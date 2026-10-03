#!/bin/bash
# Reference solution for dns-04, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# Everything happens on the nodes, which labctl reset puts back and
# test-lab.sh checks (package set, system users); no path or package on
# the workstation needs checking.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 and 4 [user]: the workstation logs in to the nodes as the
# node account. Steps 2 and 3 [sudo] run on node 1, steps 5 to 7
# [sudo] on node 2. The edits of named.conf, done with an editor in
# solution.md, are done with sed here.
run_as_student <<'STEPS'
set +u
source /opt/linux-labs/lib/load-config.sh
load_lab_config
set -u
N1=$(get_node_ip 1)
N2=$(get_node_ip 2)

run_on_node "$N1" "N1='$N1' N2='$N2' bash -euo pipefail -s" <<'NODE1'
# Step 2
sudo sed -i \
  -e "s/^\([[:space:]]*listen-on port 53 { 127.0.0.1;\) };/\1 $N1; };/" \
  -e "s/^\([[:space:]]*allow-query[[:space:]]*{ localhost;\) };/\1 $N2; };/" \
  -e "s/^\([[:space:]]*\)file \"lab.example.zone\";/&\n\1allow-transfer { $N2; };\n\1also-notify { $N2; };/" \
  /etc/named.conf
sudo grep -q "listen-on port 53 { 127.0.0.1; $N1; };" /etc/named.conf
sudo grep -q "allow-query.*{ localhost; $N2; };" /etc/named.conf
sudo grep -q "also-notify { $N2; };" /etc/named.conf

# Step 3
sudo named-checkconf
sudo systemctl enable --now named </dev/null >/dev/null 2>&1
sudo firewall-cmd --add-service=dns >/dev/null
sudo firewall-cmd --permanent --add-service=dns >/dev/null
NODE1

run_on_node "$N2" "N1='$N1' N2='$N2' bash -euo pipefail -s" <<'NODE2'
# Step 5
rpm -q bind bind-utils >/dev/null ||
  sudo dnf -y install bind bind-utils </dev/null >/dev/null

# Step 6
sudo sed -i \
  -e "s/^\([[:space:]]*listen-on port 53 { 127.0.0.1;\) };/\1 $N2; };/" \
  /etc/named.conf
sudo grep -q "listen-on port 53 { 127.0.0.1; $N2; };" /etc/named.conf
sudo tee -a /etc/named.conf >/dev/null <<CONF

zone "lab.example" IN {
	type slave;
	masters { $N1; };
	file "slaves/lab.example.zone";
};
CONF

# Step 7
sudo named-checkconf
sudo firewall-cmd --add-service=dns >/dev/null
sudo firewall-cmd --permanent --add-service=dns >/dev/null
sudo systemctl enable --now named </dev/null >/dev/null 2>&1

# Wait for the first transfer
for _ in $(seq 1 30); do
  sudo test -s /var/named/slaves/lab.example.zone && exit 0
  sleep 1
done
echo "node 2 did not transfer lab.example" >&2
exit 1
NODE2
STEPS
