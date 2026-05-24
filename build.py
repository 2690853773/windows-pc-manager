from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DIST = ROOT / "dist"
BUILD = ROOT / "build"
SPEC = ROOT / "windows-pc-manager.spec"


def run(cmd: list[str]) -> None:
    print(">", " ".join(cmd))
    subprocess.run(cmd, check=True)


def clean() -> None:
    for path in (DIST, BUILD, SPEC):
        if path.is_file():
            path.unlink()
        elif path.exists():
            shutil.rmtree(path, ignore_errors=True)


def package() -> None:
    src_main = ROOT / "src" / "main.py"
    icon = ROOT / "assets" / "icons" / "app.ico"
    add_data_items = [
        f"{ROOT / 'src' / 'main.qml'};src",
        f"{ROOT / 'src' / 'components'};src/components",
        f"{ROOT / 'src' / 'pages'};src/pages",
        f"{ROOT / 'assets'};assets",
    ]

    cmd = [
        "pyinstaller",
        "--noconfirm",
        "--clean",
        "--onefile",
        "--windowed",
        "--name",
        "Windows-PC-Manager",
        "--icon",
        str(icon),
    ]
    for item in add_data_items:
        cmd.extend(["--add-data", item])
    cmd.append(str(src_main))
    run(cmd)


if __name__ == "__main__":
    clean()
    package()
    print("打包完成，输出目录:", DIST)
