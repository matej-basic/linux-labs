#!/bin/bash
# Reference solution for firewall-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
systemctl enable --now firewalld

# Step 2 [sudo]
firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port="443" protocol="tcp" accept'

# Step 3 [sudo]
IFACE=$(head -n 1 /opt/linux-labs/state/firewall-02)
firewall-cmd --permanent --zone=trusted --change-interface="$IFACE"

# Step 4 [sudo]
firewall-cmd --reload
