#!/bin/bash
# Reference solution for ansible-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# Step 1 (the SSH session to node 1) becomes run_on_node from the
# workstation as the lab user; steps 2 to 7 run as one script on node 1
# as the SSH user, with the node addresses of the lab configuration in
# place of the classroom defaults. httpd is installed on the nodes;
# test-lab.sh checks the package set of every node after reset.
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
N1=$(get_node_ip 1); N2=$(get_node_ip 2); N3=$(get_node_ip 3)
run_on_node "$N1" "bash -euo pipefail -s -- $N2 $N3" <<'NODE1'
N2=$1; N3=$2

# Step 2
cd ~/ansible-lab
ansible all -m ansible.builtin.ping </dev/null
mkdir -p roles/webserver/tasks roles/webserver/handlers
mkdir -p roles/webserver/defaults roles/webserver/templates
mkdir -p group_vars host_vars

# Step 3
cat > roles/webserver/defaults/main.yml <<'EOF'
---
web_greeting: Hello from Ansible
EOF
cat > roles/webserver/tasks/main.yml <<'EOF'
---
- name: The package httpd is installed
  ansible.builtin.dnf:
    name: httpd
    state: present

- name: The index page is deployed
  ansible.builtin.template:
    src: index.html.j2
    dest: /var/www/html/index.html
    owner: root
    group: root
    mode: "0644"

- name: The httpd configuration is deployed
  ansible.builtin.template:
    src: webserver.conf.j2
    dest: /etc/httpd/conf.d/webserver.conf
    owner: root
    group: root
    mode: "0644"
  notify: Restart httpd

- name: httpd is enabled and running
  ansible.builtin.service:
    name: httpd
    state: started
    enabled: true
EOF
cat > roles/webserver/handlers/main.yml <<'EOF'
---
- name: Restart httpd
  ansible.builtin.service:
    name: httpd
    state: restarted
EOF

# Step 4
cat > roles/webserver/templates/index.html.j2 <<'EOF'
{{ web_greeting }}
Served by {{ ansible_facts['hostname'] }}
EOF
cat > roles/webserver/templates/webserver.conf.j2 <<'EOF'
# Managed by Ansible
ServerName {{ inventory_hostname }}
EOF

# Step 5
cat > group_vars/webservers.yml <<'EOF'
---
web_greeting: Welcome to the web farm
EOF
cat > "host_vars/$N3.yml" <<'EOF'
---
web_greeting: Welcome to the staging server
EOF
ansible-inventory --host "$N2" </dev/null
ansible-inventory --host "$N3" </dev/null

# Step 6
cat > site.yml <<'EOF'
---
- name: Deploy the web servers
  hosts: webservers
  roles:
    - webserver
EOF

# Step 7
ansible-playbook --syntax-check site.yml </dev/null
ansible-playbook site.yml </dev/null
ansible-playbook --check site.yml </dev/null
NODE1
STEPS
