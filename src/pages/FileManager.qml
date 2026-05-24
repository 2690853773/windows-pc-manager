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

    property string renamePathsJson: "[]"
    property string verifyText: ""
    property string searchJobId: ""
    property string duplicateJobId: ""
    property bool searchLoading: false
    property bool duplicateLoading: false

    ListModel { id: searchModel }
    ListModel { id: duplicateModel }

    function parse(raw) {
        try { return JSON.parse(raw) } catch (e) { return { ok: false, message: "解析失败" } }
    }

    function searchFiles() {
        if (searchLoading)
            return
        searchLoading = true
        searchModel.clear()
        countText.text = "搜索结果: 检索中..."
        var start = parse(bridge.startFileSearchJob(searchRoot.text.trim(), keywordInput.text.trim(), suffixInput.text.trim(), minSize.value))
        if (!start.ok) {
            searchLoading = false
            notify(start.message || "启动搜索失败")
            return
        }
        searchJobId = start.jobId
    }

    function searchLarge() {
        if (searchLoading)
            return
        searchLoading = true
        searchModel.clear()
        countText.text = "大文件结果: 扫描中..."
        var start = parse(bridge.startFileLargeJob(searchRoot.text.trim(), minSize.value))
        if (!start.ok) {
            searchLoading = false
            notify(start.message || "启动扫描失败")
            return
        }
        searchJobId = start.jobId
    }

    function findDuplicates() {
        if (duplicateLoading)
            return
        duplicateLoading = true
        duplicateModel.clear()
        duplicateCount.text = "重复组: 检索中..."
        var start = parse(bridge.startFileDuplicatesJob(searchRoot.text.trim()))
        if (!start.ok) {
            duplicateLoading = false
            notify(start.message || "启动查重失败")
            return
        }
        duplicateJobId = start.jobId
    }

    function pollAsyncJobs() {
        if (searchLoading && searchJobId.length > 0) {
            var searchState = parse(bridge.pollJob(searchJobId))
            if (searchState.status === "done") {
                searchLoading = false
                searchJobId = ""
                var searchData = searchState.result
                if (!searchData || !searchData.ok) {
                    notify((searchData && searchData.message) || "搜索失败")
                } else {
                    for (var i = 0; i < searchData.items.length; i++) {
                        var row = searchData.items[i]
                        row.selected = false
                        searchModel.append(row)
                    }
                    countText.text = "搜索结果: " + searchData.count + " 项"
                }
            } else if (searchState.status === "failed" || searchState.status === "missing") {
                searchLoading = false
                searchJobId = ""
                notify(searchState.message || "搜索失败")
            }
        }

        if (duplicateLoading && duplicateJobId.length > 0) {
            var dupState = parse(bridge.pollJob(duplicateJobId))
            if (dupState.status === "done") {
                duplicateLoading = false
                duplicateJobId = ""
                var dupData = dupState.result
                if (!dupData || !dupData.ok) {
                    notify((dupData && dupData.message) || "查重失败")
                } else {
                    for (var j = 0; j < dupData.groups.length; j++) {
                        duplicateModel.append({
                            hash: dupData.groups[j].hash,
                            sizeText: dupData.groups[j].sizeText,
                            filesText: dupData.groups[j].files.map(function(f) { return f.path }).join("\n")
                        })
                    }
                    duplicateCount.text = "重复组: " + dupData.count
                }
            } else if (dupState.status === "failed" || dupState.status === "missing") {
                duplicateLoading = false
                duplicateJobId = ""
                notify(dupState.message || "查重失败")
            }
        }
    }

    function requestRename() {
        var selected = []
        for (var i = 0; i < searchModel.count; i++) {
            var row = searchModel.get(i)
            if (row.selected === true)
                selected.push(row.path)
        }
        if (selected.length === 0) {
            notify("请先勾选要重命名的文件")
            return
        }
        renamePathsJson = JSON.stringify(selected)
        verifyText = ""
        renameDialog.open()
    }

    function selectAllSearch() {
        for (var i = 0; i < searchModel.count; i++)
            searchModel.setProperty(i, "selected", true)
    }

    function clearSearchSelection() {
        for (var i = 0; i < searchModel.count; i++)
            searchModel.setProperty(i, "selected", false)
    }

    function applyRename() {
        if (verifyText !== "确认执行") {
            notify("请输入“确认执行”后再继续")
            return
        }
        var result = parse(bridge.batchRename(renamePathsJson, renamePrefix.text.trim()))
        notify(result.ok ? ("已重命名 " + result.renamed.length + " 个文件") : (result.message || "重命名失败"))
        searchFiles()
    }

    Dialog {
        id: renameDialog
        title: "批量重命名确认"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: applyRename()
        contentItem: ColumnLayout {
            spacing: 10
            Text {
                text: "将对已选文件执行批量重命名，请输入“确认执行”继续。"
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

    Component.onCompleted: {
        searchFiles()
        findDuplicates()
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
            implicitHeight: 132
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    AppTextField { id: searchRoot; Layout.fillWidth: true; text: "C:/Users"; placeholderText: "扫描根目录" }
                    AppTextField { id: keywordInput; Layout.preferredWidth: 180; placeholderText: "文件名关键词" }
                    AppTextField { id: suffixInput; Layout.preferredWidth: 120; placeholderText: ".txt" }
                    SpinBox { id: minSize; from: 0; to: 10240; value: 100; editable: true }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { id: countText; Layout.fillWidth: true; text: "搜索结果: 0"; color: Style.Theme.palette.textSubtle; font.family: "Microsoft YaHei UI"; font.pixelSize: 12 }
                    AppTextField { id: renamePrefix; Layout.preferredWidth: 140; text: "文件"; placeholderText: "重命名前缀" }
                    Button { text: "搜索"; iconGlyph: "\uE721"; onClicked: searchFiles() }
                    Button { text: "查找大文件"; iconGlyph: "\uE9D9"; backgroundColor: Style.Theme.palette.secondary; onClicked: searchLarge() }
                    Button { text: "重复文件"; iconGlyph: "\uE8A7"; outlined: true; onClicked: findDuplicates() }
                    Button { text: "批量重命名"; iconGlyph: "\uE8AC"; outlined: true; onClicked: requestRename() }
                    Button { text: "系统清理"; iconGlyph: "\uE74D"; outlined: true; onClicked: requestNavigate(2) }
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
                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: "文件列表"; font.family: "Microsoft YaHei UI"; font.pixelSize: 14; font.weight: Font.DemiBold; color: Style.Theme.palette.text }
                        Button { text: "全选"; outlined: true; implicitWidth: 56; implicitHeight: 28; onClicked: selectAllSearch() }
                        Button { text: "清空选择"; outlined: true; implicitWidth: 82; implicitHeight: 28; onClicked: clearSearchSelection() }
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: searchModel
                        delegate: RowLayout {
                            required property string name
                            required property string path
                            required property string sizeText
                            required property bool selected
                            width: ListView.view.width
                            height: 34
                            CheckBox {
                                checked: selected || false
                                onCheckedChanged: searchModel.setProperty(index, "selected", checked)
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
                                text: "打开"
                                outlined: true
                                implicitWidth: 62
                                implicitHeight: 28
                                onClicked: {
                                    var result = parse(bridge.openPath(path))
                                    if (!result.ok)
                                        notify(result.message || "打开路径失败")
                                }
                            }
                            Button {
                                text: "定位"
                                outlined: true
                                implicitWidth: 62
                                implicitHeight: 28
                                onClicked: {
                                    var result = parse(bridge.revealPath(path))
                                    if (!result.ok)
                                        notify(result.message || "定位失败")
                                }
                            }
                            Button {
                                text: "复制路径"
                                outlined: true
                                implicitWidth: 82
                                implicitHeight: 28
                                onClicked: {
                                    var result = parse(bridge.copyText(path))
                                    if (!result.ok)
                                        notify(result.message || "复制失败")
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
                    anchors.margins: 10
                    spacing: 8
                    Text { id: duplicateCount; text: "重复组: 0"; font.family: "Microsoft YaHei UI"; font.pixelSize: 14; font.weight: Font.DemiBold; color: Style.Theme.palette.text }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: duplicateModel
                        delegate: Rectangle {
                            required property string hash
                            required property string sizeText
                            required property string filesText
                            width: ListView.view.width
                            height: 94
                            radius: 8
                            color: Qt.tint(Style.Theme.palette.bgElevated, Qt.rgba(1, 1, 1, 0.25))
                            border.width: 1
                            border.color: Style.Theme.palette.border
                            Column {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4
                                Text { text: "Hash: " + hash + "  大小: " + sizeText; color: Style.Theme.palette.text; font.family: "Microsoft YaHei UI"; font.pixelSize: 11; elide: Text.ElideRight }
                                Text {
                                    text: filesText
                                    color: Style.Theme.palette.textSubtle
                                    font.family: "Microsoft YaHei UI"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
