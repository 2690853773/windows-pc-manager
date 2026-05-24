from __future__ import annotations

import json
from pathlib import Path
from typing import Any


APP_NAME = "Windows 全能电脑管家"
APP_VERSION = "1.0.0"
APP_COMPANY = "Windows PC Manager Studio"


def app_data_dir() -> Path:
    path = Path.home() / "AppData" / "Local" / "WindowsPCManager"
    path.mkdir(parents=True, exist_ok=True)
    return path


class Config:
    def __init__(self) -> None:
        self.path = app_data_dir() / "settings.json"
        self.data: dict[str, Any] = {
            "theme": "ocean",
            "scan_limit": 8000,
            "desktop_backup": True,
            "default_search_root": str(Path.home()),
            "large_file_mb": 100,
        }
        self.load()

    def load(self) -> dict[str, Any]:
        if self.path.exists():
            try:
                self.data.update(json.loads(self.path.read_text(encoding="utf-8")))
            except Exception:
                pass
        return self.data

    def save(self) -> None:
        self.path.write_text(
            json.dumps(self.data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def get(self, key: str, default: Any = None) -> Any:
        return self.data.get(key, default)

    def set(self, key: str, value: Any) -> None:
        self.data[key] = value
        self.save()
