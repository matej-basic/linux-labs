#!/bin/bash
# Reference solution for fail2ban-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package epel-release
# solve: package fail2ban
# solve: package fail2ban-server
# solve: path /etc/fail2ban/filter.d/labapp.local
# solve: path /etc/fail2ban/jail.d/labapp.local
# solve: path /var/lib/fail2ban
# solve: path /var/log/labapp
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q epel-release >/dev/null || dnf -y install epel-release
rpm -q fail2ban >/dev/null || dnf -y install fail2ban

# Step 2 [sudo]
head -20 /var/log/labapp/auth.log
grep -c 'LOGIN FAILED' /var/log/labapp/auth.log

# Step 3 [sudo]
tee /etc/fail2ban/filter.d/labapp.local >/dev/null <<'F2B'
[Definition]
failregex = ^\s*labapp\[\d+\]: LOGIN FAILED user=\S+ src=<HOST>\s
ignoreregex =
F2B

# Step 4 [sudo]
(cd / && fail2ban-regex /var/log/labapp/auth.log labapp) | grep '^Lines:'

# Step 5 [user]
net=$(run_as_student <<'STEPS'
dev=$(ip -4 route show default | awk '{ print $5; exit }')
ip -4 route show dev "$dev" scope link proto kernel | awk '{ print $1; exit }'
STEPS
)
case $net in
*.*.*.*/*) ;;
*) echo "solve: no network found" >&2; exit 1 ;;
esac

# Step 6 [sudo]
tee /etc/fail2ban/jail.d/labapp.local >/dev/null <<F2B
[labapp]
enabled = true
filter = labapp
logpath = /var/log/labapp/auth.log
backend = auto
port = 8443
protocol = tcp
maxretry = 3
findtime = 10m
bantime = 30m
ignoreip = 127.0.0.1/8 ::1 $net
F2B

# Step 7 [sudo]; the server needs a moment before it answers
systemctl enable fail2ban
systemctl restart fail2ban
for _ in $(seq 1 30); do
	fail2ban-client status labapp >/dev/null 2>&1 && break
	sleep 1
done
fail2ban-client status labapp
fail2ban-client get labapp logpath
fail2ban-client get labapp ignoreip
