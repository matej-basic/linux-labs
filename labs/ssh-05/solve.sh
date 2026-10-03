#!/bin/bash
# Reference solution for ssh-05, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# Port 22 and the key logins of the task user stay as they are: the
# Match block applies to deploy only, and sshd is reloaded only after
# sshd -t passes.
#
# solve: path /etc/ssh/lab_user_ca
# solve: path /etc/ssh/lab_user_ca.pub
# solve: path /home/deploy
# solve: path /home/opsadmin/deploy_ed25519.pub
# solve: path /home/opsadmin/deploy_ed25519-cert.pub
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

KEY=/opt/linux-labs/state/ssh-05.d/deploy_ed25519
home=$(getent passwd "$SOLVE_USER" | cut -d: -f6)

# Step 1 [sudo]
ssh-keygen -t ed25519 -N '' -C lab_user_ca -f /etc/ssh/lab_user_ca
ls -l /etc/ssh/lab_user_ca /etc/ssh/lab_user_ca.pub

# Step 2 [sudo]
tee -a /etc/ssh/sshd_config >/dev/null <<'END'

Match User deploy
    TrustedUserCAKeys /etc/ssh/lab_user_ca.pub
    AuthorizedKeysFile none
END
sshd -t
systemctl reload sshd
sleep 1

# Step 3 [sudo]
sshd -T -C user=deploy,host=localhost,addr=127.0.0.1 |
	grep -E '^(trustedusercakeys|authorizedkeysfile)'
sshd -T -C user=deploy,host=localhost,addr=127.0.0.1 |
	grep -x 'trustedusercakeys /etc/ssh/lab_user_ca.pub' >/dev/null
sshd -T -C "user=$SOLVE_USER,host=localhost,addr=127.0.0.1" |
	grep -x 'trustedusercakeys none' >/dev/null

# Step 4 [sudo]
ssh-keygen -s /etc/ssh/lab_user_ca -I deploy-cert -n deploy \
	-V +52w "$home/deploy_ed25519.pub"

# Step 5 [user]
run_as_student 'ssh-keygen -L -f ~/deploy_ed25519-cert.pub'

# Step 6 [sudo]
out=$(ssh -i "$KEY" -o CertificateFile="$home/deploy_ed25519-cert.pub" \
	-o StrictHostKeyChecking=accept-new deploy@localhost id -un </dev/null)
printf '%s\n' "$out"
test "$out" = deploy

# Step 7 [sudo]: the key alone is refused
if ssh -i "$KEY" -o IdentitiesOnly=yes -o BatchMode=yes \
	deploy@localhost id -un </dev/null; then
	echo "the key alone was accepted" >&2
	exit 1
fi
