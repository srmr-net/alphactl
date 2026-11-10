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
  property string feedback: ""
  readonly property string statusLabel: healthy
    ? strings.t("status").arg(source === "input" ? "HDMI IN" : source === "gpu" ? "GPU" : "?")
        .arg(Commons.I18n.formatNumber(brightness)).arg(Commons.I18n.formatNumber(maxBrightness))
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
    mutation.command = ["alphactl"].concat(args)
    mutation.running = true
  }
  Component.onCompleted: refresh()

  Process {
    id: query
    command: ["alphactl", "--json", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.healthy = false
        if (text.length > 65536) return
        try {
          const s = JSON.parse(text)
          if (!["input", "gpu", "unknown"].includes(s.source)
              || !Number.isInteger(s.brightness) || !Number.isInteger(s.max_brightness)
              || s.brightness < 0 || s.brightness > 15 || s.max_brightness !== 15) return
          root.source = s.source
          root.brightness = s.brightness
          root.maxBrightness = s.max_brightness
          root.healthy = true
        } catch (e) {}
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
      if (mouseButton === Qt.RightButton) root.execute(["hdmi", "toggle"])
      else { root.opened = !root.opened; if (root.opened) root.refresh() }
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
      Controls.Button {
        text: strings.t("toggle")
        enabled: root.healthy && !mutation.running
        onClicked: root.execute(["hdmi", "toggle"])
      }
      Controls.Button {
        text: strings.t("gpu")
        enabled: !mutation.running
        onClicked: root.execute(["hdmi", "gpu"])
      }
      Controls.ComboBox {
        id: zone
        model: [strings.t("all"), strings.t("zone00"), strings.t("zone01")]
      }
      Controls.TextField {
        id: colorInput
        Layout.fillWidth: true
        placeholderText: strings.t("colorHint")
        maximumLength: 7
        validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{6}/ }
      }
      Controls.Button {
        text: strings.t("applyColor")
        enabled: colorInput.acceptableInput && !mutation.running
        onClicked: root.execute(["led", ["all", "zone00", "zone01"][zone.currentIndex], colorInput.text])
      }
      Controls.SpinBox {
        id: level
        from: 0
        to: 15
        value: root.brightness
      }
      Controls.Button {
        text: strings.t("applyBrightness")
        enabled: !mutation.running
        onClicked: root.execute(["brightness", String(level.value)])
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
