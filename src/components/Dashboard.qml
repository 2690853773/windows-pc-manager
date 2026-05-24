import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../assets/styles" as Style
import "."

Card {
    id: root
    property alias title: titleText.text
    property alias value: valueText.text
    property alias subtitle: subtitleText.text
    property color tone: Style.Theme.palette.primary

    implicitHeight: 140

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.tint(Style.Theme.palette.bgCard, Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.06))
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        Text {
            id: titleText
            color: Style.Theme.palette.textSubtle
            font.family: "Microsoft YaHei UI"
            font.pixelSize: 13
        }

        Text {
            id: valueText
            color: Style.Theme.palette.text
            font.family: "Microsoft YaHei UI"
            font.pixelSize: 34
            font.weight: Font.DemiBold
        }

        Text {
            id: subtitleText
            color: Style.Theme.palette.textSubtle
            font.family: "Microsoft YaHei UI"
            font.pixelSize: 12
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }
    }
}
