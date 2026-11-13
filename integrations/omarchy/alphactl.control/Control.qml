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
  property string feedback: ""
  property bool useThemeAccent: false
  readonly property string accentRGB: Commons.Color.accent.toString().slice(-6)
  readonly property string selectedZone: ["all", "zone00", "zone01"][zone.currentIndex]
  onAccentRGBChanged: scheduleAccent()
  onSelectedZoneChanged: scheduleAccent()
  onUseThemeAccentChanged: {
    if (useThemeAccent) scheduleAccent()
    else accentTimer.stop()
  }

  function scheduleAccent() {
    if (useThemeAccent) accentTimer.restart()
  }

  // Coalesce theme updates and wait for any in-flight CLI command.
  Timer {
    id: accentTimer
    interval: 150
    onTriggered: {
      if (!root.useThemeAccent) return
      if (mutation.running) { restart(); return }
      if (/^[0-9a-fA-F]{6}$/.test(root.accentRGB))
        root.execute(["led", root.selectedZone, root.accentRGB])
    }
  }
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
      Controls.ComboBox {
        id: zone
        model: [strings.t("all"), strings.t("zone00"), strings.t("zone01")]
      }
      RowLayout {
        spacing: 8
        Controls.Switch {
          text: strings.t("useThemeAccent")
          checked: root.useThemeAccent
          onToggled: root.useThemeAccent = checked
        }
        Rectangle {
          Layout.preferredWidth: 20
          Layout.preferredHeight: 20
          Layout.alignment: Qt.AlignVCenter
          color: Commons.Color.accent
          border.color: Commons.Color.foreground
          border.width: 1
          radius: 3
        }
      }
      Controls.TextField {
        id: colorInput
        enabled: !root.useThemeAccent
        Layout.fillWidth: true
        placeholderText: strings.t("colorHint")
        maximumLength: 7
        validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{6}/ }
      }
      Controls.Button {
        text: strings.t("applyColor")
        enabled: (root.useThemeAccent || colorInput.acceptableInput) && !mutation.running
        onClicked: root.execute(["led", root.selectedZone, root.useThemeAccent ? root.accentRGB : colorInput.text])
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
