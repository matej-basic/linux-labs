#!/bin/bash
# Reference solution for ssh-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# Port 22 and key logins stay as they are: the drop-in names port 22,
# root keeps key logins and sshd is reloaded only after sshd -t passes.
#
# solve: package policycoreutils-python-utils
# solve: path /home/svcbackup
# solve: path /home/svcdeploy
# solve: path /home/opsadmin/svcbackup_ed25519
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q policycoreutils-python-utils >/dev/null ||
	dnf -y install policycoreutils-python-utils
semanage port -a -t ssh_port_t -p tcp 2222

# Step 2 [sudo]
firewall-cmd --permanent --add-port=2222/tcp
firewall-cmd --reload

# Step 3 [sudo]
mkdir -p /etc/ssh/sshd_config.d
chmod 700 /etc/ssh/sshd_config.d
grep -q '^Include /etc/ssh/sshd_config.d/\*.conf' /etc/ssh/sshd_config ||
	sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config

# Step 4 [sudo]
cat > /etc/ssh/sshd_config.d/00-hardening.conf <<'CONF'
Port 22
Port 2222
PermitRootLogin prohibit-password

Match Group automation
    PasswordAuthentication no
    PubkeyAuthentication yes
CONF
chmod 600 /etc/ssh/sshd_config.d/00-hardening.conf
restorecon -R /etc/ssh

# Step 5 [sudo]
sshd -t
systemctl reload sshd
# sshd re-executes on reload; wait until it listens on both ports
for _ in $(seq 1 20); do
	ss -Htln 'sport = :2222' | grep -q . && ss -Htln 'sport = :22' | grep -q . && break
	sleep 0.5
done

# Step 6 [user]; accept-new answers the host key questions
run_as_student <<'STEPS'
for p in 22 2222; do
	test "$(ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
		-i ~/svcbackup_ed25519 -p "$p" svcbackup@localhost id -un </dev/null)" = svcbackup
done
STEPS
