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

    property string pendingDeletePaths: "[]"
    property string verifyText: ""
    property string riskAction: ""
    property string junkJobId: ""
    property string largeJobId: ""
    property bool junkLoading: false
    property bool largeLoading: false

    function parse(raw) {
        try { return JSON.parse(raw) } catch (e) { return { ok: false, message: "解析失败" } }
    }

    function checkAdminOrNotify() {
        var status = parse(bridge.adminStatus())
        if (!status.ok || status.isAdmin)
            return true
        notify("当前为标准模式。请使用管理员身份运行后执行高风险操作。")
        return false
    }

    function scanJunk() {
        if (junkLoading)
            return
        junkLoading = true
        junkModel.clear()
        totalJunk.text = "垃圾文件: 扫描中..."
        var start = parse(bridge.startScanJunkJob())
        if (!start.ok) {
            junkLoading = false
            notify(start.message || "启动扫描失败")
            return
        }
        junkJobId = start.jobId
    }

    function scanLarge() {
        if (largeLoading)
            return
        largeLoading = true
        largeModel.clear()
        totalLarge.text = "大文件: 扫描中..."
        var start = parse(bridge.startScanLargeFilesJob(searchRoot.text.trim(), minSize.value))
        if (!start.ok) {
            largeLoading = false
            notify(start.message || "启动扫描失败")
            return
        }
        largeJobId = start.jobId
    }

    function pollAsyncJobs() {
        if (junkLoading && junkJobId.length > 0) {
            var junkState = parse(bridge.pollJob(junkJobId))
            if (junkState.status === "done") {
                junkLoading = false
                junkJobId = ""
                var data = junkState.result
                if (!data || !data.ok) {
                    notify((data && data.message) || "扫描失败")
                } else {
                    totalJunk.text = "垃圾文件: " + data.count + " 项，共 " + data.totalText
                    for (var i = 0; i < data.items.length; i++) {
                        var row = data.items[i]
                        row.selected = false
                        junkModel.append(row)
                    }
                }
            } else if (junkState.status === "failed" || junkState.status === "missing") {
                junkLoading = false
                junkJobId = ""
                notify(junkState.message || "扫描失败")
            }
        }

        if (largeLoading && largeJobId.length > 0) {
            var largeState = parse(bridge.pollJob(largeJobId))
            if (largeState.status === "done") {
                largeLoading = false
                largeJobId = ""
                var largeData = largeState.result
                if (!largeData || !largeData.ok) {
                    notify((largeData && largeData.message) || "扫描失败")
                } else {
                    totalLarge.text = "大文件: " + largeData.count + " 项"
                    for (var j = 0; j < largeData.items.length; j++) {
                        var big = largeData.items[j]
                        big.selected = false
                        largeModel.append(big)
                    }
                }
            } else if (largeState.status === "failed" || largeState.status === "missing") {
                largeLoading = false
                largeJobId = ""
                notify(largeState.message || "扫描失败")
            }
        }
    }

    function collectSelected(modelObj) {
        var paths = []
        for (var i = 0; i < modelObj.count; i++) {
            var row = modelObj.get(i)
            if (row.selected === true)
                paths.push(row.path)
        }
        return paths
    }

    function beginRiskAction(actionName) {
        riskAction = actionName
        verifyText = ""
        riskDialog.open()
    }

    function removeSelected(modelObj) {
        var paths = collectSelected(modelObj)
        if (paths.length === 0) {
            notify("请先勾选要清理的文件")
            return
        }
        if (!checkAdminOrNotify())
            return
        pendingDeletePaths = JSON.stringify(paths)
        beginRiskAction("删除文件")
    }

    function executeRiskAction() {
        if (verifyText !== "确认执行") {
            notify("请输入“确认执行”后再继续")
            return
        }
        var result
        if (riskAction === "删除文件") {
            result = parse(bridge.cleanPaths(pendingDeletePaths))
            notify(result.ok ? ("已清理 " + result.cleaned + " 个项目") : (result.message || "清理失败"))
            scanJunk()
            scanLarge()
            return
        }
        if (riskAction === "清空回收站") {
            result = parse(bridge.clearRecycleBin())
            notify(result.message || (result.ok ? "回收站已清空" : "失败"))
            return
        }
        if (riskAction === "创建还原点") {
            result = parse(bridge.createRestorePoint())
            notify(result.message || (result.ok ? "还原点创建请求已提交" : "创建失败"))
        }
    }

    ListModel { id: junkModel }
    ListModel { id: largeModel }

    Dialog {
        id: riskDialog
        modal: true
        width: 460
        title: "高风险操作确认"
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: executeRiskAction()
        contentItem: ColumnLayout {
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: "操作: " + riskAction + "\n此操作可能影响系统稳定性或文件可恢复性。"
                wrapMode: Text.Wrap
                color: Style.Theme.palette.text
                font.family: "Microsoft YaHei UI"
                font.pixelSize: 13
            }
            AppTextField {
                id: verifyInput
                Layout.fillWidth: true
                placeholderText: "请输入: 确认执行"
                onTextChanged: verifyText = text.trim()
            }
        }
    }

    Component.onCompleted: {
        scanJunk()
        scanLarge()
    }

    Timer {
        interval: 250
        running: root.visible
        repeat: true
        onTriggered: pollAsyncJobs()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Card {
            Layout.fillWidth: true
            implicitHeight: 120
            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                Text {
                    Layout.fillWidth: true
                    text: "系统垃圾与大文件清理"
                    font.family: "Microsoft YaHei UI"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    color: Style.Theme.palette.text
                }
                Button { text: "扫描垃圾"; iconGlyph: "\uE721"; onClicked: scanJunk() }
                Button { text: "扫描大文件"; iconGlyph: "\uE9D9"; backgroundColor: Style.Theme.palette.secondary; onClicked: scanLarge() }
                Button { text: "创建还原点"; iconGlyph: "\uE777"; outlined: true; onClicked: { if (checkAdminOrNotify()) beginRiskAction("创建还原点") } }
                Button { text: "清空回收站"; iconGlyph: "\uE74D"; outlined: true; onClicked: { if (checkAdminOrNotify()) beginRiskAction("清空回收站") } }
                Button { text: "前往文件管理"; iconGlyph: "\uE8B7"; outlined: true; onClicked: requestNavigate(8) }
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
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            id: totalJunk
                            Layout.fillWidth: true
                            text: "垃圾文件: 0 项"
                            color: Style.Theme.palette.textSubtle
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 13
                        }
                        Button { text: "全选"; outlined: true; onClicked: { for (var i = 0; i < junkModel.count; i++) junkModel.setProperty(i, "selected", true) } }
                        Button { text: "清空选择"; outlined: true; onClicked: { for (var j = 0; j < junkModel.count; j++) junkModel.setProperty(j, "selected", false) } }
                        Button { text: "删除已选"; iconGlyph: "\uE74D"; backgroundColor: "#E74C3C"; onClicked: removeSelected(junkModel) }
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: junkModel
                        delegate: RowLayout {
                            required property string name
                            required property string path
                            required property string sizeText
                            required property bool selected
                            width: ListView.view.width
                            height: 34
                            CheckBox {
                                checked: selected || false
                                onCheckedChanged: junkModel.setProperty(index, "selected", checked)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: name
                                color: Style.Theme.palette.text
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Text {
                                text: sizeText
                                color: Style.Theme.palette.textSubtle
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 12
                            }
                            Button {
                                text: "定位"
                                outlined: true
                                implicitWidth: 64
                                implicitHeight: 28
                                onClicked: {
                                    var result = parse(bridge.openPath(path))
                                    if (!result.ok)
                                        notify(result.message || "打开失败")
                                }
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
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        AppTextField { id: searchRoot; Layout.fillWidth: true; text: "C:/Users"; placeholderText: "扫描目录" }
                        SpinBox { id: minSize; from: 50; to: 10240; value: 100; editable: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            id: totalLarge
                            Layout.fillWidth: true
                            text: "大文件: 0 项"
                            color: Style.Theme.palette.textSubtle
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 13
                        }
                        Button { text: "全选"; outlined: true; onClicked: { for (var i = 0; i < largeModel.count; i++) largeModel.setProperty(i, "selected", true) } }
                        Button { text: "清空选择"; outlined: true; onClicked: { for (var j = 0; j < largeModel.count; j++) largeModel.setProperty(j, "selected", false) } }
                        Button { text: "删除已选"; iconGlyph: "\uE74D"; backgroundColor: "#E67E22"; onClicked: removeSelected(largeModel) }
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: largeModel
                        delegate: RowLayout {
                            required property string name
                            required property string path
                            required property string sizeText
                            required property bool selected
                            width: ListView.view.width
                            height: 34
                            CheckBox {
                                checked: selected || false
                                onCheckedChanged: largeModel.setProperty(index, "selected", checked)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: name
                                color: Style.Theme.palette.text
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Text {
                                text: sizeText
                                color: Style.Theme.palette.textSubtle
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 12
                            }
                            Button {
                                text: "定位"
                                outlined: true
                                implicitWidth: 64
                                implicitHeight: 28
                                onClicked: {
                                    var result = parse(bridge.openPath(path))
                                    if (!result.ok)
                                        notify(result.message || "打开失败")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
