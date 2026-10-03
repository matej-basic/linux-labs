#!/bin/bash
# Reference solution for git-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# Everything happens on the nodes, which labctl reset puts back and
# test-lab.sh checks (package set, system users); no path or package on
# the workstation needs checking.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 and 7 [user]: the workstation logs in to the nodes as the
# node account. Steps 2 to 5 run on node 1, step 6 on the workstation,
# steps 8 to 11 on node 2. The host key of node 1 is accepted without a
# prompt, the only difference to solution.md.
run_as_student <<'STEPS'
set +u
source /opt/linux-labs/lib/load-config.sh
load_lab_config
set -u
N1=$(get_node_ip 1)
N2=$(get_node_ip 2)

run_on_node "$N1" "bash -euo pipefail -s" <<'NODE1'
# Step 2
rpm -q git >/dev/null || sudo dnf -y install git >/dev/null
grep -qx /usr/bin/git-shell /etc/shells ||
  echo /usr/bin/git-shell | sudo tee -a /etc/shells >/dev/null

# Step 3
sudo useradd -m -d /home/git -s /usr/bin/git-shell git

# Step 4
sudo mkdir -p /srv/git
sudo git init -q --bare -b main /srv/git/project.git
sudo chown -R git:git /srv/git

# Step 5
sudo install -d -m 0700 -o git -g git /home/git/.ssh
sudo install -m 0600 -o git -g git /dev/null /home/git/.ssh/authorized_keys
sudo restorecon -R /home/git/.ssh
NODE1

# Step 6
run_on_node "$N2" "cat .ssh/id_ed25519.pub" </dev/null |
  run_on_node "$N1" "sudo tee -a /home/git/.ssh/authorized_keys" >/dev/null

run_on_node "$N2" "N1='$N1' bash -euo pipefail -s" <<'NODE2'
# Step 8
rpm -q git >/dev/null || sudo dnf -y install git >/dev/null

# Step 9
export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=accept-new'
if ssh -o StrictHostKeyChecking=accept-new "git@$N1" </dev/null >/dev/null 2>&1; then
  echo "git got a shell on node 1" >&2
  exit 1
fi
git clone -q "git@$N1:/srv/git/project.git" ~/project </dev/null

# Step 10
cd ~/project
git config user.name "Lab Admin"
git config user.email admin@lab.example

# Step 11
echo "Shared project repository" > README.md
git add README.md
git commit -q -m "Add README"
git branch -M main
git push -q -u origin main </dev/null
NODE2
STEPS
