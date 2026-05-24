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

    ListModel { id: nicModel }
    ListModel { id: portModel }

    function parse(raw) {
        try { return JSON.parse(raw) } catch (e) { return { ok: false, message: "解析失败" } }
    }

    function refreshInfo() {
        nicModel.clear()
        var data = parse(bridge.networkInfo())
        if (!data.ok) {
            notify(data.message || "读取网络信息失败")
            return
        }
        hostText.text = "主机名: " + data.host
        publicText.text = "公网IP: " + data.publicIp
        dnsText.text = "DNS: " + (data.dns || "未知")
        for (var i = 0; i < data.items.length; i++) nicModel.append(data.items[i])
    }

    function runPing() {
        var result = parse(bridge.ping(hostInput.text.trim()))
        pingText.text = result.ok ? result.output : (result.message || "Ping失败")
    }

    function runSpeed() {
        var result = parse(bridge.speedTest())
        if (result.ok) {
            speedText.text = "下载 " + result.download + " Mbps    上传 " + result.upload + " Mbps    延迟 " + result.ping + " ms"
        } else {
            speedText.text = result.message || "测速失败"
        }
    }

    function scanPorts() {
        portModel.clear()
        var data = parse(bridge.scanPorts(portHost.text.trim()))
        if (!data.ok) {
            notify(data.message || "扫描失败")
            return
        }
        for (var i = 0; i < data.items.length; i++) portModel.append(data.items[i])
    }

    Component.onCompleted: {
        refreshInfo()
        scanPorts()
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

            Card {
                Layout.fillWidth: true
                implicitHeight: 160
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "网络信息"
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            color: Style.Theme.palette.text
                        }
                        Button { text: "刷新"; iconGlyph: "\uE72C"; onClicked: refreshInfo() }
                        Button { text: "系统信息"; iconGlyph: "\uE946"; outlined: true; onClicked: requestNavigate(3) }
                    }
                    Text { id: hostText; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 13 }
                    Text { id: publicText; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 13 }
                    Text { id: dnsText; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 13 }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: nicModel
                        delegate: Text {
                            required property string name
                            required property string ip
                            required property string mac
                            width: ListView.view.width
                            text: name + "  IP: " + ip + "  MAC: " + mac
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 12
                            color: Style.Theme.palette.text
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                implicitHeight: 168
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    Text { text: "网络诊断"; font.family: "Microsoft YaHei UI"; font.pixelSize: 16; font.weight: Font.DemiBold; color: Style.Theme.palette.text }
                    RowLayout {
                        Layout.fillWidth: true
                        AppTextField { id: hostInput; Layout.fillWidth: true; text: "www.baidu.com"; placeholderText: "Ping目标地址" }
                        Button { text: "Ping"; iconGlyph: "\uE717"; onClicked: runPing() }
                        Button { text: "测速"; iconGlyph: "\uE9CA"; backgroundColor: Style.Theme.palette.secondary; onClicked: runSpeed() }
                    }
                    AppTextArea {
                        id: pingText
                        Layout.fillWidth: true
                        Layout.preferredHeight: 68
                        readOnly: true
                        wrapMode: TextEdit.Wrap
                        placeholderText: "Ping输出"
                    }
                    Text { id: speedText; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 12 }
                }
            }

            Card {
                Layout.fillWidth: true
                implicitHeight: 240
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "端口扫描"; font.family: "Microsoft YaHei UI"; font.pixelSize: 16; font.weight: Font.DemiBold; color: Style.Theme.palette.text }
                        Item { Layout.fillWidth: true }
                        AppTextField { id: portHost; Layout.preferredWidth: 200; text: "127.0.0.1"; placeholderText: "扫描主机" }
                        Button { text: "开始扫描"; iconGlyph: "\uE8A7"; onClicked: scanPorts() }
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: portModel
                        delegate: RowLayout {
                            required property int port
                            required property bool open
                            width: ListView.view.width
                            height: 30
                            Text { text: "端口 " + port; color: Style.Theme.palette.text; font.family: "Microsoft YaHei UI"; font.pixelSize: 12 }
                            Text {
                                text: open ? "开放" : "关闭"
                                color: open ? Style.Theme.palette.accent : Style.Theme.palette.textSubtle
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }
}
