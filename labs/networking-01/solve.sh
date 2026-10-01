#!/bin/bash
# Reference solution for networking-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]: the free interface is recorded by setup.sh
IFACE=$(sed -n 1p /opt/linux-labs/state/networking-01)

# Steps 2 and 3 [sudo]
nmcli connection add type ethernet con-name labnet-static \
	ifname "$IFACE" ipv4.method manual ipv4.addresses 192.168.1.100/24 \
	ipv4.dns 8.8.8.8 ipv4.never-default yes
nmcli connection up labnet-static
