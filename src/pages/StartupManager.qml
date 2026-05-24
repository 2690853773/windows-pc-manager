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

    property string actionType: ""
    property string actionName: ""
    property string actionScope: ""
    property string verifyText: ""

    ListModel { id: startupModel }

    function parse(raw) {
        try { return JSON.parse(raw) } catch (e) { return { ok: false, message: "解析失败" } }
    }

    function refresh() {
        startupModel.clear()
        var data = parse(bridge.listStartupItems())
        if (!data.ok) {
            notify(data.message || "读取启动项失败")
            return
        }
        for (var i = 0; i < data.items.length; i++)
            startupModel.append(data.items[i])
        titleText.text = "启动项管理（" + data.items.length + "）"
    }

    function doAction(type, name, scope) {
        var status = parse(bridge.adminStatus())
        if (status.ok && !status.isAdmin) {
            notify("修改启动项需要管理员权限")
            return
        }

        actionType = type
        actionName = name
        actionScope = scope
        verifyText = ""

        var actionNameText = type === "disable" ? "禁用" : (type === "enable" ? "启用" : "删除")
        confirmTip.text = "将" + actionNameText + "启动项“" + name + "”，请输入“确认执行”继续。"
        actionDialog.open()
    }

    function runAction() {
        if (verifyText !== "确认执行") {
            notify("请输入“确认执行”后再继续")
            return
        }

        var result
        if (actionType === "disable")
            result = parse(bridge.disableStartup(actionName, actionScope))
        else if (actionType === "enable")
            result = parse(bridge.enableStartup(actionName, actionScope))
        else
            result = parse(bridge.deleteStartup(actionName, actionScope))

        notify(result.message || (result.ok ? "操作成功" : "操作失败"))
        refresh()
    }

    Dialog {
        id: actionDialog
        title: "高风险操作确认"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: runAction()
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Card {
            Layout.fillWidth: true
            implicitHeight: 84
            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                Text {
                    id: titleText
                    Layout.fillWidth: true
                    text: "启动项管理"
                    font.family: "Microsoft YaHei UI"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: Style.Theme.palette.text
                }
                Button { text: "刷新"; iconGlyph: "\uE72C"; onClicked: refresh() }
                Button { text: "进程管理"; iconGlyph: "\uE9F9"; outlined: true; onClicked: requestNavigate(4) }
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ListView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                model: startupModel
                delegate: Rectangle {
                    required property string name
                    required property string path
                    required property bool enabled
                    required property string scope
                    required property string impact

                    width: ListView.view.width
                    height: 46
                    color: index % 2 === 0 ? "transparent" : Qt.tint(Style.Theme.palette.bgElevated, Qt.rgba(1, 1, 1, 0.20))

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: name + "  [" + scope + "]"
                            color: Style.Theme.palette.text
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        Text {
                            text: enabled ? "已启用" : "已禁用"
                            color: enabled ? Style.Theme.palette.accent : Style.Theme.palette.textSubtle
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 12
                        }
                        Text {
                            text: impact
                            width: 36
                            horizontalAlignment: Text.AlignHCenter
                            color: Style.Theme.palette.textSubtle
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 12
                        }
                        Button {
                            text: "路径"
                            outlined: true
                            implicitWidth: 56
                            implicitHeight: 30
                            onClicked: {
                                var result = parse(bridge.openPath(path))
                                if (!result.ok)
                                    notify(result.message || "打开路径失败")
                            }
                        }
                        Button {
                            text: enabled ? "禁用" : "启用"
                            implicitWidth: 64
                            implicitHeight: 30
                            backgroundColor: enabled ? "#E67E22" : Style.Theme.palette.secondary
                            onClicked: doAction(enabled ? "disable" : "enable", name, scope)
                        }
                        Button {
                            text: "删除"
                            implicitWidth: 58
                            implicitHeight: 30
                            backgroundColor: "#E74C3C"
                            onClicked: doAction("delete", name, scope)
                        }
                    }
                }
            }
        }
    }
}
