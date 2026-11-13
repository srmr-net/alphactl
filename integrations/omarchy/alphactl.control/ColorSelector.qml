pragma ComponentBehavior: Bound
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
  readonly property var choices: [
    {key: "themeAccent", value: Commons.Color.accent},
    {key: "themeForeground", value: Commons.Color.foreground},
    {key: "themeBackground", value: Commons.Color.background},
    {key: "themeUrgent", value: Commons.Color.urgent},
    {key: "themeMuted", value: Commons.Color.muted},
    {key: "red", value: "#ff0000"}, {key: "orange", value: "#ff8000"},
    {key: "yellow", value: "#ffff00"}, {key: "green", value: "#00ff00"},
    {key: "cyan", value: "#00ffff"}, {key: "blue", value: "#0000ff"},
    {key: "purple", value: "#ff00ff"}, {key: "white", value: "#ffffff"},
    {key: "customRGB", value: "transparent"}
  ]
  readonly property bool custom: picker.currentIndex === choices.length - 1
  readonly property color selectedColor: custom
    ? (colorInput.acceptableInput ? "#" + colorInput.text.replace(/^#/, "") : "transparent")
    : choices[picker.currentIndex].value
  readonly property string selectedRGB: selectedColor.toString().slice(-6)
  readonly property string choiceKey: choices[picker.currentIndex].key
  readonly property string customRGB: colorInput.text
  readonly property bool validSelection: !custom || colorInput.acceptableInput

  function restore(choice, rgb) {
    const index = choices.findIndex(entry => entry.key === choice)
    if (index < 0 || typeof rgb !== "string" || (rgb !== "" && !/^#?[0-9a-fA-F]{6}$/.test(rgb))) return false
    picker.currentIndex = index
    colorInput.text = rgb
    return true
  }

  signal applyRequested(string rgb)
  spacing: 8

  function schedulePreset() {
    if (active && !custom) presetTimer.restart()
    else presetTimer.stop()
  }
  onActiveChanged: schedulePreset()
  onSelectedRGBChanged: schedulePreset()

  Timer {
    id: presetTimer
    interval: 150
    onTriggered: {
      if (!root.active || root.custom) return
      if (root.busy) { restart(); return }
      if (/^[0-9a-fA-F]{6}$/.test(root.selectedRGB))
        root.applyRequested(root.selectedRGB)
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
    Controls.ComboBox {
      id: picker
      Layout.fillWidth: true
      model: root.choices.map(choice => root.catalog.t(choice.key))
      currentIndex: root.choices.length - 1
      onActivated: root.schedulePreset()
    }
    Rectangle {
      Layout.preferredWidth: 20
      Layout.preferredHeight: 20
      Layout.alignment: Qt.AlignVCenter
      color: root.selectedColor
      border.color: Commons.Color.foreground
      border.width: 1
      radius: 3
    }
  }
  RowLayout {
    spacing: 6
    Repeater {
      model: root.choices.slice(5, 13)
      delegate: Controls.Button {
        id: swatch
        required property var modelData
        required property int index
        implicitWidth: 28
        implicitHeight: 28
        padding: 4
        Accessible.name: root.catalog.t(modelData.key)
        contentItem: Rectangle {
          color: swatch.modelData.value
          border.color: Commons.Color.foreground
          border.width: 1
          radius: 3
        }
        onClicked: {
          picker.currentIndex = index + 5
          root.schedulePreset()
        }
      }
    }
  }
  Controls.TextField {
    id: colorInput
    visible: root.custom
    Layout.fillWidth: true
    enabled: root.custom
    placeholderText: root.catalog.t("colorHint")
    maximumLength: 7
    validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{6}/ }
  }
  Controls.Button {
    visible: root.custom
    text: root.catalog.t("applyColor")
    enabled: root.active && (!root.custom || colorInput.acceptableInput) && !root.busy
    onClicked: root.applyRequested(root.custom ? colorInput.text : root.selectedRGB)
  }
}
