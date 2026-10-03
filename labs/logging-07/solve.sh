#!/bin/bash
# Reference solution for logging-07, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package aide
# solve: path /srv/app
# solve: path /usr/local/sbin/lab-tamper
# solve: path /root/aide-report.txt
# solve: path /var/lib/aide/aide.db.gz
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q aide >/dev/null || dnf -y install aide >/dev/null
grep -nE '^(database|report_url|[A-Z_]+ =)' /etc/aide.conf >/dev/null

# Step 2 [sudo]
cp -p /etc/aide.conf /etc/aide.conf.orig
sed -i -E '/^[[:space:]]*[!=]?\//d' /etc/aide.conf
cat >> /etc/aide.conf <<'CONF'

# logging-07: the application tree only
APPRULE = p+u+g+sha512
/srv/app APPRULE
!/srv/app/data
CONF
rm /etc/aide.conf.orig
aide --config-check

# Step 3 [sudo]
aide --init >/dev/null
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# Step 4 [sudo]
/usr/local/sbin/lab-tamper

# Step 5 [sudo]: aide --check exits 5 here (added and changed files)
rc=0
aide --check > /root/aide-report.txt || rc=$?
[ "$rc" -eq 5 ]
