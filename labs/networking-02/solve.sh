#!/bin/bash
# Reference solution for networking-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]: the free NIC is the first line of the state file
nic=$(head -n 1 /opt/linux-labs/state/networking-02)

# Step 2 [sudo]
nmcli connection add type vlan con-name vlan10 ifname vlan10 \
	dev "$nic" id 10 ipv4.method manual ipv4.addresses 192.168.10.1/24
nmcli connection up vlan10

# Step 3 [sudo]
hostnamectl set-hostname labhost

# Step 4 [sudo]
echo "192.168.10.1 labhost.example.com labhost" >> /etc/hosts
