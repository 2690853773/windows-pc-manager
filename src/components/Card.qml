import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../assets/styles" as Style

Rectangle {
    id: root
    property bool elevated: true
    radius: 12
    color: Style.Theme.palette.bgCard
    border.color: Style.Theme.palette.border
    border.width: 1

    layer.enabled: elevated
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 8
        shadowBlur: 0.5
        shadowColor: Style.Theme.palette.shadow
    }
}
