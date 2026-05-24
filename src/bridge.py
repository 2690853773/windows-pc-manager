from __future__ import annotations

import ctypes
import json
import os
import subprocess
import uuid
from concurrent.futures import Future, ThreadPoolExecutor
from datetime import datetime
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse

from PySide6.QtCore import QObject, Slot
from PySide6.QtGui import QGuiApplication

from backend.desktop_cleaner import DesktopCleanerService
from backend.file_manager import FileManagerService
from backend.network_tools import NetworkToolsService
from backend.process_manager import ProcessManagerService
from backend.startup_manager import StartupManagerService
from backend.system_cleaner import SystemCleanerService
from backend.system_info import SystemInfoService
from utils.config import Config
from utils.logger import setup_logger


def to_json(data: Any) -> str:
    return json.dumps(data, ensure_ascii=False)


class AppBridge(QObject):
    def __init__(self) -> None:
        super().__init__()
        self.logger = setup_logger()
        self.config = Config()
        self.system_info = SystemInfoService()
        self.desktop_cleaner = DesktopCleanerService()
        self.system_cleaner = SystemCleanerService()
        self.process_manager = ProcessManagerService()
        self.startup_manager = StartupManagerService()
        self.network_tools = NetworkToolsService()
        self.file_manager = FileManagerService()

        self.task_items: list[dict[str, Any]] = []
        self.task_logs: list[dict[str, Any]] = []
        self.executor = ThreadPoolExecutor(max_workers=4, thread_name_prefix="wpm")
        self.jobs: dict[str, Future] = {}

    def _safe_call(self, func, *args, **kwargs) -> str:
        try:
            result = func(*args, **kwargs)
            self._append_log(
                action=getattr(func, "__name__", "unknown"),
                status="success" if result.get("ok", False) else "failed",
                message=result.get("message", ""),
            )
            return to_json(result)
        except Exception as exc:
            self.logger.exception("Bridge call failed")
            self._append_log(
                action=getattr(func, "__name__", "unknown"),
                status="failed",
                message=str(exc),
            )
            return to_json({"ok": False, "message": str(exc)})

    def _normalize_path(self, raw: str) -> Path:
        if raw.startswith("file:/"):
            parsed = urlparse(raw)
            path = unquote(parsed.path or "")
            if path.startswith("/") and len(path) > 3 and path[2] == ":":
                path = path[1:]
            return Path(path)
        return Path(raw)

    def _is_admin(self) -> bool:
        try:
            return bool(ctypes.windll.shell32.IsUserAnAdmin())
        except Exception:
            return False

    def _require_admin(self, operation: str) -> str:
        if self._is_admin():
            return ""
        return to_json(
            {
                "ok": False,
                "adminRequired": True,
                "message": f"操作“{operation}”需要管理员权限，请使用管理员身份启动程序后重试。",
            }
        )

    def _append_log(self, action: str, status: str, message: str = "") -> None:
        self.task_logs.insert(
            0,
            {
                "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "action": action,
                "status": status,
                "message": message,
            },
        )
        if len(self.task_logs) > 200:
            self.task_logs = self.task_logs[:200]

    def _start_job(self, func, *args, **kwargs) -> dict:
        job_id = str(uuid.uuid4())
        future = self.executor.submit(func, *args, **kwargs)
        self.jobs[job_id] = future
        self._append_log(
            action=f"start_job:{getattr(func, '__name__', 'unknown')}",
            status="success",
            message=job_id,
        )
        return {"ok": True, "jobId": job_id, "status": "running"}

    def _poll_job(self, job_id: str) -> dict:
        future = self.jobs.get(job_id)
        if not future:
            return {"ok": False, "message": "任务不存在或已过期", "status": "missing"}
        if not future.done():
            return {"ok": True, "status": "running", "jobId": job_id}
        try:
            result = future.result()
            self._append_log(action="job_done", status="success", message=job_id)
            return {"ok": True, "status": "done", "jobId": job_id, "result": result}
        except Exception as exc:
            self._append_log(action="job_done", status="failed", message=str(exc))
            return {
                "ok": False,
                "status": "failed",
                "jobId": job_id,
                "message": f"后台任务失败: {exc}",
            }
        finally:
            self.jobs.pop(job_id, None)

    def _export_system_report_impl(self, save_path: str) -> dict:
        path = self._normalize_path(save_path)
        hw = self.system_info.hardware()
        snap = self.system_info.snapshot()
        osd = self.system_info.os_detail()
        lines = [
            "Windows 全能电脑管家 - 系统报告",
            "=" * 40,
            f"导出时间: {snap.get('time', '')}",
            f"主机名: {snap.get('host', '')}",
            f"CPU 使用率: {snap.get('cpu', 0)}%",
            f"内存: {snap.get('memoryUsed', '')} / {snap.get('memoryTotal', '')}",
            f"磁盘: {snap.get('diskUsed', '')} / {snap.get('diskTotal', '')}",
            f"运行时长: {snap.get('uptime', '')}",
            "",
            "系统信息",
            "-" * 40,
            f"系统: {osd.get('name', '')} {osd.get('release', '')}",
            f"版本: {osd.get('version', '')}",
            f"架构: {osd.get('arch', '')}",
            f"安装时间: {osd.get('installed', '')}",
            "",
            "磁盘列表",
        ]
        for item in hw.get("info", {}).get("drives", []):
            lines.append(
                f"- {item.get('name', '')}: 已用 {item.get('percent', 0)}%, 总容量 {item.get('total', '')}, 可用 {item.get('free', '')}"
            )
        lines.append("")
        lines.append("网络接口")
        for nic in hw.get("info", {}).get("network", []):
            lines.append(f"- {nic.get('name', '')}: {nic.get('address', '')}")

        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(lines), encoding="utf-8")
        return {"ok": True, "message": "报告导出成功", "path": str(path)}

    def _run_task_action(self, action: str, payload: dict[str, Any]) -> dict:
        if action == "scan_junk":
            return self.system_cleaner.scan_junk(int(self.config.get("scan_limit", 8000)))
        if action == "scan_large":
            return self.system_cleaner.scan_large_files(
                payload.get("root", str(Path.home())),
                int(payload.get("min_mb", 100)),
                int(self.config.get("scan_limit", 8000)),
            )
        if action == "list_processes":
            return self.process_manager.list_processes(payload.get("sort", "memory"))
        if action == "list_startups":
            return self.startup_manager.list_items()
        if action == "network_info":
            return self.network_tools.local_info()
        if action == "desktop_undo":
            return self.desktop_cleaner.undo_latest()
        if action == "export_report":
            return self._export_system_report_impl(
                payload.get("path", str(Path.home() / "Desktop" / "system-report.txt"))
            )
        return {"ok": False, "message": f"未知任务动作: {action}"}

    @Slot(result=str)
    def appMeta(self) -> str:
        return to_json(
            {
                "ok": True,
                "theme": self.config.get("theme", "ocean"),
                "scanLimit": self.config.get("scan_limit", 8000),
                "desktopBackup": self.config.get("desktop_backup", True),
                "searchRoot": self.config.get("default_search_root"),
            }
        )

    @Slot(result=str)
    def adminStatus(self) -> str:
        is_admin = self._is_admin()
        return to_json(
            {
                "ok": True,
                "isAdmin": is_admin,
                "label": "管理员模式" if is_admin else "标准模式",
            }
        )

    @Slot(str, result=str)
    def setTheme(self, theme: str) -> str:
        self.config.set("theme", theme)
        return to_json({"ok": True, "theme": theme})

    @Slot(result=str)
    def getSnapshot(self) -> str:
        return self._safe_call(self.system_info.snapshot)

    @Slot(result=str)
    def getHardwareInfo(self) -> str:
        return self._safe_call(self.system_info.hardware)

    @Slot(result=str)
    def getOSInfo(self) -> str:
        return self._safe_call(self.system_info.os_detail)

    @Slot(str, result=str)
    def desktopPreview(self, rules_json: str = "") -> str:
        return self._safe_call(self.desktop_cleaner.preview, rules_json)

    @Slot(str, bool, result=str)
    def desktopOrganize(self, rules_json: str, make_backup: bool = True) -> str:
        return self._safe_call(self.desktop_cleaner.organize, rules_json, make_backup)

    @Slot(result=str)
    def desktopUndo(self) -> str:
        return self._safe_call(self.desktop_cleaner.undo_latest)

    @Slot(result=str)
    def scanJunk(self) -> str:
        return self._safe_call(
            self.system_cleaner.scan_junk, int(self.config.get("scan_limit", 8000))
        )

    @Slot(result=str)
    def startScanJunkJob(self) -> str:
        return to_json(
            self._start_job(
                self.system_cleaner.scan_junk, int(self.config.get("scan_limit", 8000))
            )
        )

    @Slot(str, int, result=str)
    def scanLargeFiles(self, root: str, min_mb: int) -> str:
        return self._safe_call(
            self.system_cleaner.scan_large_files,
            root,
            min_mb,
            int(self.config.get("scan_limit", 8000)),
        )

    @Slot(str, int, result=str)
    def startScanLargeFilesJob(self, root: str, min_mb: int) -> str:
        return to_json(
            self._start_job(
                self.system_cleaner.scan_large_files,
                root,
                min_mb,
                int(self.config.get("scan_limit", 8000)),
            )
        )

    @Slot(str, result=str)
    def cleanPaths(self, paths_json: str) -> str:
        guard = self._require_admin("清理文件")
        if guard:
            return guard
        paths = json.loads(paths_json or "[]")
        return self._safe_call(self.system_cleaner.clean_paths, paths)

    @Slot(result=str)
    def clearRecycleBin(self) -> str:
        guard = self._require_admin("清空回收站")
        if guard:
            return guard
        return self._safe_call(self.system_cleaner.recycle_bin)

    @Slot(result=str)
    def createRestorePoint(self) -> str:
        guard = self._require_admin("创建系统还原点")
        if guard:
            return guard
        return self._safe_call(self.system_cleaner.create_restore_point)

    @Slot(str, result=str)
    def listProcesses(self, sort_by: str = "memory") -> str:
        return self._safe_call(self.process_manager.list_processes, sort_by)

    @Slot(int, result=str)
    def processDetail(self, pid: int) -> str:
        return self._safe_call(self.process_manager.process_detail, pid)

    @Slot(int, bool, result=str)
    def terminateProcess(self, pid: int, force: bool = False) -> str:
        guard = self._require_admin("结束进程")
        if guard:
            return guard
        return self._safe_call(self.process_manager.terminate, pid, force)

    @Slot(result=str)
    def listStartupItems(self) -> str:
        return self._safe_call(self.startup_manager.list_items)

    @Slot(str, str, result=str)
    def disableStartup(self, name: str, scope: str) -> str:
        guard = self._require_admin("禁用启动项")
        if guard:
            return guard
        return self._safe_call(self.startup_manager.disable_item, name, scope)

    @Slot(str, str, result=str)
    def enableStartup(self, name: str, scope: str) -> str:
        guard = self._require_admin("启用启动项")
        if guard:
            return guard
        return self._safe_call(self.startup_manager.enable_item, name, scope)

    @Slot(str, str, result=str)
    def deleteStartup(self, name: str, scope: str) -> str:
        guard = self._require_admin("删除启动项")
        if guard:
            return guard
        return self._safe_call(self.startup_manager.delete_item, name, scope)

    @Slot(result=str)
    def networkInfo(self) -> str:
        return self._safe_call(self.network_tools.local_info)

    @Slot(str, result=str)
    def ping(self, host: str) -> str:
        return self._safe_call(self.network_tools.ping, host or "www.baidu.com")

    @Slot(result=str)
    def speedTest(self) -> str:
        return self._safe_call(self.network_tools.speed_test)

    @Slot(str, result=str)
    def scanPorts(self, host: str) -> str:
        return self._safe_call(self.network_tools.scan_ports, host or "127.0.0.1")

    @Slot(str, str, str, int, result=str)
    def fileSearch(self, root: str, keyword: str, suffix: str, min_mb: int) -> str:
        return self._safe_call(
            self.file_manager.search,
            root,
            keyword,
            suffix,
            min_mb,
            int(self.config.get("scan_limit", 8000)),
        )

    @Slot(str, str, str, int, result=str)
    def startFileSearchJob(
        self, root: str, keyword: str, suffix: str, min_mb: int
    ) -> str:
        return to_json(
            self._start_job(
                self.file_manager.search,
                root,
                keyword,
                suffix,
                min_mb,
                int(self.config.get("scan_limit", 8000)),
            )
        )

    @Slot(str, result=str)
    def fileDuplicates(self, root: str) -> str:
        return self._safe_call(
            self.file_manager.duplicates, root, int(self.config.get("scan_limit", 8000))
        )

    @Slot(str, result=str)
    def startFileDuplicatesJob(self, root: str) -> str:
        return to_json(
            self._start_job(
                self.file_manager.duplicates,
                root,
                int(self.config.get("scan_limit", 8000)),
            )
        )

    @Slot(str, int, result=str)
    def fileLarge(self, root: str, min_mb: int) -> str:
        return self._safe_call(
            self.file_manager.large_files,
            root,
            min_mb,
            int(self.config.get("scan_limit", 8000)),
        )

    @Slot(str, int, result=str)
    def startFileLargeJob(self, root: str, min_mb: int) -> str:
        return to_json(
            self._start_job(
                self.file_manager.large_files,
                root,
                min_mb,
                int(self.config.get("scan_limit", 8000)),
            )
        )

    @Slot(str, str, result=str)
    def batchRename(self, paths_json: str, pattern: str) -> str:
        paths = json.loads(paths_json or "[]")
        return self._safe_call(self.file_manager.batch_rename, paths, pattern or "文件")

    @Slot(str, result=str)
    def readTextFile(self, file_path: str) -> str:
        try:
            path = self._normalize_path(file_path)
            if not path.exists():
                return to_json({"ok": False, "message": "文件不存在"})
            content = path.read_text(encoding="utf-8", errors="ignore")
            return to_json({"ok": True, "content": content, "path": str(path)})
        except Exception as exc:
            return to_json({"ok": False, "message": f"读取失败: {exc}"})

    @Slot(str, str, result=str)
    def writeTextFile(self, file_path: str, content: str) -> str:
        try:
            path = self._normalize_path(file_path)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
            return to_json({"ok": True, "path": str(path), "message": "保存成功"})
        except Exception as exc:
            return to_json({"ok": False, "message": f"保存失败: {exc}"})

    @Slot(str, result=str)
    def openPath(self, raw_path: str) -> str:
        try:
            path = self._normalize_path(raw_path)
            if not path.exists():
                return to_json({"ok": False, "message": "路径不存在"})
            os.startfile(str(path))
            return to_json({"ok": True, "message": "已打开路径"})
        except Exception as exc:
            return to_json({"ok": False, "message": f"打开失败: {exc}"})

    @Slot(str, result=str)
    def revealPath(self, raw_path: str) -> str:
        try:
            path = self._normalize_path(raw_path)
            if not path.exists():
                return to_json({"ok": False, "message": "路径不存在"})
            if path.is_file():
                subprocess.Popen(
                    ["explorer", "/select,", str(path)],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    shell=False,
                )
            else:
                os.startfile(str(path))
            return to_json({"ok": True, "message": "已定位到目标"})
        except Exception as exc:
            return to_json({"ok": False, "message": f"定位失败: {exc}"})

    @Slot(str, result=str)
    def copyText(self, text: str) -> str:
        try:
            clipboard = QGuiApplication.clipboard()
            clipboard.setText(text or "")
            return to_json({"ok": True, "message": "已复制到剪贴板"})
        except Exception as exc:
            return to_json({"ok": False, "message": f"复制失败: {exc}"})

    @Slot(str, result=str)
    def exportSystemReport(self, save_path: str) -> str:
        return self._safe_call(self._export_system_report_impl, save_path)

    @Slot(str, str, str, result=str)
    def createTask(self, name: str, action: str, payload_json: str = "{}") -> str:
        try:
            payload = json.loads(payload_json or "{}")
            item = {
                "id": str(uuid.uuid4()),
                "name": name or "未命名任务",
                "action": action,
                "payload": payload,
                "status": "pending",
                "message": "",
                "createdAt": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "updatedAt": "",
            }
            self.task_items.insert(0, item)
            self._append_log(action="create_task", status="success", message=item["name"])
            return to_json({"ok": True, "task": item})
        except Exception as exc:
            return to_json({"ok": False, "message": f"创建任务失败: {exc}"})

    @Slot(result=str)
    def listTasks(self) -> str:
        return to_json({"ok": True, "items": self.task_items})

    @Slot(str, result=str)
    def runTask(self, task_id: str) -> str:
        for item in self.task_items:
            if item["id"] != task_id:
                continue
            result = self._run_task_action(item["action"], item["payload"])
            item["status"] = "success" if result.get("ok", False) else "failed"
            item["message"] = result.get("message", "")
            item["updatedAt"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            self._append_log(
                action=f"run_task:{item['action']}",
                status=item["status"],
                message=item["message"],
            )
            return to_json({"ok": True, "task": item, "result": result})
        return to_json({"ok": False, "message": "任务不存在"})

    @Slot(str, result=str)
    def retryTask(self, task_id: str) -> str:
        return self.runTask(task_id)

    @Slot(str, result=str)
    def removeTask(self, task_id: str) -> str:
        before = len(self.task_items)
        self.task_items = [item for item in self.task_items if item["id"] != task_id]
        if len(self.task_items) == before:
            return to_json({"ok": False, "message": "任务不存在"})
        self._append_log(action="remove_task", status="success")
        return to_json({"ok": True, "message": "任务已删除"})

    @Slot(result=str)
    def listTaskLogs(self) -> str:
        return to_json({"ok": True, "items": self.task_logs})

    @Slot(result=str)
    def clearTaskLogs(self) -> str:
        self.task_logs = []
        return to_json({"ok": True, "message": "日志已清空"})

    @Slot(str, result=str)
    def pollJob(self, job_id: str) -> str:
        return to_json(self._poll_job(job_id))
