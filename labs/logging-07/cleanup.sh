#!/bin/bash
# logging-07 cleanup: remove the application tree, lab-tamper, the
# report and the AIDE databases of the lab. Put back /etc/aide.conf and
# the databases of an aide that was installed before the lab, or remove
# the edited /etc/aide.conf and the log of an aide the lab installed.
# Then restore the package set of the first start.
source /opt/linux-labs/lib/packages.sh

LAB=logging-07
STATE_DIR=/opt/linux-labs/state/$LAB

rm -rf /srv/app
rm -f /usr/local/sbin/lab-tamper /root/aide-report.txt
rm -f /var/lib/aide/aide.db.gz /var/lib/aide/aide.db.new.gz

if [ "$(cat "$STATE_DIR/aide" 2>/dev/null)" = installed ]; then
	if [ -f "$STATE_DIR/saved/aide.conf" ]; then
		cp -p "$STATE_DIR/saved/aide.conf" /etc/aide.conf
		restorecon /etc/aide.conf 2>/dev/null || true
	fi
	find "$STATE_DIR/saved" -mindepth 1 -maxdepth 1 -type f \
		! -name aide.conf -exec cp -p -t /var/lib/aide {} + 2>/dev/null
	restorecon -R /var/lib/aide 2>/dev/null || true
elif pkg_was_installed "$LAB" aide; then
	# No record of the first start: leave the configuration alone.
	:
else
	# aide came with the lab: drop the edited configuration, so that
	# removing the package leaves no .rpmsave copy behind.
	rm -f /etc/aide.conf /etc/aide.conf.rpmnew /etc/aide.conf.rpmsave
	rm -f /var/log/aide/aide.log /var/log/aide/aide.log.[0-9]*
fi

rc=0
pkg_restore "$LAB" || rc=1
rm -rf "$STATE_DIR"
exit "$rc"
