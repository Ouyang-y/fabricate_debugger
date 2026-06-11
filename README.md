# fabricate_debugger
Automation1 fabricate_debugger

## 更新日志
### v3.0

重构 fabricate_debugger 并更新 Automation1 适配说明

- 重整 fabricate_debugger.m 的主流程，补齐 .ascript / .py 输入解析
- 支持从 Python 脚本中提取 pgmRun 调用并合并为 temp.ascript
- 统一处理 G-code、MoveLinear、MoveCw、MoveCcw、MovePt、WaitForMotionDone 等指令
- 替换 test 目录中的示例脚本与测试程序，清理旧示例文件