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

    property string customRuleJson: ""
    property string desktopPath: ""

    function parse(raw) {
        try { return JSON.parse(raw) } catch (e) { return { ok: false, message: "数据解析失败" } }
    }

    function refresh() {
        previewModel.clear()
        var data = parse(bridge.desktopPreview(customRuleJson))
        if (!data.ok) {
            notify(data.message || "读取失败")
            return
        }
        desktopPath = data.desktopPath || ""
        for (var i = 0; i < data.items.length; i++) {
            previewModel.append(data.items[i])
        }
        countLabel.text = "待整理文件: " + data.count
    }

    Component.onCompleted: refresh()

    ListModel { id: previewModel }

    MessageDialog {
        id: organizeConfirm
        title: "确认操作"
        text: "确定开始整理桌面文件吗？该操作会移动文件到分类目录。"
        buttons: MessageDialog.Ok | MessageDialog.Cancel
        onAccepted: {
            var result = parse(bridge.desktopOrganize(customRuleJson, backupCheck.checked))
            notify(result.message || (result.ok ? ("整理完成，处理 " + result.moved + " 个文件") : "整理失败"))
            refresh()
        }
    }

    MessageDialog {
        id: undoConfirm
        title: "确认撤销"
        text: "确定撤销最近一次桌面整理吗？"
        buttons: MessageDialog.Ok | MessageDialog.Cancel
        onAccepted: {
            var result = parse(bridge.desktopUndo())
            notify(result.message || (result.ok ? ("已恢复 " + result.restored + " 个文件") : "撤销失败"))
            refresh()
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
                anchors.margins: 14
                spacing: 8
                Text {
                    text: "桌面整理"
                    font.family: "Microsoft YaHei UI"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    color: Style.Theme.palette.text
                }
                Text {
                    id: countLabel
                    text: "待整理文件: 0"
                    font.family: "Microsoft YaHei UI"
                    font.pixelSize: 13
                    color: Style.Theme.palette.textSubtle
                }
                Text {
                    text: desktopPath.length > 0 ? ("桌面目录: " + desktopPath) : "桌面目录: -"
                    font.family: "Microsoft YaHei UI"
                    font.pixelSize: 12
                    color: Style.Theme.palette.textSubtle
                    elide: Text.ElideMiddle
                }
                RowLayout {
                    spacing: 10
                    CheckBox {
                        id: backupCheck
                        text: "整理前自动备份"
                        checked: true
                    }
                    Button { text: "刷新预览"; iconGlyph: "\uE72C"; outlined: true; onClicked: refresh() }
                    Button { text: "一键整理"; iconGlyph: "\uECA5"; onClicked: organizeConfirm.open() }
                    Button {
                        text: "撤销上次整理"
                        iconGlyph: "\uE7A7"
                        backgroundColor: Style.Theme.palette.secondary
                        onClicked: undoConfirm.open()
                    }
                    Button { text: "前往文件管理"; iconGlyph: "\uE8B7"; outlined: true; onClicked: requestNavigate(8) }
                }
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "分类规则(JSON)"
                        font.family: "Microsoft YaHei UI"
                        font.pixelSize: 13
                        color: Style.Theme.palette.textSubtle
                    }
                    Button {
                        text: "应用规则"
                        outlined: true
                        onClicked: {
                            customRuleJson = ruleEdit.text.trim()
                            refresh()
                        }
                    }
                }
                AppTextArea {
                    id: ruleEdit
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    placeholderText: "{\"文档\": [\".txt\", \".docx\"], \"图片\": [\".png\", \".jpg\"]}"
                    wrapMode: TextEdit.Wrap
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: Style.Theme.palette.bgElevated
                    border.width: 1
                    border.color: Style.Theme.palette.border
                    ListView {
                        anchors.fill: parent
                        anchors.margins: 6
                        clip: true
                        model: previewModel
                        delegate: Rectangle {
                            required property string name
                            required property string category
                            required property int size
                            width: ListView.view.width
                            height: 38
                            color: index % 2 === 0 ? "transparent" : Qt.tint(Style.Theme.palette.bgCard, Qt.rgba(0, 0, 0, 0.02))
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                Text {
                                    Layout.fillWidth: true
                                    text: name
                                    elide: Text.ElideRight
                                    color: Style.Theme.palette.text
                                    font.family: "Microsoft YaHei UI"
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: category
                                    color: Style.Theme.palette.primary
                                    font.family: "Microsoft YaHei UI"
                                    font.pixelSize: 12
                                }
                                Text {
                                    text: Math.round(size / 1024) + " KB"
                                    color: Style.Theme.palette.textSubtle
                                    font.family: "Microsoft YaHei UI"
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: previewModel.count === 0
                        text: "暂无可整理文件，点击“刷新预览”重新扫描。"
                        color: Style.Theme.palette.textSubtle
                        font.family: "Microsoft YaHei UI"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
