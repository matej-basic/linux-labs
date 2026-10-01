#!/bin/bash
# Reference solution for networking-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

STATE_FILE=/opt/linux-labs/state/networking-03
port1=$(sed -n 's/^port1=//p' "$STATE_FILE")
port2=$(sed -n 's/^port2=//p' "$STATE_FILE")

# Step 1 [user]
run_as_student <<'STEPS'
ip route show default
nmcli device status
STEPS

# Steps 2 to 4 [sudo]
nmcli connection add type bond con-name bond0 ifname bond0 \
	bond.options "mode=active-backup,miimon=100" \
	ipv4.method manual ipv4.addresses 192.168.100.1/24
nmcli connection add type ethernet slave-type bond \
	con-name bond0-port1 ifname "$port1" master bond0
nmcli connection add type ethernet slave-type bond \
	con-name bond0-port2 ifname "$port2" master bond0
nmcli connection up bond0
nmcli connection up bond0-port1
nmcli connection up bond0-port2

# Step 5 [user]
run_as_student <<'STEPS'
ip -br addr show bond0
cat /proc/net/bonding/bond0
STEPS
