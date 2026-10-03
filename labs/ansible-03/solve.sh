#!/bin/bash
# Reference solution for ansible-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# Step 1 (the SSH session to node 1) becomes run_on_node from the
# workstation as the lab user; steps 2 to 7 run as one script on node 1
# as the SSH user. zsh is installed on node 2; test-lab.sh checks the
# package set of every node after reset.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 7 [user]
run_as_student <<'STEPS'
# load-config.sh reads unset variables
set +u
source /opt/linux-labs/lib/load-config.sh
set -u

# Step 1
N1=$(get_node_ip 1)
run_on_node "$N1" "bash -euo pipefail -s" <<'NODE1'
# Step 2
cd ~/ansible-lab
ansible all -m ansible.builtin.ping </dev/null
(umask 077; echo 'lab-vault-secret' > .vault_pass)
sed -i '/^\[defaults\]/a vault_password_file = .vault_pass' \
  ansible.cfg
ls -l .vault_pass

# Step 3
mkdir -p group_vars/appservers
pw=$(sed -n 's/^Password of the user appadmin: //p' \
  ~/appadmin-password.txt)
printf -- '---\nappadmin_password: %s\n' "$pw" \
  > group_vars/appservers/vault.yml
ansible-vault encrypt group_vars/appservers/vault.yml </dev/null
head -n 1 group_vars/appservers/vault.yml
ansible-vault view group_vars/appservers/vault.yml </dev/null

# Step 4
cat > group_vars/appservers/vars.yml <<'EOF'
---
app_groups:
  - appdev
  - appops
  - appaudit
EOF

# Step 5
mkdir -p templates
cat > templates/motd.j2 <<'EOF'
Managed by Ansible
Release {{ motd_release }} with {{ motd_memory }} MB of memory
EOF

# Step 6
cat > users.yml <<'EOF'
---
- name: Manage appadmin, its groups and the login message
  hosts: appservers
  vars:
    motd_release: "{{ ansible_facts['distribution_major_version'] }}"
    motd_memory: "{{ ansible_facts['memtotal_mb'] }}"
    appadmin_hash: >-
      {{ appadmin_password | password_hash('sha512', 'ansible03') }}
  tasks:
    - name: The application groups exist
      ansible.builtin.group:
        name: "{{ item }}"
        state: present
      loop: "{{ app_groups }}"

    - name: appadmin exists with the password from the vault
      ansible.builtin.user:
        name: appadmin
        groups: "{{ app_groups }}"
        append: true
        password: "{{ appadmin_hash }}"

    - name: /etc/motd shows the release and the memory
      ansible.builtin.template:
        src: templates/motd.j2
        dest: /etc/motd
        owner: root
        group: root
        mode: "0644"

    - name: zsh is installed on admin nodes
      ansible.builtin.dnf:
        name: zsh
        state: present
      when: ansible_local['lab']['server']['role'] == 'admin'
EOF

# Step 7
ansible-playbook --syntax-check users.yml </dev/null
ansible-playbook users.yml </dev/null
ansible-playbook --check users.yml </dev/null
NODE1
STEPS
