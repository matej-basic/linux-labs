#!/bin/bash
# Reference solution for ssh-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /home/deploy
# solve: path /home/opsadmin/.ssh/deploy_ed25519
# solve: path /home/opsadmin/.ssh/deploy_ed25519.pub
# solve: path /home/opsadmin/.ssh/config
# solve: path /home/opsadmin/.ssh/known_hosts
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

home=$(getent passwd "$SOLVE_USER" | cut -d: -f6)

# Step 1 [user]
run_as_student <<'STEPS'
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/deploy_ed25519
STEPS

# Step 2 [sudo]
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
install -m 600 -o deploy -g deploy "$home/.ssh/deploy_ed25519.pub" \
	/home/deploy/.ssh/authorized_keys
restorecon -R /home/deploy/.ssh

# Steps 3 and 4 [user]; accept-new answers the host key question
run_as_student <<'STEPS'
cat >> ~/.ssh/config <<'CONFIG'
Host deploy-local
    HostName localhost
    User deploy
    IdentityFile ~/.ssh/deploy_ed25519
CONFIG
chmod 600 ~/.ssh/config
test "$(ssh -o StrictHostKeyChecking=accept-new deploy-local id -un </dev/null)" = deploy
STEPS
