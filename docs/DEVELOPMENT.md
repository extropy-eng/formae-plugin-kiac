# Develop the plugin with `mise`

[mise](https://mise.jdx.dev) installs the toolchain and runs every development task.
It is the only entry point you need for build, test, lint, validation, install,
and conformance runs.

## Set up

```bash
mise trust
mise install
```

`mise trust` approves the repository's `.config/mise/config.toml` and`mise install` installs:

- the pinned Go toolchain
- [Lisette](https://lisette.run/)
- Apple's [container](https://github.com/apple/container) CLI
- [kiac](https://saiyam1814.github.io/kiac/docs/)
- [Pkl](https://pkl-lang.org/)
- [gotestsum](https://github.com/gotestyourself/gotestsum) for running conformance tests

The configuration pins Go `1.26` on purpose. Lisette `0.13.0` generates Go bindings
against the Go `1.26` standard library. Go `1.27` changes `encoding/json.RawMessage`,
which the Lisette `bindgen` cannot resolve.

Plugin metadata is read from `formae-plugin.pkl`, so the binary name, version, and
schema version do not drift.

## Project layout

| Path | Contents |
| --- | --- |
| `src/` | Lisette packages and colocated tests. |
| `src/main.lis` | Composition root. Starts the plugin with the formae SDK. |
| `src/domain/` | SDK-free models, resource specs, target config, failure vocabulary, and ID/text helpers. |
| `src/ports/` | Structural interfaces for outbound capabilities. |
| `src/application/` | Resource use cases, outcome types, status polling, and the operation registry. |
| `src/adapters/formae/` | SDK boundary, target/property codecs, result mapping, and resource dispatch. |
| `src/adapters/kiac/` | CLI arguments, JSON DTOs, process runner, async handles, and stderr classification. |
| `schema/pkl/` | Pkl schema for the six resource types and the target config. |
| `examples/basic/` | A complete project you can evaluate or apply. |
| `docs/` | Technical design and this document.

## Common tasks

```bash
mise run check              # lint, tests, manifest, schema, and dependency guard
mise run build              # build the plugin binary and record schema/pkl/VERSION
mise run test               # transpile, build, and run the test suite
mise run lint               # typecheck and lint for darwin/arm64 and linux/amd64
mise run validate:manifest  # validate formae-plugin.pkl
mise run validate:schema    # validate the Pkl schema against formae conventions
mise run install            # build, check, and install into the local plugin directory
mise run clean              # remove bin/ and target/
```

`mise run check` is the task to run before a commit. It fans out to `lint`, `test`,
`validate:manifest`, `validate:schema`, and `check:deps`.

`check:deps` fails if the built plugin does not use the Platform Engineering Labs forks
of `ergo` and `actor/statemachine`. The upstream statemachine does not schedule the
status timer the formae agent relies on, which causes long-running creates to be marked as
missing in action.

## Task caching

Every task declares its inputs and outputs:

```toml
[tasks."test"]
run = "lis test --go-flags {{ vars.go_flags }}"
cache.enabled = true
sources = ["formae-plugin.pkl", "lisette.toml", "src/**/*.lis"]
outputs = ["target"]
```

When the sources are unchanged and the declared outputs still exist, mise skips the task
and reuses the cached result. Editing a `.lis` file invalidates the test and lint caches.
Editing `formae-plugin.pkl` invalidates the build, test, manifest, and schema tasks.
The cached outputs include `target/`, `target/go.mod`, `target/go.sum`,
`target/.lisette`, and `schema/pkl/VERSION`, so a repeat `mise run build` does not
redo the Lisette transpile when nothing changed.

The install task depends on `check`, so it cannot install a stale or failing build.
It removes the previous local copy before writing the new binary, schema, and manifest.

## Install locally and use it from a project

```bash
mise run install
```

The plugin is installed under `${XDG_DATA_HOME:-$HOME/.pel}/formae/plugins/kiac/v<version>/`.

Restart the formae agent after installing the plugin.

Point a project at the local build:

```bash
formae project init --include kiac@local
```

The `@local` suffix tells formae to resolve the schema from the local plugin directory
instead of resolving it from the Formae Hub.

## Tests

The test suite uses a fake `kiac` shell script. It covers CLI argument construction,
JSON parsing, async operation state, status timeouts, error codes, and the fake subprocess
boundary without starting a VM.

The conformance test suite runs against a real kiac runtime on macOS. It installs the plugin
first, then exercises CRUD and discovery through the formae agent.

```bash
mise run install
FORMAE_TEST_RUN_ID=local-1 mise --env=conformance run test:conformance
```

The conformance environment also exposes `test:conformance:crud` and
`test:conformance:discovery` for narrower runs. The suite creates real containers
and cleans them up, so the `apple/container` system must be run beforehand.

CI runs `mise run check` on Linux, and runs conformance tests on macOS
when triggered.
