-- Custom workspace manager for Omarchy
-- Odd workspaces (1, 3, 5, 7, 9) on laptop display (eDP-1)
-- Even workspaces (2, 4, 6, 8, 10) on external display
-- When no external display is connected, all workspaces (1..10) on laptop display

require("default.hypr.helpers")

local M = {}

local function action(fn, expression)
  if o and o.bind_expressions then
    o.bind_expressions[fn] = expression
  end
  return fn
end

local function literal(value)
  if value == nil then
    return "nil"
  end
  return string.format("%q", value)
end

local function is_internal(mon)
  if not mon or not mon.name then return false end
  return mon.name:match("^eDP") ~= nil or mon.name:match("^LVDS") ~= nil or mon.name:match("^DSI") ~= nil
end

local function connected(gone)
  local monitors = {}
  for _, monitor in ipairs(hl.get_monitors()) do
    if not monitor.is_mirror and monitor.name ~= gone and not monitor.disabled then
      monitors[#monitors + 1] = monitor
    end
  end
  return monitors
end

local function get_monitors(gone)
  local internal_mon = nil
  local external_mon = nil

  for _, mon in ipairs(connected(gone)) do
    if is_internal(mon) then
      internal_mon = mon
    else
      if not external_mon then
        external_mon = mon
      end
    end
  end

  if not internal_mon and external_mon then
    internal_mon = external_mon
    external_mon = nil
  elseif not internal_mon and not external_mon then
    local mons = connected(gone)
    if #mons > 0 then
      internal_mon = mons[1]
      if #mons > 1 then
        external_mon = mons[2]
      end
    end
  end

  return internal_mon, external_mon
end

function M.reconcile(gone)
  local internal_mon, external_mon = get_monitors(gone)
  if not internal_mon then
    return
  end

  if external_mon then
    -- Dual display layout:
    -- Odd on laptop, Even on external display
    for i = 1, 10 do
      local is_odd = (i % 2 == 1)
      local target = is_odd and internal_mon.name or external_mon.name
      local is_default = (i == 1 or i == 2)

      hl.workspace_rule({
        workspace = tostring(i),
        monitor = target,
        default = is_default,
        persistent = true
      })
    end

    -- Reassign active/existing workspaces to correct monitors
    for _, ws in ipairs(hl.get_workspaces()) do
      local id = ws.id
      if id >= 1 and id <= 10 and not ws.special then
        local target = (id % 2 == 1) and internal_mon.name or external_mon.name
        if ws.monitor and ws.monitor.name ~= target then
          hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = target }))
        end
      end
    end
  else
    -- Single display layout (laptop only):
    -- All workspaces on laptop display like default settings
    for i = 1, 10 do
      hl.workspace_rule({
        workspace = tostring(i),
        monitor = internal_mon.name,
        default = (i == 1),
        persistent = true
      })
    end

    -- Move any workspaces that were on disconnected monitors back to laptop
    for _, ws in ipairs(hl.get_workspaces()) do
      local id = ws.id
      if id >= 1 and id <= 10 and not ws.special then
        if ws.monitor and ws.monitor.name ~= internal_mon.name then
          hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = internal_mon.name }))
        end
      end
    end
  end
end

-- Focus workspace directly and guarantee correct monitor focus
function M.focus(ws)
  return action(function()
    local internal_mon, external_mon = get_monitors()
    local target_mon = nil
    if external_mon then
      target_mon = (tonumber(ws) % 2 == 1) and internal_mon or external_mon
    else
      target_mon = internal_mon
    end

    if target_mon and not target_mon.focused then
      hl.dispatch(hl.dsp.focus({ monitor = target_mon.name }))
    end

    hl.dispatch(hl.dsp.focus({ workspace = tostring(ws) }))
  end, "hl.dsp.focus({ workspace = " .. literal(tostring(ws)) .. " })")
end

-- Move window to workspace
function M.move_window(ws, follow)
  return action(function()
    local win = hl.get_active_window()
    if win then
      hl.dispatch(hl.dsp.window.move({
        workspace = tostring(ws),
        follow = follow ~= false,
        window = "address:" .. win.address
      }))
    else
      hl.dispatch(hl.dsp.window.move({
        workspace = tostring(ws),
        follow = follow ~= false
      }))
    end
    if follow ~= false then
      local internal_mon, external_mon = get_monitors()
      local target_mon = (external_mon and (tonumber(ws) % 2 == 0)) and external_mon or internal_mon
      if target_mon and not target_mon.focused then
        hl.dispatch(hl.dsp.focus({ monitor = target_mon.name }))
      end
    end
  end, "hl.dsp.window.move({ workspace = " .. literal(tostring(ws)) .. (follow == false and ", follow = false" or "") .. " })")
end

-- Move workspace to monitor in direction
function M.move_to_monitor(direction)
  return action(function()
    local target = hl.get_monitor(direction)
    if target then
      hl.dispatch(hl.dsp.workspace.move({ monitor = target.name }))
    end
  end, "hl.dsp.workspace.move({ monitor = " .. literal(direction) .. " })")
end

-- Move window to monitor in direction
function M.move_window_to_monitor(direction)
  return action(function()
    local target = hl.get_monitor(direction)
    if target then
      hl.dispatch(hl.dsp.window.move({ monitor = target.name }))
    end
  end, "hl.dsp.window.move({ monitor = " .. literal(direction) .. " })")
end

function M.workspace_id(monitor, slot)
  return slot
end

-- Event listeners
hl.on("hyprland.start", function()
  M.reconcile()
end)

hl.on("config.reloaded", function()
  M.reconcile()
end)

hl.on("monitor.added", function(monitor)
  M.reconcile()
  hl.timer(function()
    M.reconcile()
  end, { type = "oneshot", timeout = 150 })
end)

hl.on("monitor.removed", function(monitor)
  local name = monitor and monitor.name
  M.reconcile(name)
  hl.timer(function()
    M.reconcile(name)
  end, { type = "oneshot", timeout = 150 })
end)

hl.on("monitor.layout_changed", function()
  M.reconcile()
end)

-- Reconcile immediately when module is loaded
M.reconcile()

o.workspaces = M

return M
