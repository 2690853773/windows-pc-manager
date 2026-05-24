import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../assets/styles" as Style
import "../components"

Item {
    id: root
    property var bridge
    signal notify(string message)
    signal requestNavigate(int index)

    property string pendingTaskId: ""

    ListModel { id: taskModel }
    ListModel { id: logModel }

    function parse(raw) {
        try { return JSON.parse(raw) } catch (e) { return { ok: false, message: "解析失败" } }
    }

    function loadTasks() {
        taskModel.clear()
        var data = parse(bridge.listTasks())
        if (!data.ok) {
            notify(data.message || "读取任务失败")
            return
        }
        for (var i = 0; i < data.items.length; i++)
            taskModel.append({
                taskId: data.items[i].id,
                name: data.items[i].name,
                action: data.items[i].action,
                status: data.items[i].status,
                message: data.items[i].message,
                createdAt: data.items[i].createdAt,
                updatedAt: data.items[i].updatedAt
            })
        taskCount.text = "任务队列: " + data.items.length
    }

    function loadLogs() {
        logModel.clear()
        var data = parse(bridge.listTaskLogs())
        if (!data.ok) {
            notify(data.message || "读取日志失败")
            return
        }
        for (var i = 0; i < data.items.length; i++)
            logModel.append(data.items[i])
    }

    function createTask() {
        var payload = {}
        if (actionBox.selectedAction === "scan_large") {
            payload.root = "C:/Users"
            payload.min_mb = 100
        }
        if (actionBox.selectedAction === "export_report") {
            payload.path = "C:/Users/Public/system-report-task.txt"
        }
        var result = parse(bridge.createTask(taskName.text.trim(), actionBox.selectedAction, JSON.stringify(payload)))
        notify(result.message || (result.ok ? "任务已创建" : "创建失败"))
        loadTasks()
        loadLogs()
    }

    function runTask(taskId) {
        var result = parse(bridge.runTask(taskId))
        if (!result.ok) {
            notify(result.message || "执行失败")
            return
        }
        if (result.result && result.result.ok === false)
            notify(result.result.message || "任务执行失败")
        else
            notify("任务执行完成")
        loadTasks()
        loadLogs()
    }

    function retryTask(taskId) {
        var result = parse(bridge.retryTask(taskId))
        notify(result.message || (result.ok ? "任务已重试" : "重试失败"))
        loadTasks()
        loadLogs()
    }

    function removeTask(taskId) {
        var result = parse(bridge.removeTask(taskId))
        notify(result.message || (result.ok ? "任务已删除" : "删除失败"))
        loadTasks()
        loadLogs()
    }

    function rollbackDesktopOrganize() {
        var status = parse(bridge.adminStatus())
        if (status.ok && !status.isAdmin) {
            notify("撤销操作建议在管理员模式执行")
        }
        var result = parse(bridge.desktopUndo())
        notify(result.message || (result.ok ? ("已恢复 " + result.restored + " 个文件") : "撤销失败"))
        loadLogs()
    }

    Component.onCompleted: {
        loadTasks()
        loadLogs()
    }

    Timer {
        interval: 3000
        running: root.visible
        repeat: true
        onTriggered: {
            loadTasks()
            loadLogs()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Card {
            Layout.fillWidth: true
            implicitHeight: 118
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        id: taskCount
                        Layout.fillWidth: true
                        text: "任务队列: 0"
                        font.family: "Microsoft YaHei UI"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: Style.Theme.palette.text
                    }
                    Button { text: "刷新"; iconGlyph: "\uE72C"; onClicked: { loadTasks(); loadLogs() } }
                    Button { text: "系统清理"; iconGlyph: "\uE74D"; outlined: true; onClicked: requestNavigate(2) }
                }
                RowLayout {
                    Layout.fillWidth: true
                    AppTextField { id: taskName; Layout.fillWidth: true; placeholderText: "任务名称（例如：每日垃圾扫描）" }
                    ComboBox {
                        id: actionBox
                        Layout.preferredWidth: 200
                        model: [
                            { "text": "扫描垃圾文件", "value": "scan_junk" },
                            { "text": "扫描大文件", "value": "scan_large" },
                            { "text": "读取进程列表", "value": "list_processes" },
                            { "text": "读取启动项", "value": "list_startups" },
                            { "text": "读取网络信息", "value": "network_info" },
                            { "text": "撤销桌面整理", "value": "desktop_undo" },
                            { "text": "导出系统报告", "value": "export_report" }
                        ]
                        textRole: "text"
                        property string selectedAction: model[currentIndex].value
                        onCurrentIndexChanged: selectedAction = model[currentIndex].value
                    }
                    Button { text: "创建任务"; iconGlyph: "\uE710"; onClicked: createTask() }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8
                    Text { text: "任务列表"; font.family: "Microsoft YaHei UI"; font.pixelSize: 14; font.weight: Font.DemiBold; color: Style.Theme.palette.text }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: taskModel
                        delegate: Rectangle {
                            required property string taskId
                            required property string name
                            required property string action
                            required property string status
                            required property string message
                            required property string createdAt
                            required property string updatedAt
                            width: ListView.view.width
                            height: 56
                            color: index % 2 === 0 ? "transparent" : Qt.tint(Style.Theme.palette.bgElevated, Qt.rgba(1, 1, 1, 0.23))

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: name + " (" + action + ")"
                                        font.family: "Microsoft YaHei UI"
                                        font.pixelSize: 12
                                        color: Style.Theme.palette.text
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: "状态: " + status + "  " + (updatedAt && updatedAt.length > 0 ? updatedAt : createdAt)
                                        font.family: "Microsoft YaHei UI"
                                        font.pixelSize: 11
                                        color: Style.Theme.palette.textSubtle
                                        elide: Text.ElideRight
                                    }
                                }
                                Button { text: "执行"; implicitWidth: 52; implicitHeight: 28; onClicked: runTask(taskId) }
                                Button { text: "重试"; outlined: true; implicitWidth: 52; implicitHeight: 28; onClicked: retryTask(taskId) }
                                Button { text: "删除"; backgroundColor: "#E74C3C"; implicitWidth: 52; implicitHeight: 28; onClicked: removeTask(taskId) }
                            }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "执行日志"
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: Style.Theme.palette.text
                        }
                        Button {
                            text: "清空日志"
                            outlined: true
                            onClicked: {
                                var result = parse(bridge.clearTaskLogs())
                                notify(result.message || (result.ok ? "日志已清空" : "清空失败"))
                                loadLogs()
                            }
                        }
                        Button {
                            text: "回滚桌面整理"
                            iconGlyph: "\uE7A7"
                            backgroundColor: Style.Theme.palette.secondary
                            onClicked: rollbackDesktopOrganize()
                        }
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: logModel
                        delegate: ColumnLayout {
                            required property string time
                            required property string action
                            required property string status
                            required property string message
                            width: ListView.view.width
                            spacing: 2
                            Text {
                                text: time + "  " + action + "  [" + status + "]"
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 11
                                color: status === "success" ? Style.Theme.palette.accent : "#D64545"
                                elide: Text.ElideRight
                            }
                            Text {
                                text: message
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 11
                                color: Style.Theme.palette.textSubtle
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Style.Theme.palette.border
                                opacity: 0.5
                            }
                        }
                    }
                }
            }
        }
    }
}
