# alphactl

Licensed under the [MIT License](LICENSE).

Go service and CLI for the **Alienware Alpha R1 (ASM100)** front LEDs and
HDMI input passthrough, with an Omarchy shell widget. Linux only; no Go module
dependencies. This is an initial implementation, not yet validated with physical
LED changes or an HDMI input device.

## Architecture and access

`alphactl` → JSON HTTP over a Unix socket → `alphactld` → `alienware-wmi` sysfs.
The Omarchy plugin invokes the same CLI using argument arrays.

The daemon runs as root with an empty capability set and a restricted filesystem.
Systemd owns `/run/alphactl/control.sock` as `root:alphactl`, mode `0660`.
Members of `alphactl` can control the hardware without sudo. This is a persistent
group permission: it also applies over SSH and while the desktop is locked.
There is no TCP listener or shell command execution in the daemon.

A Unix socket keeps the initial version dependency-free. D-Bus plus polkit is a
future option for active-local-session authorization and desktop change signals;
varlink is another option if an introspectable interface becomes useful.

## Build and check

Requires Go 1.23+; race tests also require a C compiler.

```sh
make build
make test
make check
omarchy plugin validate integrations/omarchy/alphactl.control
```

If a restricted workspace exposes an unusable `.git` directory, prefix Make
commands with `GOFLAGS=-buildvcs=false` to disable Go's automatic VCS stamping.

Sources are in `cmd/`, `internal/hardware/`, and `internal/ipc/`. Tests use temporary
files, never real hardware. Format Go changes with `gofmt`.

## Install on this system

Run these in a terminal. Build as your normal user; sudo may not include Go in
its PATH. Installation and adding group membership need root; subsequent CLI
and widget commands do not. Rebuild before installing updated sources.

```sh
make build
sudo make install
sudo systemd-sysusers /usr/lib/sysusers.d/alphactl.conf
sudo usermod -aG alphactl "$USER"
sudo systemctl daemon-reload
sudo systemctl enable --now alphactld.socket
```

Log out completely and back in to apply the group to the desktop session.
The first client connection starts `alphactld.service`. Nothing changes on
hardware merely by starting the service. If sysfs is missing, inspect
`ls /sys/devices/platform/alienware-wmi` and try `sudo modprobe alienware-wmi`.
Do not force driver quirks for unrelated models.

```sh
alphactl status
alphactl --json status
alphactl led all FF8000
alphactl led zone00 '#0080FF'
alphactl brightness 8
alphactl brightness 0
alphactl hdmi input
alphactl hdmi gpu
alphactl hdmi toggle
```

`input` displays the external HDMI input; `gpu` returns to Linux output. Keep
the GPU command bound to a key so returning does not require seeing the desktop.
Zone-to-front-panel labels need physical verification; identifiers intentionally
match sysfs. Colours use ordinary 8-bit `RRGGBB`, quantized to 4-bit channels
(for example `FF8000` → `0f0800`). Brightness is global, from 0 to 15.
Brightness 0 turns LEDs off; increase it to restore visibility.

## Omarchy integration

This plugin targets the installed Quickshell-based Omarchy shell with `qs.Ui`.
Copy the directory, then enable it:

```sh
mkdir -p ~/.config/omarchy/plugins
cp -r integrations/omarchy/alphactl.control ~/.config/omarchy/plugins/
omarchy plugin enable alphactl.control
```

Click **α** for brightness and zone colour controls. The brightness slider at the
top applies changes automatically; a divider separates it from the colour controls. The status line shows the
HDMI source and brightness; use the CLI or keybindings to switch HDMI.
Enable **Use theme accent colour** to apply the current Omarchy accent to
the selected zone (or both zones) and follow theme changes automatically. Turning
it off restores manual RGB entry without changing the LEDs. The toggle lasts
for the current shell session; brightness remains independently controlled.
Status refreshes when opened and every three seconds while open.
Failures appear in the panel. The shell must inherit the `alphactl` group.
The widget uses the CLI from `PATH` and the default socket.

Check `omarchy menu keybindings --print` before copying the examples in
`integrations/omarchy/bindings.lua` into `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + H", "Alpha HDMI passthrough", "alphactl hdmi toggle")
o.bind("SUPER + CTRL + A", "Alpha HDMI GPU", "alphactl hdmi gpu")
```

Use `o.rebind` if a chosen key already exists. Validate with `hyprctl reload`
and `hyprctl configerrors`. No desktop settings are changed by `make install`.

## Development and limitations

For read-only hardware inspection without installation:

```sh
./bin/alphactld --check
# To start a standalone daemon (writes still require sysfs permissions):
./bin/alphactld --socket /tmp/alphactl-dev.sock
# From another terminal:
./bin/alphactl --socket /tmp/alphactl-dev.sock status
```

Standalone sockets are `0600`; use a private directory for shared machines.
`--sysfs-root PATH` on the daemon allows a disposable fake sysfs tree.
Existing sockets are never removed to make room for a second daemon.

Settings are not persisted or reapplied after reboot/resume. LED readback is
the kernel's cached state, not a hardware measurement. Setting both zones involves
two writes; a failure may leave only one changed. Some driver versions log
firmware errors without returning them to userspace, so `OK` means the sysfs
write was accepted. Visually verify LEDs and check HDMI status after changes.

Inspect failures with `systemctl status alphactld.socket alphactld.service`,
`journalctl -u alphactld.service`, and `id`. To disable the daemon, stop both
units: `sudo systemctl disable --now alphactld.socket` followed by
`sudo systemctl stop alphactld.service`.

See [IPC reference](docs/ipc.md) for the API. Hardware behavior was checked against
the upstream [Alienware LED driver](https://raw.githubusercontent.com/torvalds/linux/master/drivers/platform/x86/dell/alienware-wmi-base.c)
and [WMAX HDMI implementation](https://gbmc.googlesource.com/linux/+/976aa630da5b5508c278487db31b873ddf6bae8f/drivers/platform/x86/dell/alienware-wmi-wmax.c).
