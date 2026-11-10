-- Copy chosen lines into ~/.config/hypr/bindings.lua after checking for conflicts
-- with `omarchy menu keybindings --print`. Use o.rebind for an existing binding.
o.bind("SUPER + CTRL + H", "Alpha HDMI passthrough", "alphactl hdmi toggle")
o.bind("SUPER + CTRL + A", "Alpha HDMI GPU", "alphactl hdmi gpu")
