# Script_Tools

日常 Vibe Coding 随手开发的脚本工具集合。

## 脚本说明

- **netspeed.sh** — 网络网卡速度监控工具。读取 `/sys/class/net/` 目录下的数据，展示实时 RX/TX 速率、包计数以及错误/丢包统计。
  - 用法：`bash netspeed.sh [网卡名]`
  - 实时监控：`watch -n 1 bash netspeed.sh [网卡名]`
  - 不填网卡名则自动获取默认网卡