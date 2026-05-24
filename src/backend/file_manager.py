from __future__ import annotations

from collections import defaultdict
from pathlib import Path

from utils.helpers import file_md5, human_size, iter_files


class FileManagerService:
    def search(
        self,
        root: str,
        keyword: str = "",
        suffix: str = "",
        min_mb: int = 0,
        limit: int = 8000,
    ) -> dict:
        start = Path(root).expanduser()
        if not start.exists():
            return {"ok": False, "message": "目录不存在", "items": []}

        threshold = min_mb * 1024 * 1024
        suffix = suffix.lower().strip()
        rows: list[dict] = []
        for path in iter_files(start, limit=limit):
            try:
                stat = path.stat()
                if keyword and keyword.lower() not in path.name.lower():
                    continue
                if suffix and path.suffix.lower() != suffix:
                    continue
                if stat.st_size < threshold:
                    continue
                rows.append(
                    {
                        "name": path.name,
                        "path": str(path),
                        "size": stat.st_size,
                        "sizeText": human_size(stat.st_size),
                        "modified": int(stat.st_mtime),
                    }
                )
            except Exception:
                continue

        rows.sort(key=lambda item: item["size"], reverse=True)
        return {"ok": True, "items": rows[:800], "count": len(rows)}

    def duplicates(self, root: str, limit: int = 6000) -> dict:
        start = Path(root).expanduser()
        if not start.exists():
            return {"ok": False, "message": "目录不存在", "groups": []}

        grouped_by_size: dict[int, list[Path]] = defaultdict(list)
        for path in iter_files(start, limit=limit):
            try:
                size = path.stat().st_size
                if size > 0:
                    grouped_by_size[size].append(path)
            except Exception:
                continue

        duplicate_groups = []
        for size, paths in grouped_by_size.items():
            if len(paths) < 2:
                continue
            grouped_by_hash: dict[str, list[Path]] = defaultdict(list)
            for path in paths:
                try:
                    grouped_by_hash[file_md5(path)].append(path)
                except Exception:
                    continue

            for digest, members in grouped_by_hash.items():
                if len(members) > 1:
                    duplicate_groups.append(
                        {
                            "hash": digest,
                            "size": size,
                            "sizeText": human_size(size),
                            "files": [
                                {"name": member.name, "path": str(member)}
                                for member in members
                            ],
                        }
                    )

        return {"ok": True, "groups": duplicate_groups[:200], "count": len(duplicate_groups)}

    def large_files(self, root: str, min_mb: int = 100, limit: int = 8000) -> dict:
        return self.search(root=root, keyword="", suffix="", min_mb=min_mb, limit=limit)

    def batch_rename(self, paths: list[str], pattern: str) -> dict:
        renamed = []
        for index, raw in enumerate(paths, start=1):
            source = Path(raw)
            if not source.exists():
                continue
            target = source.with_name(f"{pattern}_{index:03d}{source.suffix}")
            source.rename(target)
            renamed.append({"from": str(source), "to": str(target)})
        return {"ok": True, "renamed": renamed}
