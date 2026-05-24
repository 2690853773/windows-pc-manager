pragma Singleton
import QtQuick

QtObject {
    id: theme
    property string activeTheme: "ocean"

    readonly property var themes: ({
        "ocean": {
            "primary": "#165DFF",
            "secondary": "#0084FF",
            "accent": "#19BE6B",
            "bg": "#F5F8FF",
            "bgCard": "#FFFFFF",
            "bgElevated": "#ECF2FF",
            "text": "#1F2D3D",
            "textSubtle": "#5A6470",
            "border": "#D9E4FF",
            "shadow": "#1A165DFF"
        },
        "dawn": {
            "primary": "#0E8F6D",
            "secondary": "#2AB57B",
            "accent": "#FF8A3D",
            "bg": "#F6FBF8",
            "bgCard": "#FFFFFF",
            "bgElevated": "#EAF7F0",
            "text": "#1E2B24",
            "textSubtle": "#4F5F56",
            "border": "#CFE8DA",
            "shadow": "#220E8F6D"
        },
        "graphite": {
            "primary": "#1C6ED2",
            "secondary": "#4E7CBF",
            "accent": "#F08C00",
            "bg": "#F3F5F9",
            "bgCard": "#FFFFFF",
            "bgElevated": "#E8ECF5",
            "text": "#1B2430",
            "textSubtle": "#596273",
            "border": "#D0D8E8",
            "shadow": "#1A1B2430"
        }
    })

    function useTheme(name) {
        if (themes[name] !== undefined) {
            activeTheme = name
        }
    }

    readonly property var palette: themes[activeTheme]
}
