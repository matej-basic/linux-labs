#!/bin/bash
# Reference solution for logging-05, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# Everything happens on the nodes, which labctl reset puts back and
# test-lab.sh checks (package set, system users); no path or package on
# the workstation needs checking.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 and 5 [user]: the workstation logs in to the nodes as the
# node account. Steps 2 to 4 [sudo] run on node 1, steps 6 and 7 [sudo]
# on node 2.
run_as_student <<'STEPS'
set +u
source /opt/linux-labs/lib/load-config.sh
load_lab_config
set -u
N1=$(get_node_ip 1)
N2=$(get_node_ip 2)

run_on_node "$N1" "bash -euo pipefail -s" <<'NODE1'
# Step 2
sudo tee /etc/rsyslog.d/remote-server.conf >/dev/null <<'EOF'
module(load="imtcp")

template(name="RemoteHostFile" type="string"
         string="/var/log/remote/%HOSTNAME%/messages")

ruleset(name="remote") {
    action(type="omfile" dynaFile="RemoteHostFile")
}

input(type="imtcp" port="514" ruleset="remote")
EOF

# Step 3
sudo rsyslogd -N1 >/dev/null 2>&1
sudo systemctl enable rsyslog >/dev/null 2>&1
sudo systemctl restart rsyslog

# Step 4
sudo firewall-cmd --add-port=514/tcp >/dev/null
sudo firewall-cmd --permanent --add-port=514/tcp >/dev/null
NODE1

run_on_node "$N2" "N1='$N1' bash -euo pipefail -s" <<'NODE2'
# Step 6
sudo tee /etc/rsyslog.d/forward.conf >/dev/null <<EOF
*.info action(type="omfwd" target="$N1" port="514"
              protocol="tcp"
              queue.type="LinkedList" queue.filename="fwd_node1"
              queue.maxDiskSpace="100m" queue.saveOnShutdown="on"
              action.resumeRetryCount="-1")
EOF

# Step 7
sudo rsyslogd -N1 >/dev/null 2>&1
sudo systemctl enable rsyslog >/dev/null 2>&1
sudo systemctl restart rsyslog
NODE2
STEPS
