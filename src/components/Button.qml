import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../assets/styles" as Style

Button {
    id: root
    property string iconGlyph: ""
    property color backgroundColor: Style.Theme.palette.primary
    property color hoverColor: Qt.darker(backgroundColor, 1.08)
    property color filledTextColor: "#FFFFFF"
    property color outlinedTextColor: Style.Theme.palette.primary
    property color disabledTextColor: "#9AA4B0"
    property bool outlined: false
    readonly property color effectiveTextColor: outlined ? outlinedTextColor : filledTextColor

    implicitHeight: 38
    implicitWidth: 120

    contentItem: RowLayout {
        spacing: 6
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        Text {
            visible: root.iconGlyph.length > 0
            text: root.iconGlyph
            color: root.enabled ? root.effectiveTextColor : root.disabledTextColor
            font.family: "Segoe MDL2 Assets"
            font.pixelSize: 14
        }
        Text {
            text: root.text
            color: root.enabled ? root.effectiveTextColor : root.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: "Microsoft YaHei UI"
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }

    background: Rectangle {
        radius: 10
        color: root.outlined
               ? (root.hovered ? Qt.tint(Style.Theme.palette.bgElevated, Qt.rgba(1, 1, 1, 0.32)) : Qt.tint(Style.Theme.palette.bgCard, Qt.rgba(1, 1, 1, 0.14)))
               : (root.hovered ? root.hoverColor : root.backgroundColor)
        border.width: 1
        border.color: root.outlined ? Style.Theme.palette.primary : Qt.tint(root.backgroundColor, Qt.rgba(0, 0, 0, 0.12))
        opacity: root.pressed ? 0.82 : (root.enabled ? 1.0 : 0.55)
    }
}
