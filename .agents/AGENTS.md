# Workspace Agent Rules

## 权限与交互规则
- **读取权限**：读取代码文件、搜索目录、查看日志等只读操作（view_file / list_dir / grep_search）无需询问提示，自动直接执行。
- **写入确认**：仅在对代码库文件进行修改/写入（write_to_file / replace_file_content）或执行具有破坏性/写入性质的终端 Shell 命令时，请求用户确认。
