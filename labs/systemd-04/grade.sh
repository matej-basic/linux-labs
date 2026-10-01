#!/bin/bash
# systemd-04 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/systemd-04

grade_begin systemd-04
grade_require_state systemd-04 "$STATE_FILE"

recorded_boot_id=$(grep '^boot_id=' "$STATE_FILE" | head -n 1 | cut -d= -f2-)
current_boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)

rc=1
[ "$(systemctl get-default 2>/dev/null)" = "multi-user.target" ] && rc=0
criterion_result "Default boot target is multi-user.target" "$rc"

rc=1
[ -n "$recorded_boot_id" ] && [ "$current_boot_id" != "$recorded_boot_id" ] && rc=0
criterion_result "System has been rebooted since the lab started" "$rc"

rc=1
[ "$(systemctl is-active multi-user.target 2>/dev/null)" = "active" ] && rc=0
criterion_result "multi-user.target is active" "$rc"

rc=1
[ "$(systemctl is-active graphical.target 2>/dev/null)" != "active" ] && rc=0
criterion_result "graphical.target is not active" "$rc"
grade_end
