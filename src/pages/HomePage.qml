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

    property real cpu: 0
    property real memory: 0
    property real disk: 0
    property string uptime: "--"
    property string temperature: "--"
    property string memoryDetail: "-- / --"
    property string diskDetail: "-- / --"
    property bool isAdmin: false

    function parse(raw) {
        try { return JSON.parse(raw) } catch (e) { return { ok: false, message: "解析失败" } }
    }

    function refreshSnapshot() {
        var data = parse(bridge.getSnapshot())
        if (!data.ok) {
            notify(data.message || "读取系统信息失败")
            return
        }
        cpu = data.cpu
        memory = data.memory
        disk = data.disk
        uptime = data.uptime
        temperature = data.temperature
        memoryDetail = data.memoryUsed + " / " + data.memoryTotal
        diskDetail = data.diskUsed + " / " + data.diskTotal
    }

    function refreshAdmin() {
        var status = parse(bridge.adminStatus())
        if (status.ok)
            isAdmin = status.isAdmin
    }

    Component.onCompleted: {
        refreshSnapshot()
        refreshAdmin()
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.visible
        onTriggered: refreshSnapshot()
    }

    MessageDialog {
        id: restoreDialog
        title: "确认创建还原点"
        text: "系统将创建新的还原点，是否继续？"
        buttons: MessageDialog.Ok | MessageDialog.Cancel
        onAccepted: {
            var result = parse(bridge.createRestorePoint())
            notify(result.message || (result.ok ? "还原点创建请求已提交" : "创建失败"))
        }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 36
        clip: true

        ColumnLayout {
            id: contentCol
            width: root.width - 32
            x: 16
            y: 16
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Dashboard {
                    Layout.fillWidth: true
                    title: "CPU 使用率"
                    value: cpu.toFixed(1) + "%"
                    subtitle: "实时处理器负载"
                    tone: Style.Theme.palette.primary
                }
                Dashboard {
                    Layout.fillWidth: true
                    title: "内存占用"
                    value: memory.toFixed(1) + "%"
                    subtitle: memoryDetail
                    tone: Style.Theme.palette.secondary
                }
                Dashboard {
                    Layout.fillWidth: true
                    title: "磁盘占用"
                    value: disk.toFixed(1) + "%"
                    subtitle: diskDetail
                    tone: Style.Theme.palette.accent
                }
            }

            Card {
                Layout.fillWidth: true
                implicitHeight: 236
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10
                    Text {
                        text: "系统运行状态"
                        font.family: "Microsoft YaHei UI"
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: Style.Theme.palette.text
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text { text: "CPU"; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 13 }
                        ProgressBar { Layout.fillWidth: true; value: cpu }
                        Text { text: cpu.toFixed(1) + "%"; color: Style.Theme.palette.text; font.family: "Microsoft YaHei UI"; font.pixelSize: 13 }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text { text: "内存"; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 13 }
                        ProgressBar { Layout.fillWidth: true; value: memory; barColor: Style.Theme.palette.secondary }
                        Text { text: memory.toFixed(1) + "%"; color: Style.Theme.palette.text; font.family: "Microsoft YaHei UI"; font.pixelSize: 13 }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text { text: "磁盘"; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 13 }
                        ProgressBar { Layout.fillWidth: true; value: disk; barColor: Style.Theme.palette.accent }
                        Text { text: disk.toFixed(1) + "%"; color: Style.Theme.palette.text; font.family: "Microsoft YaHei UI"; font.pixelSize: 13 }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 20
                        Text { text: "运行时长: " + uptime; font.family: "Microsoft YaHei UI"; font.pixelSize: 13; color: Style.Theme.palette.textSubtle }
                        Text { text: "温度: " + temperature; font.family: "Microsoft YaHei UI"; font.pixelSize: 13; color: Style.Theme.palette.textSubtle }
                        Text {
                            text: isAdmin ? "当前权限: 管理员" : "当前权限: 标准用户"
                            color: isAdmin ? Style.Theme.palette.accent : "#B76E00"
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 13
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                implicitHeight: 116
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    Text {
                        text: "快捷操作"
                        font.family: "Microsoft YaHei UI"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: Style.Theme.palette.text
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Button { text: "刷新状态"; iconGlyph: "\uE72C"; onClicked: { refreshSnapshot(); notify("系统状态已刷新") } }
                        Button { text: "创建还原点"; iconGlyph: "\uE777"; backgroundColor: Style.Theme.palette.secondary; onClicked: restoreDialog.open() }
                        Button { text: "前往系统清理"; iconGlyph: "\uE74D"; outlined: true; onClicked: requestNavigate(2) }
                        Button { text: "前往进程管理"; iconGlyph: "\uE9F9"; outlined: true; onClicked: requestNavigate(4) }
                    }
                }
            }
        }
    }
}
