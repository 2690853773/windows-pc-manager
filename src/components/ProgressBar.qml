import QtQuick
import QtQuick.Controls
import "../../assets/styles" as Style

Item {
    id: root
    property real value: 0
    property color barColor: Style.Theme.palette.primary
    property int heightValue: 10

    implicitHeight: heightValue

    Rectangle {
        anchors.fill: parent
        radius: root.heightValue / 2
        color: Style.Theme.palette.bgElevated
    }

    Rectangle {
        width: Math.max(0, Math.min(parent.width, parent.width * (root.value / 100.0)))
        height: parent.height
        radius: root.heightValue / 2
        color: root.barColor
        Behavior on width {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
    }
}
