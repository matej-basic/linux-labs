#!/bin/bash
# Reference solution for ssh-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# Port 22 and the key logins of the task user stay as they are: only
# the Match block for webdeploy goes, and sshd is reloaded only after
# sshd -t passes.
#
# solve: package policycoreutils-python-utils
# solve: path /srv/users
# solve: path /home/opsadmin/.ssh/webdeploy_ed25519
# solve: path /home/opsadmin/.ssh/webdeploy_ed25519.pub
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# ssh_opts: the client options of solution.md; accept-new answers the
# host key question of the first login
ssh_opts='-o StrictHostKeyChecking=accept-new -o BatchMode=yes -i ~/.ssh/webdeploy_ed25519'
login="ssh $ssh_opts webdeploy@localhost id -un </dev/null"

# Step 1 [user]: publickey is not offered
run_as_student "out=\$(ssh -v $ssh_opts webdeploy@localhost id -un </dev/null 2>&1 || true)
printf '%s\\n' \"\$out\" | grep 'Authentications that can continue' | grep -v publickey >/dev/null"

# Step 2 [sudo]
sshd -T -C user=webdeploy,host=localhost,addr=127.0.0.1 |
	grep -x 'pubkeyauthentication no' >/dev/null
grep -n -A 2 '^Match' /etc/ssh/sshd_config

# Step 3 [sudo]
sed -i '/^Match User webdeploy$/,/PubkeyAuthentication no$/d' /etc/ssh/sshd_config
sshd -t
systemctl reload sshd
sleep 1

# Step 4 [user]: the key is offered and refused
run_as_student "out=\$(ssh -v $ssh_opts webdeploy@localhost id -un </dev/null 2>&1 || true)
printf '%s\\n' \"\$out\" | grep 'Offering public key' >/dev/null
printf '%s\\n' \"\$out\" | grep 'Permission denied' >/dev/null"

# Step 5 [sudo]. ausearch reads standard input when it is not a
# terminal, as under test-lab.sh, so --input-logs makes it read the log.
sleep 1
ausearch --input-logs -m AVC -ts recent | grep 'authorized_keys' >/dev/null
ls -ldZ /srv/users/webdeploy /srv/users/webdeploy/.ssh/authorized_keys

# Step 6 [sudo]
rpm -q policycoreutils-python-utils >/dev/null ||
	dnf -y install policycoreutils-python-utils
semanage fcontext -a -e /home /srv/users
restorecon -Rv /srv/users

# Step 7 [user]
run_as_student "! $login"
sleep 1
tail -n 20 /var/log/secure |
	grep 'bad ownership or modes for directory /srv/users/webdeploy' >/dev/null

# Step 8 [sudo]
chmod 0700 /srv/users/webdeploy

# Step 9 [user]: the key works, the shell refuses
run_as_student "out=\$($login 2>&1 || true)
printf '%s\\n' \"\$out\" | grep 'currently not available' >/dev/null"

# Step 10 [sudo]
usermod -s /bin/bash webdeploy

# Step 11 [user]
run_as_student "test \"\$($login)\" = webdeploy"
