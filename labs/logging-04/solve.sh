#!/bin/bash
# Reference solution for logging-04, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /etc/audit/rules.d/lab-audit.rules
# solve: path /etc/lab-app.conf
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
cat > /etc/audit/rules.d/lab-audit.rules <<'RULES'
-w /etc/lab-app.conf -p wa -k lab_config
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=unset -k lab_delete
-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=unset -k lab_delete
RULES
chmod 600 /etc/audit/rules.d/lab-audit.rules

# Step 2 [sudo]
augenrules --load
augenrules --check
auditctl -l

# Step 3 [sudo]
sed -i -e 's/^max_log_file *=.*/max_log_file = 25/' \
	-e 's/^max_log_file_action *=.*/max_log_file_action = keep_logs/' \
	/etc/audit/auditd.conf
grep -E '^max_log_file' /etc/audit/auditd.conf
service auditd reload

# Step 4 [user]; ausearch reads stdin when it is not a terminal, so
# --input-logs makes it read the log files
run_as_student <<'STEPS'
sudo chmod 644 /etc/lab-app.conf
touch /tmp/audit-test && rm /tmp/audit-test
sleep 2
sudo ausearch --input-logs -i -k lab_config -ts recent
sudo ausearch --input-logs -i -k lab_delete -ts recent
STEPS
