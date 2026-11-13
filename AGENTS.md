# Repository Guidelines

## Project Structure & Architecture

alphactl targets Linux on the Alienware Alpha R1 (ASM100), using Go 1.23+ without dependencies. The CLI communicates with the privileged daemon through JSON HTTP over a Unix socket; the daemon accesses the kernel's `alienware-wmi` sysfs interface.

- `cmd/alphactl/`: user-facing CLI.
- `cmd/alphactld/`: daemon startup, socket activation, and shutdown.
- `internal/hardware/`: sysfs access, validation, colour conversion, and serialized hardware operations.
- `internal/ipc/`: versioned HTTP handlers and Unix socket client.
- `packaging/`: systemd service/socket units and sysusers group definition.
- `integrations/omarchy/`: QML widget, JSON manifest/translations, and Lua keybinding examples.
- `docs/ipc.md`: API contract; `bin/`: ignored build outputs.

## Build, Test, and Development Commands

- `make build`: build both binaries into `bin/`.
- `make test`: run `go test -race ./...`; requires a C compiler.
- `make check`: run `go vet` and check formatting; its `go fmt` invocation also reformats files.
- `gofmt -w cmd internal`: format Go sources.
- `./bin/alphactld --check`: read hardware status without starting a socket or changing settings.
- `omarchy plugin validate integrations/omarchy/alphactl.control`: validate the plugin manifest.
- `make install DESTDIR=/tmp/alphactl-stage`: stage installation files for review.

Use `GOFLAGS=-buildvcs=false` if inaccessible Git metadata prevents builds. See `INSTALL.md` for installation and `README.md` for standalone daemon commands.

## Coding Style & Naming Conventions

Use idiomatic Go, gofmt indentation, lowercase package names, and explicit error handling. Keep hardware access in `internal/hardware` and synchronize operations there. Preserve sysfs identifiers (`zone00`, `zone01`) and version API routes under `/v1/`. Follow existing two-space QML/JSON indentation. Pass CLI arguments as arrays in QML, render dynamic text as plain text, and place UI strings in `i18n/en.json`.

## Testing Guidelines

Use Go's standard `testing` package, colocated `*_test.go` files, and descriptive `Test...` names. Cover invalid input, colour quantization, missing attributes, HDMI state parsing, concurrency, and IPC behavior using temporary fake sysfs files. Automated tests must not change real hardware. No coverage threshold is configured; report physical verification separately.

## Commit & Pull Request Guidelines

History currently contains only `init commit`; no established convention exists. Use concise, imperative subjects and focused commits. PRs should explain behavior, validation, relevant issues, and limitations. Include screenshots for widget changes and update API documentation when contracts change.

## Security & Hardware Boundaries

Preserve the group-restricted socket and narrow service write access. Never accept caller-supplied filesystem paths through IPC. Keep startup read-only. Document partial writes and driver readback limitations; accepted sysfs writes do not guarantee firmware success. Do not commit secrets.
