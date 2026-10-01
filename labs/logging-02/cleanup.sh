#!/bin/bash
# logging-02 cleanup: remove the rsyslog and logrotate configuration and the
# logs, and restart rsyslog so that it drops the rules.

rm -f /etc/rsyslog.d/myapp* /etc/logrotate.d/myapp*
if systemctl is-enabled rsyslog &>/dev/null; then
	systemctl restart rsyslog &>/dev/null || true
fi
rm -f /var/log/myapp.log* /var/log/myapp-program.log*
if [ -f /var/lib/logrotate/logrotate.status ]; then
	sed -i '/myapp/d' /var/lib/logrotate/logrotate.status
fi
rm -f /opt/linux-labs/state/logging-02
exit 0
