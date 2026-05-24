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

    property int selectedPid: -1
    property bool selectedForce: false
    property string currentSort: "memory"
    property string verifyText: ""

    ListModel { id: processModel }

    function parse(raw) {
        try { return JSON.parse(raw) } catch (e) { return { ok: false, message: "解析失败" } }
    }

    function refresh() {
        processModel.clear()
        var data = parse(bridge.listProcesses(currentSort))
        if (!data.ok) {
            notify(data.message || "读取进程失败")
            return
        }
        for (var i = 0; i < data.items.length; i++)
            processModel.append(data.items[i])
        countText.text = "进程数量: " + data.items.length
    }

    function requestTerminate(pid, force) {
        var status = parse(bridge.adminStatus())
        if (status.ok && !status.isAdmin) {
            notify("结束进程需要管理员权限")
            return
        }
        selectedPid = pid
        selectedForce = force
        verifyText = ""
        confirmTip.text = force
                          ? ("将强制结束进程 PID " + pid + "，请输入“确认执行”继续。")
                          : ("将结束进程 PID " + pid + "，请输入“确认执行”继续。")
        terminateDialog.open()
    }

    function executeTerminate() {
        if (verifyText !== "确认执行") {
            notify("请输入“确认执行”后再继续")
            return
        }
        var result = parse(bridge.terminateProcess(selectedPid, selectedForce))
        notify(result.message || (result.ok ? "操作完成" : "操作失败"))
        refresh()
    }

    Dialog {
        id: terminateDialog
        title: "高风险操作确认"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: executeTerminate()
        contentItem: ColumnLayout {
            spacing: 10
            Text {
                id: confirmTip
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Style.Theme.palette.text
                font.family: "Microsoft YaHei UI"
                font.pixelSize: 13
            }
            AppTextField {
                Layout.fillWidth: true
                placeholderText: "请输入: 确认执行"
                onTextChanged: verifyText = text.trim()
            }
        }
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 3000
        running: root.visible
        repeat: true
        onTriggered: refresh()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Card {
            Layout.fillWidth: true
            implicitHeight: 86
            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                Text {
                    id: countText
                    Layout.fillWidth: true
                    text: "进程数量: 0"
                    color: Style.Theme.palette.text
                    font.family: "Microsoft YaHei UI"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                ComboBox {
                    id: sortBox
                    model: ["memory", "cpu", "name"]
                    onActivated: {
                        currentSort = model[index]
                        refresh()
                    }
                }
                Button { text: "刷新"; iconGlyph: "\uE72C"; onClicked: refresh() }
                Button { text: "启动项管理"; iconGlyph: "\uE768"; outlined: true; onClicked: requestNavigate(5) }
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                ListView {
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    model: processModel
                    delegate: Rectangle {
                        required property int pid
                        required property string name
                        required property real cpu
                        required property string memoryText
                        required property string user
                        required property string exe
                        width: ListView.view.width
                        height: 44
                        color: index % 2 === 0 ? "transparent" : Qt.tint(Style.Theme.palette.bgElevated, Qt.rgba(1, 1, 1, 0.25))

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10
                            Text { text: pid; width: 60; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 12 }
                            Text {
                                Layout.fillWidth: true
                                text: name
                                color: Style.Theme.palette.text
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            Text { text: "CPU " + cpu + "%"; width: 78; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 12 }
                            Text { text: memoryText; width: 96; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 12 }
                            Button {
                                text: "路径"
                                outlined: true
                                implicitWidth: 58
                                implicitHeight: 30
                                onClicked: {
                                    if (exe && exe.length > 0) {
                                        var res = parse(bridge.openPath(exe))
                                        if (!res.ok)
                                            notify(res.message || "打开失败")
                                    } else {
                                        notify("该进程无可用路径")
                                    }
                                }
                            }
                            Button {
                                text: "结束"
                                implicitWidth: 66
                                implicitHeight: 30
                                backgroundColor: "#E67E22"
                                onClicked: requestTerminate(pid, false)
                            }
                            Button {
                                text: "强制"
                                implicitWidth: 66
                                implicitHeight: 30
                                backgroundColor: "#E74C3C"
                                onClicked: requestTerminate(pid, true)
                            }
                        }
                    }
                }
            }
        }
    }
}
