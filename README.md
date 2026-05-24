# Windows 全能电脑管家

Windows 全能电脑管家是一个基于 `Python + PySide6 + QML` 的桌面系统管理工具，目标是提供美观、专业、可扩展的 Windows 系统维护体验。

## 项目介绍

核心能力：

1. 系统状态首页：CPU/内存/磁盘实时监控，运行时长与温度展示
2. 桌面整理：按类型分类归档，支持预览、备份、撤销
3. 系统清理：垃圾文件扫描、大文件扫描、回收站清理
4. 系统信息：硬件、磁盘、网络、显卡、驱动信息展示
5. 进程管理：进程列表、排序、详情、结束与强制结束
6. 启动项管理：查看/禁用/启用/删除启动项
7. 网络工具：本机网络信息、Ping、测速、端口扫描
8. 实用工具：计算器、计时器、记事本、截图调用
9. 文件管理：高级搜索、重复文件查找、大文件查找、批量重命名

## 界面展示

当前仓库包含完整 UI（左侧导航 + 顶部状态栏 + 卡片式模块页面 + 底部状态栏），支持三套主题：

1. `ocean`（蓝色商务风）
2. `dawn`（绿色清新风）
3. `graphite`（灰蓝专业风）

可运行后自行截图并放入 `assets/images/` 目录：

- `assets/images/home.png`
- `assets/images/system-cleaner.png`
- `assets/images/process-manager.png`

## 快速使用（运行源码）

```bash
pip install -r requirements.txt
python src/main.py
```

## 本地开发

环境要求：

1. Windows 10/11
2. Python 3.10+

目录结构：

```text
windows-pc-manager/
├─ src/
│  ├─ main.py
│  ├─ main.qml
│  ├─ bridge.py
│  ├─ components/
│  ├─ pages/
│  ├─ backend/
│  └─ utils/
├─ assets/
│  ├─ icons/
│  ├─ styles/
│  └─ images/
├─ build.py
├─ requirements.txt
├─ README.md
└─ LICENSE
```

## 打包方法（单文件 EXE）

```bash
pip install -r requirements.txt
python build.py
```

打包结果：

- 输出文件：`dist/Windows-PC-Manager.exe`
- 打包参数：`--onefile --windowed --icon --add-data`

## 功能特性

1. 统一异常捕获与日志系统（`src/utils/logger.py`）
2. 模块化后端服务（`src/backend/*.py`）
3. 统一桥接层（`src/bridge.py`）供 QML 调用
4. 所有高风险系统操作前均有确认对话框
5. 主题持久化配置（`src/utils/config.py`）

## 自定义扩展

扩展建议：

1. 在 `src/backend/` 中新增服务类
2. 在 `src/bridge.py` 暴露对应 Slot
3. 在 `src/pages/` 新增页面并挂到 `src/main.qml` 的导航模型

## 注意事项

1. 启动项修改、进程结束、系统清理等操作建议以管理员身份运行
2. 系统还原点创建依赖系统策略，部分设备可能不可用
3. 网络测速依赖外网连接，离线时会提示失败
4. 为避免误报，建议使用官方 Python 与 PyInstaller 正式版本

## 许可证

本项目使用 MIT 许可证，详见 [LICENSE](/E:/git/progam/windows-pc-manager/LICENSE)。
