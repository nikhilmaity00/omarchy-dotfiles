import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "custom.agent-usage"
  ipcTarget: "custom.agent-usage"
  manageIpc: false
  property var settings: ({})

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var allProviders: usage.enabledProviders
  readonly property var providers: {
    var list = []
    var all = allProviders || []
    for (var i = 0; i < all.length; i++) {
      if (isAgentInUse(all[i])) {
        list.push(all[i])
      }
    }
    return list
  }
  // Options: "multi" (separate icon + percentage for every active agent) or "single" (one unified button)
  readonly property string barMode: String(root.setting("barMode", "multi"))
  readonly property bool showPercentage: root.setting("showPercentage", true) !== false

  // The selection follows the provider, not the slot it happens to sit in
  property string selectedProviderId: ""
  readonly property int providerIndex: {
    for (var i = 0; i < providers.length; i++)
      if (providers[i].providerId === selectedProviderId) return i
    return 0
  }
  readonly property var provider: providers.length > 0 ? providers[providerIndex] : null

  property bool cursorActive: false
  property double nowMs: Date.now()

  readonly property var limits: limitWindows(provider)
  readonly property var models: modelRows(provider)
  readonly property var headline: bindingWindow(provider)
  readonly property var balance: provider ? (provider.balance || null) : null
  readonly property bool balanceAlarming: !!balance && balance.funded > 0
    && balance.remaining / balance.funded <= 0.1
  readonly property bool alarming: (!!headline && headline.percent >= 0.9) || balanceAlarming

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function selectProvider(index) {
    if (providers.length === 0) return
    var wrapped = ((index % providers.length) + providers.length) % providers.length
    selectedProviderId = providers[wrapped].providerId
  }

  function refreshNow() {
    usage.refreshAll(true)
  }

  function launchAgent() {
    if (root.bar) root.bar.run("omarchy-agent --pick")
    root.close()
  }

  // ----------------------------------------------------------- multi-bar helpers

  function isAgentInUse(p) {
    if (!p) return false
    var hasPromptsToday = (Number(p.todayPrompts || 0) > 0) || (Number(p.todayTotalTokens || 0) > 0)
    return p.ready === true && hasPromptsToday
  }

  readonly property var activeInUseProviders: {
    var list = []
    for (var i = 0; i < providers.length; i++) {
      if (isAgentInUse(providers[i])) {
        list.push(providers[i])
      }
    }
    return list
  }

  function getAgentUtilizedPercent(p) {
    if (!p) return 0
    var window = bindingWindow(p)
    if (window && window.percent !== undefined && !isNaN(window.percent)) {
      return Math.round(window.percent * 100)
    }
    if (p.balance && p.balance.funded > 0) {
      var spentRatio = p.balance.spent / p.balance.funded
      return Math.round(Math.min(1.0, Math.max(0.0, spentRatio)) * 100)
    }
    return 0
  }

  function getAgentUtilizedText(p) {
    if (!p) return ""
    var pct = getAgentUtilizedPercent(p)
    if (pct > 0 || (p.limits && p.limits.length > 0)) {
      return pct + "%"
    }
    if (p.todayTotalTokens > 0) {
      return usage.formatTokenCount(p.todayTotalTokens)
    }
    return ""
  }

  function agentGlyph(p) {
    if (!p) return "󱚣"
    var id = String(p.providerId || "").toLowerCase()
    if (id === "gemini") return "✦"
    if (id === "codex") return "󰘦"
    if (id === "claude") return "󰧑"
    if (id === "fireworks") return "🎆"
    return "󱚣"
  }

  // ---------------------------------------------------------------- limits

  function windowIsLong(text) {
    return text.indexOf("week") >= 0 || text.indexOf("7-day") >= 0 || text.indexOf("seven") >= 0
      || text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0
  }

  function windowSpanMs(label) {
    var text = String(label || "").toLowerCase()
    if (text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0) return 30 * 24 * 3600 * 1000
    if (windowIsLong(text)) return 7 * 24 * 3600 * 1000
    var hours = text.match(/(\d+)\s*-?\s*h(?:our)?\b/)
    if (hours) return Number(hours[1]) * 3600 * 1000
    var minutes = text.match(/(\d+)\s*-?\s*m(?:in(?:ute)?s?)?\b/)
    if (minutes) return Number(minutes[1]) * 60 * 1000
    return 0
  }

  function windowTitle(label) {
    var text = String(label || "").toLowerCase()
    if (text.indexOf("month") >= 0) return "Monthly"
    if (windowIsLong(text)) return "Weekly"
    if (text.indexOf("session") >= 0 || windowSpanMs(label) > 0) return "Session"
    var plain = String(label || "").replace(/\s*\(.*\)\s*/, "").trim()
    return plain === "" ? "Limit" : plain
  }

  function limitWindow(label, percent, resetAt, title) {
    return {
      title: String(title || "") !== "" ? String(title) : windowTitle(label),
      percent: Number(percent),
      resetAt: String(resetAt || "")
    }
  }

  function limitWindows(p) {
    if (!p) return []
    var out = []
    var list = p.limits || []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i] || {}
      var percent = Number(entry.percent)
      if (percent >= 0) out.push(limitWindow(entry.label, percent, entry.resetsAt, entry.title))
    }
    return out
  }

  function bindingWindow(p) {
    var windows = limitWindows(p)
    var best = null
    for (var i = 0; i < windows.length; i++) {
      if (!best || windows[i].percent > best.percent) best = windows[i]
    }
    return best
  }

  function resetMsFor(w) {
    if (!w || !w.resetAt) return 0
    var targetMs = Date.parse(w.resetAt)
    if (!isFinite(targetMs)) return 0
    return Math.max(0, targetMs - root.nowMs)
  }

  function formatDuration(ms) {
    var seconds = Math.ceil(ms / 1000)
    var d = Math.floor(seconds / (24 * 3600))
    var h = Math.floor((seconds % (24 * 3600)) / 3600)
    var m = Math.floor((seconds % 3600) / 60)
    var s = seconds % 60

    if (d > 0) return d + "d " + h + "h"
    if (h > 0) return h + "h " + (m > 0 ? m + "m" : "")
    if (m > 0) return m + "m"
    return Math.max(1, s) + "s"
  }

  // ---------------------------------------------------------------- format

  function heroMeta(p) {
    if (!p) return ""
    if (p.usageStatusText !== "") return p.usageStatusText
    if (p.tierLabel !== "") return p.tierLabel
    if (p.ready) return "Ready"
    return "Not authenticated"
  }

  function heroCardTitle(p) {
    if (!p) return ""
    if (p.usageStatusText !== "") return "STATUS"
    return "AUTHENTICATION"
  }

  function todayDate() {
    var d = new Date()
    var y = d.getFullYear()
    var m = String(d.getMonth() + 1).padStart(2, "0")
    var day = String(d.getDate()).padStart(2, "0")
    return y + "-" + m + "-" + day
  }

  function dayLabel(rawDate, today) {
    if (today) return "Today"
    if (!rawDate) return ""
    var parts = rawDate.split("-")
    if (parts.length !== 3) return rawDate
    var date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
    var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    return days[date.getDay()] || rawDate
  }

  function weekPeak(p) {
    if (!p || !p.recentDays) return 1
    var peak = 1
    for (var i = 0; i < p.recentDays.length; i++) {
      var count = Number(p.recentDays[i].messageCount || 0)
      if (count > peak) peak = count
    }
    return peak
  }

  function dayTooltip(day, today) {
    if (!day) return ""
    var tokens = usage.formatTokenCount(Number(day.messageCount || 0))
    var dateText = dayLabel(day.date, today) + " (" + (day.date || "") + ")"
    if (today && provider) {
      var prompts = Number(provider.todayPrompts || 0)
      var sessions = Number(provider.todaySessions || 0)
      var promptPart = provider.hasPromptStats
        ? prompts + " prompt" + (prompts === 1 ? "" : "s") + " · "
        : ""
      var sessionPart = sessions + " session" + (sessions === 1 ? "" : "s")
      return dateText + "\n" + tokens + " tokens · " + promptPart + sessionPart
    }
    return dateText + "\n" + tokens + " tokens"
  }

  function modelRows(p) {
    if (!p || !p.modelUsage) return []
    var out = []
    for (var id in p.modelUsage) {
      var m = p.modelUsage[id] || {}
      var total = Number(m.inputTokens || 0) + Number(m.outputTokens || 0)
        + Number(m.cacheReadInputTokens || 0) + Number(m.cacheCreationInputTokens || 0)
      if (total > 0) {
        out.push({
          id: id,
          name: usage.friendlyModelName(id),
          total: total,
          input: Number(m.inputTokens || 0),
          output: Number(m.outputTokens || 0),
          cacheRead: Number(m.cacheReadInputTokens || 0),
          cacheCreation: Number(m.cacheCreationInputTokens || 0)
        })
      }
    }
    out.sort(function(a, b) { return b.total - a.total })
    return out
  }

  function modelTooltip(row) {
    if (!row) return ""
    var lines = [row.name + " (" + usage.formatTokenCount(row.total) + " tokens)"]
    if (row.input > 0) lines.push("  Input: " + usage.formatTokenCount(row.input))
    if (row.output > 0) lines.push("  Output: " + usage.formatTokenCount(row.output))
    if (row.cacheRead > 0) lines.push("  Cache read: " + usage.formatTokenCount(row.cacheRead))
    if (row.cacheCreation > 0) lines.push("  Cache write: " + usage.formatTokenCount(row.cacheCreation))
    return lines.join("\n")
  }

  function formatMoney(amount, currency) {
    var val = Number(amount)
    if (!isFinite(val)) return "$0.00"
    var sym = currency === "EUR" ? "€" : (currency === "GBP" ? "£" : "$")
    return sym + val.toFixed(2)
  }

  function balanceDetailText(b) {
    if (!b) return ""
    var estText = b.estimated ? " (estimated)" : ""
    if (b.funded > 0) {
      return formatMoney(b.spent, b.currency) + " spent of " + formatMoney(b.funded, b.currency) + " funded" + estText
    }
    return formatMoney(b.remaining, b.currency) + " remaining" + estText
  }

  function footerText() {
    if (usage.syncStatusText !== "") return usage.syncStatusText
    if (provider && provider.syncEnabled && provider.syncDeviceCount > 0)
      return "Merged from " + provider.syncDeviceCount + " device" + (provider.syncDeviceCount === 1 ? "" : "s")
    return ""
  }

  function colorChannelLuminance(value) {
    var channel = Number(value)
    if (!isFinite(channel)) return 0
    return channel <= 0.03928 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
  }

  function colorLuminance(color) {
    return 0.2126 * colorChannelLuminance(color.r)
      + 0.7152 * colorChannelLuminance(color.g)
      + 0.0722 * colorChannelLuminance(color.b)
  }

  function iconCandidatesForProvider(p, surfaceColor) {
    if (!p) return []
    var candidates = []
    if (colorLuminance(surfaceColor || Color.background) >= 0.5)
      candidates.push(Qt.resolvedUrl("assets/" + p.providerId + "-light.svg"))
    candidates.push(Qt.resolvedUrl("assets/" + p.providerId + ".svg"))
    return candidates
  }

  visible: providers.length > 0
  implicitWidth: barContainer.implicitWidth
  implicitHeight: barContainer.implicitHeight

  onProviderIndexChanged: if (panelFlick) panelFlick.contentY = 0
  onOpenedChanged: if (opened) {
    cursorActive = false
    nowMs = Date.now()
    if (panelFlick) panelFlick.contentY = 0
    usage.refreshLimits()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Main {
    id: usage
    settings: root.settings
  }

  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refreshNow(); return "ok" }
    function next(): string { root.selectProvider(root.providerIndex + 1); return "ok" }
  }

  // ------------------------------------------------------------- top bar layout

  Item {
    id: barContainer
    implicitWidth: barRow.implicitWidth
    implicitHeight: barRow.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Row {
      id: barRow
      spacing: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left

      Repeater {
        model: root.barMode === "multi" && root.activeInUseProviders.length > 0
          ? root.activeInUseProviders
          : (root.providers.length > 0 ? [root.providers[0]] : [])

        delegate: WidgetButton {
          id: agentBtn
          required property var modelData
          required property int index

          readonly property var provider: modelData
          readonly property int agentPercent: root.getAgentUtilizedPercent(provider)
          readonly property string pctText: root.getAgentUtilizedText(provider)
          readonly property bool isAlarming: agentPercent >= 90
          readonly property bool isWarning: agentPercent >= 80

          bar: root.bar
          hasVisualContent: true
          labelVisible: false
          fixedWidth: innerRow.implicitWidth + Style.space(16)
          active: isAlarming
          activeColor: root.urgent
          tooltipText: provider ? (provider.providerName + ": " + (pctText !== "" ? pctText + " utilized" : "Active")) : ""

          onPressed: function(buttonCode) {
            if (buttonCode === Qt.RightButton) {
              root.launchAgent()
            } else if (buttonCode === Qt.MiddleButton) {
              root.selectProvider(root.providerIndex + 1)
            } else {
              if (provider && provider.providerId) {
                root.selectedProviderId = provider.providerId
              }
              root.toggle()
            }
          }

          Row {
            id: innerRow
            anchors.centerIn: parent
            spacing: Style.space(4)

            Item {
              id: iconCanvas
              width: Style.bar.iconCanvas
              height: Style.bar.iconCanvas
              anchors.verticalCenter: parent.verticalCenter

              property var candidates: root.iconCandidatesForProvider(agentBtn.provider, root.surface)
              property string candidatesKey: candidates.join("\n")
              property int candidateIndex: 0
              onCandidatesKeyChanged: candidateIndex = 0

              Image {
                id: svgMark
                anchors.fill: parent
                source: iconCanvas.candidateIndex < iconCanvas.candidates.length ? iconCanvas.candidates[iconCanvas.candidateIndex] : ""
                sourceSize.width: Style.bar.iconCanvas * 2
                sourceSize.height: Style.bar.iconCanvas * 2
                fillMode: Image.PreserveAspectFit
                onStatusChanged: if (status === Image.Error && iconCanvas.candidateIndex < iconCanvas.candidates.length)
                  Qt.callLater(function() { iconCanvas.candidateIndex++ })
              }

              OpticalGlyph {
                anchors.fill: parent
                visible: svgMark.status !== Image.Ready
                text: root.agentGlyph(agentBtn.provider)
                fontFamily: root.fontFamily
                fontSize: Style.bar.iconFont
                color: agentBtn.isAlarming ? root.urgent : (agentBtn.isWarning ? "#e5c07b" : agentBtn.foreground)
              }
            }

            Text {
              visible: root.showPercentage && agentBtn.pctText !== ""
              text: agentBtn.pctText
              color: agentBtn.isAlarming ? root.urgent : (agentBtn.isWarning ? "#e5c07b" : agentBtn.foreground)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
              renderType: Text.NativeRendering
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------- dashboard panel

  KeyboardPanel {
    id: panel
    anchorItem: barContainer
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) {
          root.cursorActive = true
          root.selectProvider(root.providerIndex + dx)
        }
        if (dy !== 0)
          panelFlick.contentY = root.clamp(panelFlick.contentY + dy * Style.space(56), 0,
                                           Math.max(0, panelFlick.contentHeight - panelFlick.height))
      }
      onActivateRequested: root.refreshNow()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") root.refreshNow() }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            visible: !!root.provider
            width: parent.width
            title: root.provider ? root.provider.providerName : ""
            meta: root.heroMeta(root.provider)
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Item {
                id: heroMark
                property var candidates: root.iconCandidatesForProvider(root.provider, root.surface)
                property string candidatesKey: candidates.join("\n")
                property int candidateIndex: 0
                onCandidatesKeyChanged: candidateIndex = 0

                width: Style.font.display
                height: Style.font.display

                Image {
                  id: heroMarkImage
                  anchors.fill: parent
                  source: heroMark.candidateIndex < heroMark.candidates.length ? heroMark.candidates[heroMark.candidateIndex] : ""
                  sourceSize.width: Style.font.display * 2
                  sourceSize.height: Style.font.display * 2
                  fillMode: Image.PreserveAspectFit
                  onStatusChanged: if (status === Image.Error && heroMark.candidateIndex < heroMark.candidates.length)
                    Qt.callLater(function() { heroMark.candidateIndex++ })
                }

                OpticalGlyph {
                  anchors.fill: parent
                  visible: heroMarkImage.status !== Image.Ready
                  text: root.agentGlyph(root.provider)
                  fontFamily: root.fontFamily
                  fontSize: Style.font.display
                  color: root.foreground
                }
              }
            }
          }

          Text {
            visible: root.providers.length === 0
            width: parent.width
            topPadding: Style.space(24)
            text: "No AI coding subscriptions found.\nAgents show up here once you've used them."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          Row {
            id: providerSwitch
            visible: root.providers.length > 1
            width: parent.width
            spacing: Style.spacing.md

            readonly property real cellWidth: root.providers.length > 0
              ? (width - spacing * (root.providers.length - 1)) / root.providers.length
              : 0

            Repeater {
              model: root.providers

              Button {
                required property var modelData
                required property int index

                width: providerSwitch.cellWidth
                text: modelData.providerName
                selected: index === root.providerIndex
                hasCursor: root.cursorActive && index === root.providerIndex
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  root.cursorActive = true
                  root.selectProvider(index)
                }
                onHovered: function(isHovered) { if (isHovered) root.cursorActive = true }
              }
            }
          }

          BorderSurface {
            visible: !!root.provider && String(root.provider.usageStatusText || "") !== ""
            width: parent.width
            implicitHeight: statusText.implicitHeight + Style.spacing.xl * 2
            color: root.alpha(root.urgent, 0.10)
            borderSpec: Border.flat(root.alpha(root.urgent, 0.35), 1)
            radius: Style.cornerRadius

            Text {
              id: statusText
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              text: root.provider ? String(root.provider.authHelpText || "") : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          PanelSeparator {
            visible: balanceSection.visible || limitsSection.visible
            foreground: root.foreground
          }

          Column {
            id: balanceSection
            visible: !!root.balance
            width: parent.width
            spacing: Style.space(10)

            readonly property real ratio: root.balance && root.balance.funded > 0
              ? root.clamp(root.balance.remaining / root.balance.funded, 0, 1)
              : -1

            PanelSectionHeader {
              width: parent.width
              text: "BALANCE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Item {
              width: parent.width
              implicitHeight: Math.max(balanceLabel.implicitHeight, balanceValue.implicitHeight)

              Text {
                id: balanceLabel
                text: "Prepaid credits"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: balanceValue
                textFormat: Text.PlainText
                text: root.balance ? root.formatMoney(root.balance.remaining, root.balance.currency) : ""
                color: root.balanceAlarming ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Meter {
              visible: balanceSection.ratio >= 0
              width: parent.width
              value: balanceSection.ratio
              alarming: root.balanceAlarming
            }

            Text {
              textFormat: Text.PlainText
              visible: text !== ""
              width: parent.width
              text: root.balanceDetailText(root.balance)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Column {
            id: limitsSection
            visible: root.limits.length > 0
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "LIMITS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.limits

              LimitRow {
                required property var modelData
                width: limitsSection.width
                window: modelData
              }
            }
          }

          PanelSeparator {
            visible: usageSection.visible
            foreground: root.foreground
          }

          Column {
            id: usageSection
            visible: !!root.provider && root.provider.recentDays && root.provider.recentDays.length > 0
            width: parent.width
            spacing: Style.spacing.md

            readonly property var days: root.provider ? (root.provider.recentDays || []) : []
            readonly property real peak: Math.max(1, root.weekPeak(root.provider))

            PanelSectionHeader {
              width: parent.width
              text: "TOKENS BY DAY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: usageSection.days

              DayRow {
                required property var modelData
                required property int index

                width: usageSection.width
                day: modelData
                ratio: Number(modelData.messageCount || 0) / usageSection.peak
                today: String(modelData.date || "") === root.todayDate()
              }
            }
          }

          PanelSeparator {
            visible: modelSection.visible
            foreground: root.foreground
          }

          Column {
            id: modelSection
            visible: root.models.length > 0
            width: parent.width
            spacing: Style.spacing.md

            PanelSectionHeader {
              width: parent.width
              text: "TOKENS BY MODEL"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.models

              ModelRow {
                required property var modelData
                width: modelSection.width
                row: modelData
                share: modelData.total / Math.max(1, root.models[0].total)
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: text !== ""
            width: parent.width
            topPadding: Style.space(2)
            text: root.footerText()
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  component LimitRow: Column {
    id: limitRow
    property var window: null

    readonly property bool alarming: window && window.percent >= 0.9

    spacing: Style.space(6)

    Item {
      width: parent.width
      implicitHeight: Math.max(limitLabel.implicitHeight, limitValue.implicitHeight)

      Text {
        id: limitLabel
        textFormat: Text.PlainText
        text: limitRow.window ? limitRow.window.title : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        anchors.left: parent.left
        anchors.right: limitValue.left
        anchors.rightMargin: Style.spacing.sm
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: limitValue
        textFormat: Text.PlainText
        text: limitRow.window && limitRow.window.percent >= 0
          ? Math.round(limitRow.window.percent * 100) + "%"
          : "—"
        color: limitRow.alarming ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Meter {
      width: parent.width
      value: limitRow.window ? limitRow.window.percent : -1
      alarming: limitRow.alarming
    }

    Text {
      id: resetText
      textFormat: Text.PlainText
      width: parent.width
      text: {
        var remainingMs = root.resetMsFor(limitRow.window)
        return remainingMs > 0 ? "Resets in " + root.formatDuration(remainingMs) : ""
      }
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  component Meter: Item {
    id: meter
    property real value: -1
    property bool alarming: false
    property real thickness: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))

    implicitHeight: thickness

    Rectangle {
      id: meterTrack
      anchors.fill: parent
      radius: height / 2
      color: root.track
    }

    Rectangle {
      anchors.left: meterTrack.left
      anchors.verticalCenter: meterTrack.verticalCenter
      height: meterTrack.height
      radius: meterTrack.radius
      width: meterTrack.width * root.clamp(meter.value, 0, 1)
      color: meter.alarming ? root.urgent : root.foreground

      Behavior on width {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
    }
  }

  component DayRow: Item {
    id: dayRow
    property var day: null
    property real ratio: 0
    property bool today: false

    implicitHeight: Math.max(dayLabel.implicitHeight, dayValue.implicitHeight) + Style.spacing.sm

    Text {
      id: dayLabel
      textFormat: Text.PlainText
      text: root.dayLabel(dayRow.day ? dayRow.day.date : "", dayRow.today)
      color: dayRow.today ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: dayRow.today
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(52)
    }

    Rectangle {
      id: dayTrack
      anchors.left: dayLabel.right
      anchors.right: dayValue.left
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      height: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))
      radius: height / 2
      color: root.track

      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        radius: parent.radius
        width: parent.width * root.clamp(dayRow.ratio, 0, 1)
        color: dayRow.today ? root.foreground : root.alpha(root.foreground, 0.55)

        Behavior on width {
          NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
      }
    }

    Text {
      id: dayValue
      textFormat: Text.PlainText
      text: usage.formatTokenCount(dayRow.day ? Number(dayRow.day.messageCount || 0) : 0)
      color: dayRow.today ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: Text.AlignRight
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(52)
    }

    MouseArea {
      id: dayHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }

    PanelToolTip {
      visible: dayHover.containsMouse
      text: root.dayTooltip(dayRow.day, dayRow.today)
      fontFamily: root.fontFamily
    }
  }

  component ModelRow: Item {
    id: modelRow
    property var row: null
    property real share: 0

    implicitHeight: modelName.implicitHeight + Style.spacing.lg

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: root.alpha(root.foreground, 0.05)
    }

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * root.clamp(modelRow.share, 0, 1)
      radius: Style.cornerRadius
      color: root.alpha(root.foreground, 0.14)

      Behavior on width {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
    }

    Text {
      id: modelName
      textFormat: Text.PlainText
      text: modelRow.row ? modelRow.row.name : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8)
      anchors.right: modelTokens.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: modelTokens
      textFormat: Text.PlainText
      text: modelRow.row ? usage.formatTokenCount(modelRow.row.total) : ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
      id: modelHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }

    PanelToolTip {
      visible: modelHover.containsMouse
      text: root.modelTooltip(modelRow.row)
      fontFamily: root.fontFamily
    }
  }
}
