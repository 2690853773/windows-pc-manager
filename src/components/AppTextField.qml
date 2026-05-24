import QtQuick
import QtQuick.Controls
import "../../assets/styles" as Style

TextField {
    id: root
    color: Style.Theme.palette.text
    font.family: "Microsoft YaHei UI"
    font.pixelSize: 13
    padding: 10
    selectionColor: Qt.tint(Style.Theme.palette.primary, Qt.rgba(1, 1, 1, 0.72))
    selectedTextColor: Style.Theme.palette.text

    background: Rectangle {
        radius: 8
        color: root.enabled ? Style.Theme.palette.bgCard : Qt.tint(Style.Theme.palette.bgElevated, Qt.rgba(1, 1, 1, 0.35))
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Style.Theme.palette.primary : Style.Theme.palette.border
    }
}
