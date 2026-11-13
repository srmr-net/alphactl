GO ?= go
PREFIX ?= /usr
DESTDIR ?=

.PHONY: build test check install clean
build:
	mkdir -p bin
	$(GO) build -trimpath -o bin/alphactl ./cmd/alphactl
	$(GO) build -trimpath -o bin/alphactld ./cmd/alphactld

test:
	$(GO) test -race ./...

check:
	$(GO) vet ./...
	test -z "$$($(GO) fmt ./...)"

install:
	@test -f bin/alphactl -a -f bin/alphactld || { echo "Build binaries as your normal user first: make build" >&2; exit 1; }
	install -Dm755 bin/alphactl $(DESTDIR)$(PREFIX)/bin/alphactl
	install -Dm755 bin/alphactld $(DESTDIR)$(PREFIX)/bin/alphactld
	install -Dm644 packaging/systemd/alphactld.service $(DESTDIR)$(PREFIX)/lib/systemd/system/alphactld.service
	install -Dm644 packaging/systemd/alphactld.socket $(DESTDIR)$(PREFIX)/lib/systemd/system/alphactld.socket
	install -Dm644 packaging/sysusers.d/alphactl.conf $(DESTDIR)$(PREFIX)/lib/sysusers.d/alphactl.conf

clean:
	rm -rf bin
