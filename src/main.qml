import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../assets/styles" as Style
import "components"
import "pages"

Window {
    id: root
    width: 1380
    height: 920
    visible: true
    title: "Windows 全能电脑管家"
    color: Style.Theme.palette.bg

    property int currentIndex: 0
    property string currentTime: ""
    property string modeText: "标准模式"
    property bool isAdmin: false
    property string toastText: ""

    function parseResult(raw) {
        try { return JSON.parse(raw) } catch (e) { return { ok: false, message: "数据解析失败" } }
    }

    function showToast(msg) {
        root.toastText = msg
        toastTimer.restart()
    }

    function gotoPage(pageIndex) {
        if (pageIndex >= 0 && pageIndex < navModel.count)
            root.currentIndex = pageIndex
    }

    function refreshAdminStatus() {
        var data = parseResult(backendBridge.adminStatus())
        if (data.ok) {
            root.isAdmin = data.isAdmin
            root.modeText = data.label
        }
    }

    Component.onCompleted: {
        var meta = parseResult(backendBridge.appMeta())
        if (meta.ok && meta.theme) {
            Style.Theme.useTheme(meta.theme)
            themeBox.currentIndex = themeBox.model.indexOf(meta.theme)
        }
        refreshAdminStatus()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")
    }

    Timer {
        id: toastTimer
        interval: 2600
        running: false
        repeat: false
        onTriggered: root.toastText = ""
    }

    ListModel {
        id: navModel
        ListElement { name: "首页"; icon: "\uE80F" }
        ListElement { name: "桌面整理"; icon: "\uECA5" }
        ListElement { name: "系统清理"; icon: "\uE74D" }
        ListElement { name: "系统信息"; icon: "\uE946" }
        ListElement { name: "进程管理"; icon: "\uE9F9" }
        ListElement { name: "启动项管理"; icon: "\uE768" }
        ListElement { name: "网络工具"; icon: "\uE839" }
        ListElement { name: "实用工具"; icon: "\uE7FC" }
        ListElement { name: "文件管理"; icon: "\uE8B7" }
        ListElement { name: "任务中心"; icon: "\uE8A5" }
    }

    Rectangle {
        anchors.fill: parent
        color: Style.Theme.palette.bg

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.tint(Style.Theme.palette.primary, Qt.rgba(1, 1, 1, 0.90)) }
                GradientStop { position: 0.5; color: Style.Theme.palette.bg }
                GradientStop { position: 1.0; color: Qt.tint(Style.Theme.palette.secondary, Qt.rgba(1, 1, 1, 0.94)) }
            }
            opacity: 0.48
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 228
                Layout.fillHeight: true
                color: Style.Theme.palette.bgCard
                border.color: Style.Theme.palette.border
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        elevated: false
                        color: Style.Theme.palette.bgElevated
                        border.color: Style.Theme.palette.border
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12
                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                radius: 12
                                color: Style.Theme.palette.primary
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uE770"
                                    color: "white"
                                    font.family: "Segoe MDL2 Assets"
                                    font.pixelSize: 18
                                }
                            }
                            ColumnLayout {
                                spacing: 2
                                Text {
                                    text: "Windows 管家"
                                    font.family: "Microsoft YaHei UI"
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    color: Style.Theme.palette.text
                                }
                                Text {
                                    text: "专业版 1.2.0"
                                    font.family: "Microsoft YaHei UI"
                                    font.pixelSize: 12
                                    color: Style.Theme.palette.textSubtle
                                }
                            }
                        }
                    }

                    ListView {
                        id: navList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: navModel
                        currentIndex: root.currentIndex
                        delegate: Rectangle {
                            id: navItem
                            required property string name
                            required property string icon
                            required property int index

                            width: navList.width
                            height: 46
                            radius: 12
                            color: root.currentIndex === index
                                   ? Qt.tint(Style.Theme.palette.primary, Qt.rgba(1, 1, 1, 0.86))
                                   : (navArea.containsMouse ? Qt.tint(Style.Theme.palette.bgElevated, Qt.rgba(1, 1, 1, 0.5)) : "transparent")
                            border.width: root.currentIndex === index ? 1 : 0
                            border.color: Style.Theme.palette.primary

                            Behavior on color { ColorAnimation { duration: 140 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10
                                Text {
                                    text: navItem.icon
                                    font.family: "Segoe MDL2 Assets"
                                    font.pixelSize: 14
                                    color: root.currentIndex === navItem.index ? Style.Theme.palette.primary : Style.Theme.palette.textSubtle
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: navItem.name
                                    font.family: "Microsoft YaHei UI"
                                    font.pixelSize: 14
                                    font.weight: root.currentIndex === navItem.index ? Font.DemiBold : Font.Normal
                                    color: root.currentIndex === navItem.index ? Style.Theme.palette.primary : Style.Theme.palette.textSubtle
                                }
                            }

                            MouseArea {
                                id: navArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentIndex = navItem.index
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    color: Style.Theme.palette.bgCard
                    border.color: Style.Theme.palette.border
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        spacing: 14

                        Text {
                            text: navModel.get(root.currentIndex).name
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                            color: Style.Theme.palette.text
                        }
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitHeight: 28
                            implicitWidth: adminLabel.implicitWidth + 20
                            radius: 14
                            color: root.isAdmin ? Qt.tint(Style.Theme.palette.accent, Qt.rgba(1, 1, 1, 0.80)) : Qt.tint("#D97706", Qt.rgba(1, 1, 1, 0.78))
                            border.color: root.isAdmin ? Style.Theme.palette.accent : "#D97706"
                            border.width: 1
                            Text {
                                id: adminLabel
                                anchors.centerIn: parent
                                text: root.modeText
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 12
                                color: root.isAdmin ? Style.Theme.palette.accent : "#8A4B00"
                            }
                        }

                        Text {
                            text: root.currentTime
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 13
                            color: Style.Theme.palette.textSubtle
                        }

                        ComboBox {
                            id: themeBox
                            Layout.preferredWidth: 130
                            model: ["ocean", "dawn", "graphite"]
                            onActivated: function(index) {
                                var themeName = model[index]
                                Style.Theme.useTheme(themeName)
                                backendBridge.setTheme(themeName)
                            }
                        }
                    }
                }

                Item {
                    id: pageHost
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    property var pageItems: []
                    property var loadedFlags: [false, false, false, false, false, false, false, false, false, false]
                    property real fadeOpacity: 1.0

                    function ensureLoaded(index) {
                        if (index < 0 || index >= pageComponents.length)
                            return
                        if (loadedFlags[index] === true) {
                            if (pageItems[index])
                                pageItems[index].visible = true
                            return
                        }
                        var obj = pageComponents[index].createObject(pageHost)
                        if (!obj)
                            return
                        obj.anchors.fill = pageHost
                        pageItems[index] = obj
                        loadedFlags[index] = true
                        obj.visible = true
                    }

                    function showOnly(index) {
                        for (var i = 0; i < pageItems.length; i++) {
                            if (pageItems[i])
                                pageItems[i].visible = (i === index)
                        }
                    }

                    Component.onCompleted: {
                        ensureLoaded(root.currentIndex)
                        showOnly(root.currentIndex)
                    }

                    opacity: fadeOpacity
                    Behavior on fadeOpacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.InOutQuad
                        }
                    }

                    Connections {
                        target: root
                        function onCurrentIndexChanged() {
                            pageHost.fadeOpacity = 0.90
                            pageHost.ensureLoaded(root.currentIndex)
                            pageHost.showOnly(root.currentIndex)
                            pageHost.fadeOpacity = 1.0
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    color: Style.Theme.palette.bgCard
                    border.color: Style.Theme.palette.border
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10
                        Text {
                            text: "版本: 1.2.0"
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 12
                            color: Style.Theme.palette.textSubtle
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Copyright © 2026 Windows PC Manager Studio"
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 12
                            color: Style.Theme.palette.textSubtle
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: root.toastText.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 54
            color: "#1F2D3D"
            radius: 10
            opacity: 0.94
            width: Math.min(500, toastLabel.implicitWidth + 28)
            height: 42
            Text {
                id: toastLabel
                anchors.centerIn: parent
                text: root.toastText
                color: "#FFFFFF"
                font.family: "Microsoft YaHei UI"
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }
    }

    property var pageComponents: [
        homePageComponent,
        desktopCleanerComponent,
        systemCleanerComponent,
        systemInfoComponent,
        processManagerComponent,
        startupManagerComponent,
        networkToolsComponent,
        utilsComponent,
        fileManagerComponent,
        taskCenterComponent
    ]

    Component {
        id: homePageComponent
        HomePage {
            bridge: backendBridge
            onNotify: function(message) { root.showToast(message) }
            onRequestNavigate: function(idx) { root.gotoPage(idx) }
        }
    }
    Component {
        id: desktopCleanerComponent
        DesktopCleaner {
            bridge: backendBridge
            onNotify: function(message) { root.showToast(message) }
            onRequestNavigate: function(idx) { root.gotoPage(idx) }
        }
    }
    Component {
        id: systemCleanerComponent
        SystemCleaner {
            bridge: backendBridge
            onNotify: function(message) { root.showToast(message) }
            onRequestNavigate: function(idx) { root.gotoPage(idx) }
        }
    }
    Component {
        id: systemInfoComponent
        SystemInfo {
            bridge: backendBridge
            onNotify: function(message) { root.showToast(message) }
            onRequestNavigate: function(idx) { root.gotoPage(idx) }
        }
    }
    Component {
        id: processManagerComponent
        ProcessManager {
            bridge: backendBridge
            onNotify: function(message) { root.showToast(message) }
            onRequestNavigate: function(idx) { root.gotoPage(idx) }
        }
    }
    Component {
        id: startupManagerComponent
        StartupManager {
            bridge: backendBridge
            onNotify: function(message) { root.showToast(message) }
            onRequestNavigate: function(idx) { root.gotoPage(idx) }
        }
    }
    Component {
        id: networkToolsComponent
        NetworkTools {
            bridge: backendBridge
            onNotify: function(message) { root.showToast(message) }
            onRequestNavigate: function(idx) { root.gotoPage(idx) }
        }
    }
    Component {
        id: utilsComponent
        Utils {
            bridge: backendBridge
            onNotify: function(message) { root.showToast(message) }
            onRequestNavigate: function(idx) { root.gotoPage(idx) }
        }
    }
    Component {
        id: fileManagerComponent
        FileManager {
            bridge: backendBridge
            onNotify: function(message) { root.showToast(message) }
            onRequestNavigate: function(idx) { root.gotoPage(idx) }
        }
    }
    Component {
        id: taskCenterComponent
        TaskCenter {
            bridge: backendBridge
            onNotify: function(message) { root.showToast(message) }
            onRequestNavigate: function(idx) { root.gotoPage(idx) }
        }
    }
}
