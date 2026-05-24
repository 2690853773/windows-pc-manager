from __future__ import annotations

import os
import sys
from pathlib import Path

from PySide6.QtCore import QUrl, Qt
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from bridge import AppBridge
from utils.config import APP_NAME
from utils.logger import setup_logger


def resource_path(relative: str) -> str:
    base_path = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent.parent))
    return str(base_path / relative)


def main() -> int:
    # Use a non-native Controls style so custom Button/TextField skins render correctly.
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Fusion"
    logger = setup_logger()

    QGuiApplication.setAttribute(Qt.AA_EnableHighDpiScaling, True)
    app = QGuiApplication(sys.argv)
    app.setApplicationName(APP_NAME)
    app.setOrganizationName("Windows PC Manager Studio")

    icon_path = resource_path("assets/icons/app.ico")
    if not Path(icon_path).exists():
        icon_path = resource_path("assets/icons/app.svg")
    if Path(icon_path).exists():
        app.setWindowIcon(QIcon(icon_path))

    engine = QQmlApplicationEngine()
    bridge = AppBridge()
    engine.rootContext().setContextProperty("backendBridge", bridge)

    for import_dir in ("src", "assets", "PySide6/qml"):
        import_path = resource_path(import_dir)
        if Path(import_path).exists():
            engine.addImportPath(import_path)
            logger.info("已添加 QML 导入路径: %s", import_path)

    qml_path = resource_path("src/main.qml")
    logger.info("加载 QML 文件: %s", qml_path)
    logger.info("QML 文件存在: %s", Path(qml_path).exists())
    logger.info("QML 导入路径: %s", engine.importPathList())
    engine.load(QUrl.fromLocalFile(qml_path))

    if not engine.rootObjects():
        logger.error("QML 引擎加载失败: %s", qml_path)
        for error in engine.errors():
            logger.error("QML 错误: %s", error.toString())
        return 1
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
