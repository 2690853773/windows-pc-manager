import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../../assets/styles" as Style
import "../components"

Item {
    id: root
    property var bridge
    signal notify(string message)
    signal requestNavigate(int index)

    ListModel { id: driveModel }
    ListModel { id: nicModel }
    ListModel { id: gpuModel }
    ListModel { id: driverModel }

    function parse(raw) {
        try { return JSON.parse(raw) } catch (e) { return { ok: false, message: "解析失败" } }
    }

    function refresh() {
        var hw = parse(bridge.getHardwareInfo())
        if (hw.ok) {
            machineName.text = "主机: " + hw.info.computer
            osName.text = "系统: " + hw.info.system
            cpuName.text = "处理器: " + hw.info.processor
            bootTime.text = "启动时间: " + hw.info.boot

            driveModel.clear()
            for (var i = 0; i < hw.info.drives.length; i++) driveModel.append(hw.info.drives[i])
            nicModel.clear()
            for (var j = 0; j < hw.info.network.length; j++) nicModel.append(hw.info.network[j])
            gpuModel.clear()
            for (var k = 0; k < hw.info.gpu.length; k++) gpuModel.append(hw.info.gpu[k])
            driverModel.clear()
            for (var t = 0; t < hw.info.drivers.length; t++) driverModel.append(hw.info.drivers[t])
        }

        var osd = parse(bridge.getOSInfo())
        if (osd.ok) {
            osVersion.text = "版本: " + osd.name + " " + osd.release + " (" + osd.arch + ")"
            osInstall.text = "安装时间: " + osd.installed
            pyVersion.text = "运行环境: Python " + osd.python
        }
    }

    function exportReport() {
        var path = reportPath.text.trim()
        if (!path || path.length === 0) {
            notify("请先输入导出路径")
            return
        }
        var result = parse(bridge.exportSystemReport(path))
        notify(result.message || (result.ok ? "导出成功" : "导出失败"))
    }

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Card {
            Layout.fillWidth: true
            implicitHeight: 138
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "系统信息总览"
                        font.family: "Microsoft YaHei UI"
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: Style.Theme.palette.text
                    }
                    Button { text: "刷新"; iconGlyph: "\uE72C"; onClicked: refresh() }
                    Button { text: "导出报告"; iconGlyph: "\uE74E"; backgroundColor: Style.Theme.palette.secondary; onClicked: exportReport() }
                    Button { text: "网络工具"; iconGlyph: "\uE839"; outlined: true; onClicked: requestNavigate(6) }
                }
                Text { id: machineName; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 13 }
                Text { id: osName; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 13 }
                Text { id: cpuName; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 13; elide: Text.ElideRight }
                RowLayout {
                    Layout.fillWidth: true
                    Text { id: bootTime; Layout.fillWidth: true; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 12; elide: Text.ElideRight }
                    Text { id: osVersion; Layout.fillWidth: true; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 12; elide: Text.ElideRight }
                    Text { id: osInstall; Layout.fillWidth: true; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 12; elide: Text.ElideRight }
                    Text { id: pyVersion; Layout.fillWidth: true; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 12; elide: Text.ElideRight }
                }
                AppTextField {
                    id: reportPath
                    Layout.fillWidth: true
                    text: "C:/Users/Public/system-report.txt"
                    placeholderText: "报告导出路径"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Card {
                Layout.fillWidth: true
                Layout.preferredWidth: 0.54 * parent.width
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Text { text: "磁盘与网络"; font.family: "Microsoft YaHei UI"; font.pixelSize: 15; font.weight: Font.DemiBold; color: Style.Theme.palette.text }
                    Text { text: "磁盘列表"; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 12 }
                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 190
                        clip: true
                        model: driveModel
                        delegate: Column {
                            required property string name
                            required property string total
                            required property string free
                            required property real percent
                            width: ListView.view.width
                            spacing: 2
                            Text {
                                text: name + "  已用 " + percent + "%   总容量 " + total + "   可用 " + free
                                color: Style.Theme.palette.text
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 12
                            }
                        }
                    }
                    Text { text: "网络接口"; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 12 }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: nicModel
                        delegate: Text {
                            required property string name
                            required property string address
                            width: ListView.view.width
                            text: name + "  " + address
                            color: Style.Theme.palette.text
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.preferredWidth: 0.46 * parent.width
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Text { text: "显卡与驱动"; font.family: "Microsoft YaHei UI"; font.pixelSize: 15; font.weight: Font.DemiBold; color: Style.Theme.palette.text }
                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120
                        clip: true
                        model: gpuModel
                        delegate: Text {
                            required property string name
                            required property string driver
                            width: ListView.view.width
                            text: name + "  驱动: " + driver
                            color: Style.Theme.palette.text
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: Style.Theme.palette.bgElevated
                        border.color: Style.Theme.palette.border
                        ListView {
                            anchors.fill: parent
                            anchors.margins: 6
                            clip: true
                            model: driverModel
                            delegate: Text {
                                required property string name
                                required property string version
                                width: ListView.view.width
                                text: name + "  " + version
                                color: Style.Theme.palette.textSubtle
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
