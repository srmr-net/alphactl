import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons as Commons

ColumnLayout {
  id: root
  required property var catalog
  property string title: ""
  property bool active: true
  property bool busy: false
  property bool useThemeAccent: false
  readonly property string accentRGB: Commons.Color.accent.toString().slice(-6)
  signal applyRequested(string rgb)
  spacing: 8

  function scheduleAccent() {
    if (active && useThemeAccent) accentTimer.restart()
    else accentTimer.stop()
  }
  onActiveChanged: scheduleAccent()
  onUseThemeAccentChanged: scheduleAccent()
  onAccentRGBChanged: scheduleAccent()

  Timer {
    id: accentTimer
    interval: 150
    onTriggered: {
      if (!root.active || !root.useThemeAccent) return
      if (root.busy) { restart(); return }
      if (/^[0-9a-fA-F]{6}$/.test(root.accentRGB))
        root.applyRequested(root.accentRGB)
    }
  }
  Text {
    visible: root.title !== ""
    text: root.title
    textFormat: Text.PlainText
    color: Commons.Color.foreground
  }
  RowLayout {
    spacing: 8
    Controls.Switch {
      text: root.catalog.t("useThemeAccent")
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
    Layout.fillWidth: true
    enabled: !root.useThemeAccent
    placeholderText: root.catalog.t("colorHint")
    maximumLength: 7
    validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{6}/ }
  }
  Controls.Button {
    text: root.catalog.t("applyColor")
    enabled: root.active && (root.useThemeAccent || colorInput.acceptableInput) && !root.busy
    onClicked: root.applyRequested(root.useThemeAccent ? root.accentRGB : colorInput.text)
  }
}
