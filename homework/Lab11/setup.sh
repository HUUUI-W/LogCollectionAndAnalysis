#!/usr/bin/env bash
# Lab11：创建一个受 cgroup v2 MemoryMax 限制的服务，让它真实触发 OOM kill。
set -euo pipefail

LAB_NAME="Lab11"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lablib.sh"

need_root
require_command python3
require_command systemctl
require_command logger
state_init

if [ "$(stat -fc %T /sys/fs/cgroup 2>/dev/null || true)" != "cgroup2fs" ]; then
  die "当前不是 cgroup v2（unified hierarchy），本实验需要 cgroup v2。"
fi
grep -qw memory /sys/fs/cgroup/cgroup.controllers || die "当前环境没有可用的 memory 控制器。"

backup_path /etc/systemd/system/course-memhog.service
backup_path /usr/local/bin/course-memhog.py

# 允许从修复验证阶段重新开始，避免旧进程继续占用同名服务。
systemctl stop course-memhog.service 2>/dev/null || true
systemctl reset-failed course-memhog.service 2>/dev/null || true

cat > /usr/local/bin/course-memhog.py <<'EOF'
#!/usr/bin/env python3
# 课程演示用内存分配器：每秒约分配 40MB，且不释放，直到 cgroup OOM。
import time

chunks = []
i = 0
while True:
    i += 1
    chunks.append(bytearray(8 * 1024 * 1024))
    print(f"allocated {i * 8} MiB", flush=True)
    time.sleep(0.2)
EOF
chmod 0755 /usr/local/bin/course-memhog.py

cat > /etc/systemd/system/course-memhog.service <<'EOF'
[Unit]
Description=Course memory hog (cgroup OOM demo)

[Service]
Type=simple
ExecStartPre=/usr/bin/grep -Fxq 134217728 /sys/fs/cgroup/system.slice/%n/memory.max
ExecStart=/usr/local/bin/course-memhog.py
# 在 systemd 回收空 cgroup 前，将内核计数器的原始读数留在本服务的 journal。
ExecStopPost=-/usr/bin/grep -H . /sys/fs/cgroup/system.slice/%n/memory.events /sys/fs/cgroup/system.slice/%n/memory.peak
# 将 systemd 提供的本次退出结果发送到 Lab5 已采集的 syslog。
ExecStopPost=-/usr/bin/logger -t course-memhog-result -- unit=%n result=${SERVICE_RESULT} exit_code=${EXIT_CODE} exit_status=${EXIT_STATUS}
MemoryMax=128M
MemorySwapMax=0
OOMPolicy=stop
Restart=no

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
log "已安装 course-memhog.service（MemoryMax=128M，MemorySwapMax=0），服务尚未启动。"
log "完成任务 1 的基线记录后，在任务 2 手动启动服务。"
