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
-- When external display is connected:
--   Odd on external monitor, Even on laptop (eDP-1)
-- When external display is disconnected:
--   All workspaces continue on the available laptop display (eDP-1)

local function is_internal_display(name)
  if not name then return false end
  return (name:match("^eDP%-") or name:match("^LVDS%-") or name:match("^DSI%-")) ~= nil
end

local function get_active_displays()
  local internal = nil
  local external = nil
  local monitors = hl.get_monitors() or {}

  for _, mon in ipairs(monitors) do
    if not mon.disabled then
      if is_internal_display(mon.name) then
        internal = internal or mon.name
      else
        external = external or mon.name
      end
    end
  end

  if not internal and external then
    internal = external
  elseif not internal and #monitors > 0 then
    internal = monitors[1].name
  end

  return internal or "eDP-1", external
end

local function sync_workspaces()
  local internal, external = get_active_displays()

  for i = 1, 10 do
    local is_odd = (i % 2 == 1)
    local target_monitor
    local is_default

    if external then
      target_monitor = is_odd and external or internal
      is_default = (i == 1 or i == 2)
    else
      target_monitor = internal
      is_default = (i == 1)
    end

    hl.workspace_rule({
      workspace = tostring(i),
      monitor = target_monitor,
      default = is_default,
      persistent = true
    })

    hl.dispatch(hl.dsp.workspace.move({
      workspace = tostring(i),
      monitor = target_monitor
    }))
  end
end

-- Run initially on load / reload
sync_workspaces()

-- React dynamically to monitor connect / disconnect events
local function on_monitor_change()
  sync_workspaces()
  hl.timer(sync_workspaces, { timeout = 250 })
  hl.timer(sync_workspaces, { timeout = 600 })
end

hl.on("monitor.added", on_monitor_change)
hl.on("monitor.removed", on_monitor_change)
