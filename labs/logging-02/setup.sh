#!/bin/bash
# logging-02 setup: remove any earlier myapp configuration and logs, make
# sure rsyslog and logrotate are installed and rsyslog is running.
# Prints nothing on success.
set -eu

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
