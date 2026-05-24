import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Window
import "../../assets/styles" as Style
import "../components"

Item {
    id: root
    property var bridge
    signal notify(string message)
    signal requestNavigate(int index)

    property bool timerRunning: false
    property int timerValue: 0
    property int countdownValue: 0
    property string generatedText: ""

    function evaluateExpression(expr) {
        try {
            if (!expr || expr.trim().length === 0) return "0"
            var safe = expr.replace(/[^0-9+\-*/().%^ ]/g, "")
            var fn = Function("return (" + safe + ")")
            var result = fn()
            return String(result)
        } catch (e) {
            return "表达式错误"
        }
    }

    Timer {
        interval: 1000
        running: timerRunning && root.visible
        repeat: true
        onTriggered: {
            timerValue += 1
            if (countdownValue > 0) {
                countdownValue -= 1
                if (countdownValue === 0) {
                    timerRunning = false
                    notify("倒计时结束")
                }
            }
        }
    }

    FileDialog {
        id: openDialog
        title: "打开文本文件"
        nameFilters: ["文本文件 (*.txt *.md *.log)", "所有文件 (*)"]
        onAccepted: {
            notePath.text = selectedFile.toString()
            var result = parse(bridge.readTextFile(notePath.text))
            if (result.ok) {
                noteText.text = result.content
                notify("文件已打开")
            } else {
                notify(result.message || "读取失败")
            }
        }
    }

    FileDialog {
        id: saveDialog
        title: "保存文本文件"
        fileMode: FileDialog.SaveFile
        nameFilters: ["文本文件 (*.txt)", "所有文件 (*)"]
        onAccepted: {
            notePath.text = selectedFile.toString()
            saveConfirm.open()
        }
    }

    MessageDialog {
        id: saveConfirm
        title: "确认保存"
        text: "确认覆盖保存当前文本内容吗？"
        buttons: MessageDialog.Ok | MessageDialog.Cancel
        onAccepted: {
            var result = parse(bridge.writeTextFile(notePath.text, noteText.text))
            notify(result.message || (result.ok ? "保存成功" : "保存失败"))
        }
    }

    function parse(raw) {
        try { return JSON.parse(raw) } catch (e) { return { ok: false, message: "解析失败" } }
    }

    function randomPassword(length) {
        var chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%^&*"
        var out = ""
        for (var i = 0; i < length; i++) {
            out += chars.charAt(Math.floor(Math.random() * chars.length))
        }
        return out
    }

    function randomUuidLike() {
        function part(n) {
            var s = ""
            var hex = "0123456789abcdef"
            for (var i = 0; i < n; i++)
                s += hex.charAt(Math.floor(Math.random() * hex.length))
            return s
        }
        return part(8) + "-" + part(4) + "-" + part(4) + "-" + part(4) + "-" + part(12)
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 32
        clip: true

        ColumnLayout {
            id: contentCol
            width: root.width - 32
            x: 16
            y: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: 220
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        Text { text: "计算器"; font.family: "Microsoft YaHei UI"; font.pixelSize: 16; font.weight: Font.DemiBold; color: Style.Theme.palette.text }
                        AppTextField {
                            id: exprInput
                            Layout.fillWidth: true
                            placeholderText: "输入表达式，例如 (3+5)*2"
                        }
                        AppTextField {
                            id: exprResult
                            Layout.fillWidth: true
                            readOnly: true
                            placeholderText: "结果"
                        }
                        RowLayout {
                            Button {
                                text: "计算"
                                onClicked: exprResult.text = evaluateExpression(exprInput.text)
                            }
                            Button {
                                text: "清空"
                                outlined: true
                                onClicked: {
                                    exprInput.clear()
                                    exprResult.clear()
                                }
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: 220
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        Text { text: "计时器"; font.family: "Microsoft YaHei UI"; font.pixelSize: 16; font.weight: Font.DemiBold; color: Style.Theme.palette.text }
                        Text {
                            text: "正计时: " + timerValue + " 秒"
                            color: Style.Theme.palette.text
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 14
                        }
                        RowLayout {
                            AppTextField { id: countdownInput; placeholderText: "倒计时秒数"; Layout.preferredWidth: 140 }
                            Text {
                                text: countdownValue > 0 ? ("剩余: " + countdownValue + " 秒") : "未设置倒计时"
                                color: Style.Theme.palette.textSubtle
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 12
                            }
                        }
                        RowLayout {
                            Button {
                                text: timerRunning ? "暂停" : "开始"
                                onClicked: timerRunning = !timerRunning
                            }
                            Button {
                                text: "重置"
                                outlined: true
                                onClicked: {
                                    timerRunning = false
                                    timerValue = 0
                                    countdownValue = 0
                                }
                            }
                            Button {
                                text: "设定倒计时"
                                backgroundColor: Style.Theme.palette.secondary
                                onClicked: {
                                    var v = parseInt(countdownInput.text)
                                    if (isNaN(v) || v <= 0) {
                                        notify("请输入有效秒数")
                                        return
                                    }
                                    countdownValue = v
                                    timerRunning = true
                                }
                            }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                implicitHeight: 280
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "记事本"; font.family: "Microsoft YaHei UI"; font.pixelSize: 16; font.weight: Font.DemiBold; color: Style.Theme.palette.text }
                        Item { Layout.fillWidth: true }
                        AppTextField { id: notePath; Layout.preferredWidth: 260; placeholderText: "当前文件路径"; readOnly: true }
                        Button { text: "打开"; outlined: true; onClicked: openDialog.open() }
                        Button { text: "另存为"; outlined: true; onClicked: saveDialog.open() }
                    }
                    AppTextArea {
                        id: noteText
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "在这里记录内容..."
                        wrapMode: TextEdit.Wrap
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                implicitHeight: 170
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Text {
                        text: "随机生成工具"
                        font.family: "Microsoft YaHei UI"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: Style.Theme.palette.text
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: "生成 12 位密码"
                            iconGlyph: "\uE9A0"
                            onClicked: generatedText = randomPassword(12)
                        }
                        Button {
                            text: "生成 16 位密码"
                            iconGlyph: "\uE9A0"
                            backgroundColor: Style.Theme.palette.secondary
                            onClicked: generatedText = randomPassword(16)
                        }
                        Button {
                            text: "生成 UUID"
                            iconGlyph: "\uE8D5"
                            outlined: true
                            onClicked: generatedText = randomUuidLike()
                        }
                        Button {
                            text: "复制结果"
                            iconGlyph: "\uE8C8"
                            outlined: true
                            onClicked: {
                                if (!generatedText || generatedText.length === 0) {
                                    notify("请先生成内容")
                                    return
                                }
                                var result = parse(bridge.copyText(generatedText))
                                notify(result.message || (result.ok ? "已复制" : "复制失败"))
                            }
                        }
                    }
                    AppTextField {
                        Layout.fillWidth: true
                        readOnly: true
                        text: generatedText
                        placeholderText: "生成结果会显示在这里"
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                implicitHeight: 96
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    Text {
                        Layout.fillWidth: true
                        text: "截图工具（系统截图）"
                        font.family: "Microsoft YaHei UI"
                        font.pixelSize: 15
                        color: Style.Theme.palette.text
                    }
                    Button { text: "文件管理"; iconGlyph: "\uE8B7"; outlined: true; onClicked: requestNavigate(8) }
                    Button {
                        text: "全屏截图"
                        iconGlyph: "\uE722"
                        onClicked: {
                            notify("已调用系统截图工具")
                            Qt.openUrlExternally("ms-screenclip:")
                        }
                    }
                    Button {
                        text: "区域截图"
                        iconGlyph: "\uE70F"
                        backgroundColor: Style.Theme.palette.secondary
                        onClicked: {
                            notify("请选择截图区域")
                            Qt.openUrlExternally("ms-screenclip:")
                        }
                    }
                }
            }
        }
    }
}
