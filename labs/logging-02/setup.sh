#!/bin/bash
# logging-02 setup: remove any earlier myapp configuration and logs, make
# sure rsyslog and logrotate are installed and rsyslog is running. The
# package set and the service state of rsyslog before the lab are recorded
# for cleanup.sh. Prints nothing on success.
set -eu
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/logging-02

pkg_snapshot logging-02 || exit 1

# Record the rsyslog service state of the first start only
if [ ! -f "$STATE_FILE" ]; then
	mkdir -p /opt/linux-labs/state
	{
		echo "rsyslog_enabled=$(systemctl is-enabled rsyslog 2>/dev/null || true)"
		echo "rsyslog_active=$(systemctl is-active rsyslog 2>/dev/null || true)"
	} >"$STATE_FILE"
	chmod 0644 "$STATE_FILE"
fi

rm -f /etc/rsyslog.d/myapp.conf /etc/logrotate.d/myapp
rm -f /var/log/myapp.log* /var/log/myapp-program.log*

if ! rpm -q rsyslog logrotate &>/dev/null; then
	dnf -y -q install rsyslog logrotate >/dev/null || {
		echo "Error: cannot install rsyslog and logrotate." >&2
		exit 1
	}
fi

systemctl enable rsyslog &>/dev/null || true
# Restart so that a configuration left by an earlier run is unloaded
if ! systemctl restart rsyslog; then
	echo "Error: rsyslog does not start." >&2
	exit 1
fi
