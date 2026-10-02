#!/bin/bash
# Reference solution for ansible-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# Step 1 (the SSH session to node 1) becomes run_on_node from the
# workstation as the lab user; steps 2 to 7 run as one script on node 1
# as the SSH user. ssh-copy-id has no terminal there, so it gets the
# password redhat from a temporary SSH_ASKPASS script and accepts the
# new host keys with StrictHostKeyChecking=accept-new instead of the
# interactive yes. The packages are installed on the nodes; test-lab.sh
# checks the package set of every node after reset.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 7 [user] and [sudo]
run_as_student <<'STEPS'
# load-config.sh reads unset variables
set +u
source /opt/linux-labs/lib/load-config.sh
set -u

# Step 1
N1=$(get_node_ip 1); N2=$(get_node_ip 2); N3=$(get_node_ip 3)
run_on_node "$N1" "bash -euo pipefail -s -- $N2 $N3" <<'NODE1'
N2=$1; N3=$2

# Step 2
rpm -q ansible-core || sudo -n dnf -y install ansible-core </dev/null

# Step 3
[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519 </dev/null
ap=$(mktemp)
printf '#!/bin/sh\necho redhat\n' > "$ap"
chmod 0700 "$ap"
for ip in $N2 $N3; do
  DISPLAY=none SSH_ASKPASS="$ap" setsid -w ssh-copy-id \
    -o StrictHostKeyChecking=accept-new ansible@$ip </dev/null
done
rm -f "$ap"

# Step 4
mkdir -p ~/ansible-lab
cd ~/ansible-lab
cat > ansible.cfg <<'EOF'
[defaults]
inventory = ./inventory
remote_user = ansible

[privilege_escalation]
become = true
become_method = sudo
EOF
cat > inventory <<EOF
[webservers]
$N2
$N3
EOF

# Step 5
ansible --version | grep 'config file'
ansible-config dump --only-changed
ansible all -m ansible.builtin.ping </dev/null

# Step 6
cat > site.yml <<'EOF'
---
- name: Deploy a web server
  hosts: webservers
  become: true
  tasks:
    - name: The package httpd is installed
      ansible.builtin.dnf:
        name: httpd
        state: present

    - name: The index page is deployed
      ansible.builtin.copy:
        content: "This web server is managed by Ansible.\n"
        dest: /var/www/html/index.html
        owner: root
        group: root
        mode: "0644"

    - name: httpd is enabled and running
      ansible.builtin.service:
        name: httpd
        state: started
        enabled: true
EOF

# Step 7
ansible-playbook --syntax-check site.yml </dev/null
ansible-playbook site.yml </dev/null
ansible-playbook --check site.yml </dev/null
NODE1
STEPS
