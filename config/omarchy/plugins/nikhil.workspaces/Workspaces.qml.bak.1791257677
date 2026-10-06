import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  property int revision: 0

  readonly property string screenName: {
    if (root.QsWindow && root.QsWindow.window && root.QsWindow.window.screen) {
      return root.QsWindow.window.screen.name || ""
    }
    return ""
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      root.revision++
    }
    function onFocusedWorkspaceChanged() {
      root.revision++
    }
    function onActiveToplevelChanged() {
      root.revision++
    }
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values || []
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function workspaceBelongsToThisScreen(wsId, wsMonitorName) {
    var sName = root.screenName
    if (!sName) return true
    if (wsMonitorName) return wsMonitorName === sName
    if (sName === "HDMI-A-1") return (wsId % 2 === 1)
    if (sName === "eDP-1") return (wsId % 2 === 0)
    return true
  }

  function workspaceIds() {
    var _rev = root.revision
    var sName = root.screenName
    var values = Hyprland.workspaces.values || []
    var focusedId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    var ids = []

    for (var i = 0; i < values.length; i++) {
      var ws = values[i]
      if (!ws || ws.id <= 0 || ws.id > 10) continue

      var monName = ws.monitor ? ws.monitor.name : ""
      if (!root.workspaceBelongsToThisScreen(ws.id, monName)) continue

      var occupied = ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0
      var isActive = ws.active === true
      var isFocused = (focusedId === ws.id)

      if (occupied || isActive || isFocused) {
        if (ids.indexOf(ws.id) === -1) ids.push(ws.id)
      }
    }

    if (focusedId > 0 && focusedId <= 10 && ids.indexOf(focusedId) === -1) {
      var focusedWs = root.workspaceById(focusedId)
      var focusedMonName = focusedWs && focusedWs.monitor ? focusedWs.monitor.name : ""
      if (root.workspaceBelongsToThisScreen(focusedId, focusedMonName)) {
        ids.push(focusedId)
      }
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : Math.max(1, root.workspaceIds().length)
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : (modelData === 10 ? "0" : String(modelData))
        opacity: 1
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
