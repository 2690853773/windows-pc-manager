from __future__ import annotations

import json
import shutil
import ctypes
from datetime import datetime
from pathlib import Path
from typing import Optional


class GUID(ctypes.Structure):
    _fields_ = [
        ("Data1", ctypes.c_uint32),
        ("Data2", ctypes.c_uint16),
        ("Data3", ctypes.c_uint16),
        ("Data4", ctypes.c_ubyte * 8),
    ]


class DesktopCleanerService:
    DEFAULT_RULES = {
        "文档": {".doc", ".docx", ".pdf", ".txt", ".xls", ".xlsx", ".ppt", ".pptx", ".md"},
        "图片": {".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".svg"},
        "视频": {".mp4", ".mov", ".mkv", ".avi", ".wmv"},
        "音乐": {".mp3", ".wav", ".flac", ".aac"},
        "压缩包": {".zip", ".rar", ".7z", ".tar", ".gz"},
        "程序": {".exe", ".msi", ".bat", ".cmd", ".lnk"},
    }

    def __init__(self) -> None:
        self.desktop_dir = self._resolve_desktop_dir()
        self.backup_root = (
            Path.home() / "AppData" / "Local" / "WindowsPCManager" / "desktop_backups"
        )
        self.backup_root.mkdir(parents=True, exist_ok=True)
        self.history_file = self.backup_root / "history.json"

    def _resolve_desktop_dir(self) -> Path:
        candidates: list[Path] = []

        known = self._desktop_from_known_folder()
        if known:
            candidates.append(known)

        home = Path.home()
        candidates.extend(
            [
                home / "Desktop",
                home / "OneDrive" / "Desktop",
                home / "OneDrive - Personal" / "Desktop",
            ]
        )

        for candidate in candidates:
            try:
                if candidate.exists() and candidate.is_dir():
                    return candidate
            except Exception:
                continue
        return home / "Desktop"

    def _desktop_from_known_folder(self) -> Optional[Path]:
        ptr = ctypes.c_wchar_p()
        ole32 = None
        try:
            shell32 = ctypes.windll.shell32
            ole32 = ctypes.windll.ole32
            # FOLDERID_Desktop = {B4BFCC3A-DB2C-424C-B029-7FE99A87C641}
            folder_id = GUID(
                0xB4BFCC3A,
                0xDB2C,
                0x424C,
                (ctypes.c_ubyte * 8)(0xB0, 0x29, 0x7F, 0xE9, 0x9A, 0x87, 0xC6, 0x41),
            )
            result = shell32.SHGetKnownFolderPath(
                ctypes.byref(folder_id), 0, None, ctypes.byref(ptr)
            )
            if result == 0 and ptr.value:
                return Path(ptr.value)
        except Exception:
            return None
        finally:
            if ole32 and ptr.value:
                try:
                    ole32.CoTaskMemFree(ptr)
                except Exception:
                    pass
        return None

    def _category_for(self, path: Path, custom_rules: dict | None = None) -> str:
        rules = custom_rules or self.DEFAULT_RULES
        suffix = path.suffix.lower()
        for category, exts in rules.items():
            ext_set = set(item.lower() for item in exts)
            if suffix in ext_set:
                return category
        return "其他"

    def preview(self, custom_rules_json: str = "") -> dict:
        custom_rules: dict | None = None
        if custom_rules_json:
            try:
                custom_rules = json.loads(custom_rules_json)
            except Exception:
                custom_rules = None

        if not self.desktop_dir.exists():
            return {"ok": False, "message": f"未找到桌面目录: {self.desktop_dir}", "items": []}

        rows = []
        for path in self.desktop_dir.iterdir():
            if path.is_dir() or path.name.startswith("."):
                continue
            rows.append(
                {
                    "name": path.name,
                    "path": str(path),
                    "size": path.stat().st_size,
                    "category": self._category_for(path, custom_rules),
                }
            )
        return {
            "ok": True,
            "items": rows,
            "count": len(rows),
            "desktopPath": str(self.desktop_dir),
        }

    def organize(self, custom_rules_json: str = "", make_backup: bool = True) -> dict:
        preview_result = self.preview(custom_rules_json)
        if not preview_result.get("ok"):
            return preview_result

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_dir = self.backup_root / timestamp
        if make_backup:
            backup_dir.mkdir(parents=True, exist_ok=True)

        manifest: list[dict] = []
        moved_count = 0
        for row in preview_result["items"]:
            source = Path(row["path"])
            if not source.exists():
                continue
            target_dir = self.desktop_dir / row["category"]
            target_dir.mkdir(exist_ok=True)
            target = target_dir / source.name
            if target.exists():
                target = target_dir / f"{source.stem}_{timestamp}{source.suffix}"

            if make_backup:
                shutil.copy2(source, backup_dir / source.name)
            shutil.move(str(source), str(target))
            manifest.append({"from": str(source), "to": str(target)})
            moved_count += 1

        if make_backup:
            (backup_dir / "manifest.json").write_text(
                json.dumps(manifest, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
        self._append_history(
            {
                "timestamp": timestamp,
                "manifest": manifest,
                "backup": str(backup_dir) if make_backup else "",
            }
        )

        return {
            "ok": True,
            "moved": moved_count,
            "backup": str(backup_dir) if make_backup else "",
        }

    def undo_latest(self) -> dict:
        history = self._read_history()
        for entry in history:
            if entry.get("undone"):
                continue

            manifest = entry.get("manifest", [])
            if not isinstance(manifest, list) or len(manifest) == 0:
                continue

            restored = 0
            for item in reversed(manifest):
                old_path = Path(item.get("to", ""))
                new_path = Path(item.get("from", ""))
                if old_path.exists():
                    new_path.parent.mkdir(parents=True, exist_ok=True)
                    shutil.move(str(old_path), str(new_path))
                    restored += 1

            entry["undone"] = True
            self._write_history(history)
            return {
                "ok": True,
                "restored": restored,
                "backup": entry.get("backup", ""),
                "message": "已撤销最近一次桌面整理",
            }

        backups = sorted(
            [p for p in self.backup_root.iterdir() if p.is_dir()],
            key=lambda item: item.name,
            reverse=True,
        )

        for backup in backups:
            manifest_file = backup / "manifest.json"
            if not manifest_file.exists():
                continue
            try:
                manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
            except Exception:
                continue

            restored = 0
            for item in reversed(manifest):
                old_path = Path(item.get("to", ""))
                new_path = Path(item.get("from", ""))
                if old_path.exists():
                    new_path.parent.mkdir(parents=True, exist_ok=True)
                    shutil.move(str(old_path), str(new_path))
                    restored += 1
            return {
                "ok": True,
                "restored": restored,
                "backup": str(backup),
                "message": "已撤销最近一次桌面整理",
            }

        return {"ok": False, "message": "没有可撤销的整理记录"}

    def _read_history(self) -> list[dict]:
        try:
            if self.history_file.exists():
                data = json.loads(self.history_file.read_text(encoding="utf-8"))
                if isinstance(data, list):
                    return data
        except Exception:
            pass
        return []

    def _write_history(self, items: list[dict]) -> None:
        self.history_file.write_text(
            json.dumps(items[:40], ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def _append_history(self, entry: dict) -> None:
        if not entry.get("manifest"):
            return
        history = self._read_history()
        entry["undone"] = False
        history.insert(0, entry)
        self._write_history(history)
