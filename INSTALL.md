# Installation

## Prerequisites

Run commands from the repository root. Requires Linux with systemd, an Alienware
Alpha R1 (ASM100) exposing the `alienware-wmi` sysfs interface, Go 1.23+, and make.
Race tests also require a C compiler. The optional widget requires Omarchy's
Quickshell-based shell with `qs.Ui`.

## Install the daemon and CLI

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

Verify access after logging back in:

```sh
alphactl status
```

See [CLI usage](README.md#cli-usage) for LED and HDMI commands.

## Omarchy plugin

This plugin targets the installed Quickshell-based Omarchy shell with `qs.Ui`.
Copy the directory, then enable it:

```sh
mkdir -p ~/.config/omarchy/plugins
cp -r integrations/omarchy/alphactl.control ~/.config/omarchy/plugins/
omarchy plugin enable alphactl.control
```

After updating the repository, copy the plugin again and rescan:

```sh
cp -r integrations/omarchy/alphactl.control ~/.config/omarchy/plugins/
omarchy-shell shell rescanPlugins
```

If the update is not visible, run `omarchy restart shell`.

## HDMI keybindings

Check `omarchy menu keybindings --print` before copying the examples in
`integrations/omarchy/bindings.lua` into `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + H", "Alpha HDMI passthrough", "alphactl hdmi toggle")
o.bind("SUPER + CTRL + A", "Alpha HDMI GPU", "alphactl hdmi gpu")
```

Use `o.rebind` if a chosen key already exists. Validate with `hyprctl reload`
and `hyprctl configerrors`. No desktop settings are changed by `make install`.

Personally, I just rebind "Toggle laptop display on/off" to HDMI Passthrough:

```lua
hl.unbind("SUPER + CTRL + Delete")
o.bind("SUPER + CTRL + Delete", "Toggle HDMI Passthrough", "alphactl hdmi toggle")
```


## Troubleshooting

If `sudo make install` reports missing binaries, run `make build` as your normal
user first. Rebuild before installing updated sources. If Git metadata prevents
a build, use `GOFLAGS=-buildvcs=false make build`.

For socket permission errors, check `id` and
`ls -l /run/alphactl/control.sock`. The socket should be owned by `root:alphactl`
with mode `0660`. After adding group membership, fully log out and back in to
update the desktop session. `newgrp alphactl` allows a temporary CLI test in a
new subshell but does not update the running desktop shell.

Inspect failures with `systemctl status alphactld.socket alphactld.service`,
`journalctl -u alphactld.service`, and `id`. To disable the daemon, stop both
units: `sudo systemctl disable --now alphactld.socket` followed by
`sudo systemctl stop alphactld.service`.

