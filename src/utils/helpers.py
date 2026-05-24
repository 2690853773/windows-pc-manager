from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
from pathlib import Path
from typing import Iterable


def human_size(size: int | float) -> str:
    value = float(size)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if value < 1024 or unit == "TB":
            return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
        value /= 1024
    return f"{value:.1f} TB"


def file_md5(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.md5()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(chunk_size), b""):
            digest.update(chunk)
    return digest.hexdigest()


def iter_files(root: Path, limit: int = 5000) -> Iterable[Path]:
    count = 0
    for current, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if not d.startswith("$")]
        for filename in files:
            if count >= limit:
                return
            count += 1
            yield Path(current) / filename


def recycle_or_delete(path: Path) -> None:
    try:
        from send2trash import send2trash

        send2trash(str(path))
        return
    except Exception:
        pass

    if path.is_dir():
        shutil.rmtree(path, ignore_errors=True)
    else:
        path.unlink(missing_ok=True)


def run_command(args: list[str], timeout: int = 10) -> str:
    completed = subprocess.run(
        args,
        capture_output=True,
        text=True,
        timeout=timeout,
        encoding="utf-8",
        errors="ignore",
        shell=False,
    )
    return (completed.stdout or completed.stderr).strip()
