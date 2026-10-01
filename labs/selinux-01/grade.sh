#!/bin/bash
# selinux-01 grader
source /opt/linux-labs/lib/grading.sh

CONF=/etc/selinux/config

runtime_enforcing() {
	[ "$(getenforce 2>/dev/null)" = "Enforcing" ]
}

config_enforcing() {
	local v
	v=$(grep -E '^[[:space:]]*SELINUX=' "$CONF" 2>/dev/null | tail -n 1)
	v=${v#*=}
	v=${v//[[:space:]]/}
	[ "$v" = "enforcing" ]
}

selinux_enabled() {
	[ "$(getenforce 2>/dev/null)" != "Disabled" ] &&
		sestatus 2>/dev/null | grep -Eq '^SELinux status:[[:space:]]+enabled'
}

policy_targeted() {
	sestatus 2>/dev/null | grep -Eq '^Loaded policy name:[[:space:]]+targeted$'
}

grade_begin selinux-01

criterion "SELinux is enabled" selinux_enabled
criterion "SELinux is in enforcing mode now" runtime_enforcing
criterion "SELINUX=enforcing is set in $CONF" config_enforcing
criterion "The targeted policy is loaded" policy_targeted
grade_end
