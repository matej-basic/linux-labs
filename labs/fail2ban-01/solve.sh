#!/bin/bash
# Reference solution for fail2ban-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package epel-release
# solve: package fail2ban
# solve: package fail2ban-server
# solve: path /etc/fail2ban/jail.local
# solve: path /var/lib/fail2ban
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q epel-release >/dev/null || dnf -y install epel-release
rpm -q fail2ban >/dev/null || dnf -y install fail2ban

# Step 2 [user]
net=$(run_as_student <<'STEPS'
dev=$(ip -4 route show default | awk '{ print $5; exit }')
ip -4 route show dev "$dev" scope link proto kernel | awk '{ print $1; exit }'
STEPS
)
case $net in
*.*.*.*/*) ;;
*) echo "solve: no network found" >&2; exit 1 ;;
esac

# Step 3 [sudo]
tee /etc/fail2ban/jail.local >/dev/null <<EOF
[sshd]
enabled = true
maxretry = 4
findtime = 15m
bantime = 1h
ignoreip = 127.0.0.1/8 ::1 $net
EOF

# Step 4 [sudo]
systemctl enable fail2ban
systemctl restart fail2ban

# Step 5 [sudo]; the server needs a moment before it answers
for _ in $(seq 1 30); do
	fail2ban-client status sshd >/dev/null 2>&1 && break
	sleep 1
done
fail2ban-client status sshd
for k in maxretry findtime bantime ignoreip actions; do
	fail2ban-client get sshd "$k"
done

# Step 6 [sudo]
fail2ban-client set sshd banip 192.0.2.77
sleep 2
firewall-cmd --list-rich-rules
fail2ban-client set sshd unbanip 192.0.2.77
sleep 2
firewall-cmd --list-rich-rules
