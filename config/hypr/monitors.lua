-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "desc:LG Electronics LG FULL HD 0x01010101", mode = "1920x1080@74.97", position = "0x0", scale = 1.0, vrr = 0 })
hl.monitor({ output = "eDP-1", mode = "preferred", position = "192x1080", scale = omarchy_monitor_scale })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

-- Workspace monitor assignments:
-- Odd on laptop (eDP-1), Even on external monitor (HDMI-A-1)
local laptop = "eDP-1"
local ext_mon = "desc:LG Electronics LG FULL HD 0x01010101"

for i = 1, 10 do
  local is_odd = (i % 2 == 1)
  local target_monitor = is_odd and laptop or ext_mon
  local is_default = (i == 1 or i == 2)

  hl.workspace_rule({
    workspace = tostring(i),
    monitor = target_monitor,
    default = is_default,
    persistent = true
  })
end