-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")
-- Media playback controls
o.bind("ALT + X", "Toggle play/pause", "omarchy-shell media playPause", { locked = true })
o.bind("ALT + C", "Next media track", "omarchy-shell media next", { locked = true })
o.bind("ALT + Z", "Previous media track", "omarchy-shell media previous", { locked = true })
--Omarchy Find file search overlay
o.bind("ALT + SPACE", "Find files & folders", "omarchy-shell shell toggle jesseburlamaque.omarchy-find")
o.bind("ALT + TAB", "Workspace overview", "omarchy-shell shell toggle mirador '{}'")
o.bind("SUPER + E", "Files", { omarchy = "nautilus" })

-- Volume and Brightness controls
o.bind("ALT + A", "Volume down", "omarchy-audio-output-volume lower", { locked = true, repeating = true })
o.bind("ALT + S", "Volume up", "omarchy-audio-output-volume raise", { locked = true, repeating = true })
o.bind("ALT + D", "Active display brightness down", "omarchy-brightness-display 5%-", { locked = true, repeating = true })
o.bind("ALT + F", "Active display brightness up", "omarchy-brightness-display +5%", { locked = true, repeating = true })
