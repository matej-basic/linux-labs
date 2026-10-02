#!/bin/bash
# logging-02 cleanup: remove the rsyslog and logrotate configuration and the
# logs, restart rsyslog so that it drops the rules, restore the package set
# of the first start (rsyslog and logrotate go if the lab installed them),
# then put rsyslog back in the service state recorded by setup.sh.
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/logging-02

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

rm -f /etc/rsyslog.d/myapp* /etc/logrotate.d/myapp*
rm -f /var/log/myapp.log* /var/log/myapp-program.log*
if [ -f /var/lib/logrotate/logrotate.status ]; then
	sed -i '/myapp/d' /var/lib/logrotate/logrotate.status
fi
if systemctl is-active rsyslog &>/dev/null; then
	systemctl restart rsyslog &>/dev/null || true
fi

rc=0
pkg_restore logging-02 || rc=1

if rpm -q rsyslog &>/dev/null; then
	enabled=$(state_value rsyslog_enabled)
	active=$(state_value rsyslog_active)
	case "$enabled" in
	enabled) systemctl enable rsyslog &>/dev/null || true ;;
	disabled) systemctl disable rsyslog &>/dev/null || true ;;
	esac
	case "$active" in
	active) systemctl start rsyslog &>/dev/null || true ;;
	inactive | failed) systemctl stop rsyslog &>/dev/null || true ;;
	esac
fi

if [ "$rc" -eq 0 ]; then
	rm -f "$STATE_FILE"
fi
exit "$rc"
