#!/usr/bin/env bash
# Lab11：移除 course-memhog 服务与脚本。
# 已写入 journal 的日志和计数器读数保留。
set -euo pipefail

LAB_NAME="Lab11"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lablib.sh"

need_root

systemctl stop course-memhog.service 2>/dev/null || true
systemctl reset-failed course-memhog.service 2>/dev/null || true

restore_backups
systemctl daemon-reload

log "已移除 Lab11 的 course-memhog 服务与脚本。"
log "journal、dmesg 中的 OOM 记录保留，供报告和复盘使用。"
