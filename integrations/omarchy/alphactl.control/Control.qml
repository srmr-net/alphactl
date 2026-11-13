import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell.Io
import qs.Ui
import qs.Commons as Commons

BarWidget {
  id: root
  moduleName: "alphactl.control"
  property bool opened: false
  property bool healthy: false
  property string source: "unknown"
  property int brightness: 0
  property int maxBrightness: 15
  property int pendingBrightness: -1
  property int commandRevision: 0

  Timer {
    id: brightnessTimer
    interval: 60
    onTriggered: {
      if (mutation.running) { restart(); return }
      const value = root.pendingBrightness
      if (value >= 0) root.execute(["brightness", String(value)])
      root.pendingBrightness = -1
    }
  }
  property color zone00Color: "transparent"
  property color zone01Color: "transparent"

  function zoneColor(raw) {
    if (typeof raw !== "string" || raw.length > 100) return "transparent"
    const match = /^red: (\d{1,2}), green: (\d{1,2}), blue: (\d{1,2})$/.exec(raw)
    if (!match) return "transparent"
    const channels = [Number(match[1]), Number(match[2]), Number(match[3])]
    if (channels.some(value => value > 15)) return "transparent"
    // The driver reports four-bit channels; expand them for the preview.
    return Qt.rgba(channels[0] / 15, channels[1] / 15, channels[2] / 15, 1)
  }

  property string feedback: ""
  property bool sameColor: true
  readonly property string statusLabel: healthy
    ? strings.t("status").arg(Commons.I18n.formatNumber(brightness))
        .arg(Commons.I18n.formatNumber(maxBrightness))
    : strings.t("unavailable")
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function refresh() {
    if (!query.running) query.running = true
  }
  function open() { root.opened = true; root.refresh() }
  function close() { root.opened = false }
  function execute(args) {
    if (mutation.running) return
    feedback = ""
    commandRevision++
    mutation.command = ["alphactl"].concat(args)
    mutation.running = true
  }
  Component.onCompleted: refresh()

  Process {
    id: query
    property int revision: 0
    onRunningChanged: if (running) revision = root.commandRevision
    command: ["alphactl", "--json", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text.length > 65536) { root.healthy = false; return }
        try {
          const s = JSON.parse(text)
          if (!["input", "gpu", "unknown"].includes(s.source)
              || !Number.isInteger(s.brightness) || !Number.isInteger(s.max_brightness)
              || s.brightness < 0 || s.brightness > 15 || s.max_brightness !== 15) { root.healthy = false; return }
          root.source = s.source
          if (query.revision === root.commandRevision && !mutation.running) {
            root.zone00Color = root.zoneColor(s.zones ? s.zones.zone00 : null)
            root.zone01Color = root.zoneColor(s.zones ? s.zones.zone01 : null)
          }
          if (!level.pressed && root.pendingBrightness < 0 && !mutation.running
              && query.revision === root.commandRevision)
            root.brightness = s.brightness
          root.maxBrightness = s.max_brightness
          root.healthy = true
        } catch (e) { root.healthy = false }
      }
    }
    onExited: function(code, status) { if (code !== 0 || status !== 0) root.healthy = false }
  }
  Process {
    id: mutation
    onExited: function(code, status) {
      root.feedback = code === 0 && status === 0 ? "success" : "failed"
      root.refresh()
    }
  }
  // Poll only while the panel is open; opening always refreshes CLI changes.
  Timer {
    interval: 3000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "α"
    tooltipText: strings.t("title")
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) {
        root.opened = !root.opened
        if (root.opened) root.refresh()
      }
    }
  }
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: 330
    contentHeight: controls.implicitHeight
    ColumnLayout {
      id: controls
      width: parent.width
      spacing: 8
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        color: Commons.Color.foreground
        text: root.statusLabel
        wrapMode: Text.Wrap
      }
      Controls.Slider {
        id: level
        Layout.fillWidth: true
        from: 0
        to: root.maxBrightness
        stepSize: 1
        snapMode: Controls.Slider.SnapAlways
        enabled: root.healthy
        onMoved: {
          root.pendingBrightness = Math.round(value)
          root.brightness = root.pendingBrightness
          brightnessTimer.restart()
        }
      }
      Binding {
        target: level
        property: "value"
        value: root.brightness
        when: !level.pressed && root.pendingBrightness < 0 && !mutation.running
        restoreMode: Binding.RestoreNone
      }
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        color: Commons.Color.foreground
        opacity: 0.25
      }
      RowLayout {
        spacing: 8
        Text {
          textFormat: Text.PlainText
          color: Commons.Color.foreground
          text: strings.t("zone00")
        }
        Rectangle {
          Layout.preferredWidth: 20
          Layout.preferredHeight: 20
          color: root.healthy ? root.zone00Color : "transparent"
          border.color: Commons.Color.foreground
          border.width: 1
          radius: 3
        }
        Item { Layout.preferredWidth: 8 }
        Text {
          textFormat: Text.PlainText
          color: Commons.Color.foreground
          text: strings.t("zone01")
        }
        Rectangle {
          Layout.preferredWidth: 20
          Layout.preferredHeight: 20
          color: root.healthy ? root.zone01Color : "transparent"
          border.color: Commons.Color.foreground
          border.width: 1
          radius: 3
        }
      }
      Controls.Switch {
        text: strings.t("sameColor")
        checked: root.sameColor
        onToggled: root.sameColor = checked
      }
      ColorSelector {
        Layout.fillWidth: true
        visible: root.sameColor
        active: root.sameColor
        busy: mutation.running
        catalog: strings
        onApplyRequested: function(rgb) { root.execute(["led", "all", rgb]) }
      }
      ColorSelector {
        Layout.fillWidth: true
        visible: !root.sameColor
        active: !root.sameColor
        title: strings.t("zone00")
        busy: mutation.running
        catalog: strings
        onApplyRequested: function(rgb) { root.execute(["led", "zone00", rgb]) }
      }
      ColorSelector {
        Layout.fillWidth: true
        visible: !root.sameColor
        active: !root.sameColor
        title: strings.t("zone01")
        busy: mutation.running
        catalog: strings
        onApplyRequested: function(rgb) { root.execute(["led", "zone01", rgb]) }
      }
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        color: Commons.Color.foreground
        text: root.feedback ? strings.t(root.feedback) : ""
        wrapMode: Text.Wrap
      }
    }
  }
}
