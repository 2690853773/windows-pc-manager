from __future__ import annotations

import os
from pathlib import Path

from utils.helpers import human_size, iter_files, recycle_or_delete, run_command


class SystemCleanerService:
    def candidate_roots(self) -> list[Path]:
        roots = [
            Path(os.environ.get("TEMP", "")),
            Path(os.environ.get("TMP", "")),
            Path.home() / "AppData" / "Local" / "Temp",
            Path.home() / "AppData" / "Local" / "Microsoft" / "Windows" / "INetCache",
            Path.home() / "AppData" / "Local" / "Microsoft" / "Windows" / "WebCache",
            Path("C:/Windows/Temp"),
        ]
        return [root for root in roots if str(root) and root.exists()]

    def scan_junk(self, limit: int = 5000) -> dict:
        suffixes = {".tmp", ".temp", ".log", ".bak", ".old", ".dmp"}
        rows: list[dict] = []
        total = 0
        for root in self.candidate_roots():
            for path in iter_files(root, limit=limit):
                try:
                    if path.suffix.lower() in suffixes or "temp" in root.name.lower():
                        size = path.stat().st_size
                        rows.append(
                            {
                                "name": path.name,
                                "path": str(path),
                                "size": size,
                                "sizeText": human_size(size),
                            }
                        )
                        total += size
                except Exception:
                    continue
        rows.sort(key=lambda item: item["size"], reverse=True)
        return {
            "ok": True,
            "items": rows[:600],
            "count": len(rows),
            "total": total,
            "totalText": human_size(total),
        }

    def scan_large_files(self, root: str = "", min_mb: int = 100, limit: int = 8000) -> dict:
        scan_root = Path(root) if root else Path.home()
        if not scan_root.exists():
            return {"ok": False, "message": "扫描目录不存在", "items": []}

        threshold = min_mb * 1024 * 1024
        rows = []
        for path in iter_files(scan_root, limit=limit):
            try:
                size = path.stat().st_size
                if size >= threshold:
                    rows.append(
                        {
                            "name": path.name,
                            "path": str(path),
                            "size": size,
                            "sizeText": human_size(size),
                        }
                    )
            except Exception:
                continue
        rows.sort(key=lambda item: item["size"], reverse=True)
        return {"ok": True, "items": rows[:400], "count": len(rows)}

    def clean_paths(self, paths: list[str]) -> dict:
        cleaned = 0
        failed: list[dict] = []
        for raw in paths:
            path = Path(raw)
            try:
                if path.exists():
                    recycle_or_delete(path)
                    cleaned += 1
            except Exception as exc:
                failed.append({"path": raw, "error": str(exc)})
        return {"ok": True, "cleaned": cleaned, "failed": failed}

    def recycle_bin(self) -> dict:
        try:
            output = run_command(
                [
                    "powershell",
                    "-NoProfile",
                    "-Command",
                    "Clear-RecycleBin -Force -ErrorAction Stop; 'OK'",
                ],
                timeout=15,
            )
            return {"ok": True, "message": output or "回收站已清空"}
        except Exception as exc:
            return {"ok": False, "message": f"清空回收站失败: {exc}"}

    def create_restore_point(self, description: str = "WindowsPCManager 清理前还原点") -> dict:
        try:
            output = run_command(
                [
                    "powershell",
                    "-NoProfile",
                    "-Command",
                    f"Checkpoint-Computer -Description '{description}' -RestorePointType MODIFY_SETTINGS",
                ],
                timeout=25,
            )
            return {"ok": True, "message": output or "已发起创建还原点请求"}
        except Exception as exc:
            return {"ok": False, "message": f"创建还原点失败: {exc}"}
