#!/bin/bash
# firewall-02 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/firewall-02

grade_begin firewall-02
grade_require_state firewall-02 "$STATE_FILE"
iface=$(head -n 1 "$STATE_FILE")

# Rich rule for 443/tcp from 192.168.1.0/24 in public; $1 is empty for the
# running configuration or --permanent
rich_rule_present() {
	local scope=()
	[ -n "$1" ] && scope=("$1")
	firewall-cmd "${scope[@]}" --zone=public --list-rich-rules 2>/dev/null |
		grep -E 'source address="192\.168\.1\.0/24"' |
		grep -E 'port port="443" protocol="tcp"' |
		grep -qE ' accept$'
}

rich_rule_runtime() { rich_rule_present ""; }
rich_rule_permanent() { rich_rule_present --permanent; }

iface_trusted_runtime() {
	[ -n "$iface" ] &&
		[ "$(firewall-cmd --get-zone-of-interface="$iface" 2>/dev/null)" = trusted ]
}

# Permanent binding: in the zone file, or in the NetworkManager profile
iface_trusted_permanent() {
	local conn
	[ -n "$iface" ] || return 1
	firewall-cmd --permanent --zone=trusted --list-interfaces 2>/dev/null |
		tr ' ' '\n' | grep -qx "$iface" && return 0
	conn=$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null)
	[ -n "$conn" ] && [ "$conn" != -- ] &&
		[ "$(nmcli -g connection.zone connection show "$conn" 2>/dev/null)" = trusted ]
}

criterion "firewalld is enabled and running" \
	bash -c 'systemctl is-enabled firewalld && systemctl is-active firewalld'
criterion "Rich rule for 443/tcp from 192.168.1.0/24 is active" rich_rule_runtime
criterion "Rich rule for 443/tcp from 192.168.1.0/24 is permanent" rich_rule_permanent
criterion "Interface $iface is in the trusted zone now" iface_trusted_runtime
criterion "Interface $iface is in the trusted zone permanently" iface_trusted_permanent
grade_end
