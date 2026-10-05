-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.0

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- External monitor on the left (0x0)
hl.monitor({ output = "desc:Lenovo Group Limited TE24-10 V905LMBB", mode = "1920x1080@60.00", position = "0x0", scale = 1.0 })
hl.monitor({ output = "desc:LG Electronics LG FULL HD 0x01010101", mode = "1920x1080@74.97", position = "0x0", scale = 1.0, vrr = 0 })
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "0x0", scale = 1.0 })

-- Internal laptop display on the right (1920x0)
hl.monitor({ output = "eDP-1", mode = "1920x1080@144.00", position = "1920x0", scale = 1.0 })

-- Fallback for any unconfigured displays
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

-- Workspace monitor assignments:
-- Odd on external monitor (HDMI-A-1), Even on laptop (eDP-1)
local laptop = "eDP-1"
local ext_mon = "HDMI-A-1"

for i = 1, 10 do
  local is_odd = (i % 2 == 1)
  local target_monitor = is_odd and ext_mon or laptop
  local is_default = (i == 1 or i == 2)

  hl.workspace_rule({
    workspace = tostring(i),
    monitor = target_monitor,
    default = is_default,
    persistent = true
  })
end
