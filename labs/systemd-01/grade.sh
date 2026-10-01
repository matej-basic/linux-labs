#!/bin/bash
# systemd-01 grader
source /opt/linux-labs/lib/grading.sh

UNIT=test-service.service

# "enabled" exactly: not static, linked, masked or disabled
unit_enabled() {
	[ "$(systemctl is-enabled "$UNIT" 2>/dev/null)" = enabled ]
}

unit_active() {
	[ "$(systemctl is-active "$UNIT" 2>/dev/null)" = active ]
}

grade_begin systemd-01
criterion "$UNIT is enabled" unit_enabled
criterion "$UNIT is active (running)" unit_active
grade_end
