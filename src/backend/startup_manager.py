from __future__ import annotations

import winreg
from dataclasses import dataclass


@dataclass
class StartupLocation:
    root: int
    key: str
    scope: str


class StartupManagerService:
    RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
    DISABLED_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run_Disabled_By_WPM"

    LOCATIONS = [
        StartupLocation(winreg.HKEY_CURRENT_USER, RUN_KEY, "当前用户"),
        StartupLocation(winreg.HKEY_LOCAL_MACHINE, RUN_KEY, "所有用户"),
    ]

    def list_items(self) -> dict:
        rows: list[dict] = []
        for location in self.LOCATIONS:
            rows.extend(self._read_location(location))
            rows.extend(self._read_location_disabled(location))
        return {"ok": True, "items": rows}

    def _read_location(self, location: StartupLocation) -> list[dict]:
        rows = []
        try:
            with winreg.OpenKey(location.root, location.key, 0, winreg.KEY_READ) as key:
                index = 0
                while True:
                    try:
                        name, value, _ = winreg.EnumValue(key, index)
                        rows.append(
                            {
                                "name": name,
                                "path": value,
                                "scope": location.scope,
                                "enabled": True,
                                "impact": self.impact_for(value),
                            }
                        )
                        index += 1
                    except OSError:
                        break
        except Exception:
            return rows
        return rows

    def _read_location_disabled(self, location: StartupLocation) -> list[dict]:
        rows = []
        try:
            with winreg.OpenKey(
                location.root, self.DISABLED_KEY, 0, winreg.KEY_READ
            ) as key:
                index = 0
                while True:
                    try:
                        name, value, _ = winreg.EnumValue(key, index)
                        rows.append(
                            {
                                "name": name,
                                "path": value,
                                "scope": location.scope,
                                "enabled": False,
                                "impact": self.impact_for(value),
                            }
                        )
                        index += 1
                    except OSError:
                        break
        except Exception:
            return rows
        return rows

    def impact_for(self, value: str) -> str:
        text = value.lower()
        if any(token in text for token in ("updater", "update", "helper")):
            return "低"
        if any(token in text for token in ("cloud", "sync", "security", "driver")):
            return "中"
        return "未知"

    def _open_key_for_write(self, root: int, key: str):
        return winreg.CreateKeyEx(root, key, 0, access=winreg.KEY_ALL_ACCESS)

    def disable_item(self, name: str, scope: str = "当前用户") -> dict:
        for location in self.LOCATIONS:
            if location.scope != scope:
                continue
            try:
                with self._open_key_for_write(location.root, location.key) as run_key:
                    value, value_type = winreg.QueryValueEx(run_key, name)
                    winreg.DeleteValue(run_key, name)
                with self._open_key_for_write(location.root, self.DISABLED_KEY) as disabled:
                    winreg.SetValueEx(disabled, name, 0, value_type, value)
                return {"ok": True, "message": f"已禁用启动项: {name}"}
            except Exception as exc:
                return {"ok": False, "message": f"禁用失败: {exc}"}
        return {"ok": False, "message": "未找到匹配作用域"}

    def enable_item(self, name: str, scope: str = "当前用户") -> dict:
        for location in self.LOCATIONS:
            if location.scope != scope:
                continue
            try:
                with self._open_key_for_write(location.root, self.DISABLED_KEY) as disabled:
                    value, value_type = winreg.QueryValueEx(disabled, name)
                    winreg.DeleteValue(disabled, name)
                with self._open_key_for_write(location.root, location.key) as run_key:
                    winreg.SetValueEx(run_key, name, 0, value_type, value)
                return {"ok": True, "message": f"已启用启动项: {name}"}
            except Exception as exc:
                return {"ok": False, "message": f"启用失败: {exc}"}
        return {"ok": False, "message": "未找到匹配作用域"}

    def delete_item(self, name: str, scope: str = "当前用户") -> dict:
        for location in self.LOCATIONS:
            if location.scope != scope:
                continue
            try:
                deleted = False
                with self._open_key_for_write(location.root, location.key) as run_key:
                    try:
                        winreg.DeleteValue(run_key, name)
                        deleted = True
                    except Exception:
                        pass
                with self._open_key_for_write(location.root, self.DISABLED_KEY) as dis_key:
                    try:
                        winreg.DeleteValue(dis_key, name)
                        deleted = True
                    except Exception:
                        pass
                if deleted:
                    return {"ok": True, "message": f"已删除启动项: {name}"}
                return {"ok": False, "message": "未找到启动项"}
            except Exception as exc:
                return {"ok": False, "message": f"删除失败: {exc}"}
        return {"ok": False, "message": "未找到匹配作用域"}
