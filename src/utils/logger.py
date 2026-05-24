from __future__ import annotations

import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path


def get_log_dir() -> Path:
    root = Path.home() / "AppData" / "Local" / "WindowsPCManager" / "logs"
    root.mkdir(parents=True, exist_ok=True)
    return root


def setup_logger(name: str = "windows_pc_manager") -> logging.Logger:
    logger = logging.getLogger(name)
    if logger.handlers:
        return logger

    logger.setLevel(logging.INFO)
    formatter = logging.Formatter(
        "%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    file_handler = RotatingFileHandler(
        get_log_dir() / "app.log",
        maxBytes=2_000_000,
        backupCount=5,
        encoding="utf-8",
    )
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(formatter)
    logger.addHandler(stream_handler)
    return logger
