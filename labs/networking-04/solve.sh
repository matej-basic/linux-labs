#!/bin/bash
# Reference solution for networking-04, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

iface=$(sed -n 1p /opt/linux-labs/state/networking-04)

# Step 1 [user]
run_as_student <<'STEPS'
head -n 1 /opt/linux-labs/state/networking-04
ip route show default
nmcli device status
STEPS

# Steps 2 to 4 [sudo]
nmcli connection add type ethernet con-name lab-v6 \
	ifname "$iface" autoconnect yes \
	ipv4.method manual ipv4.addresses 192.168.150.10/24 \
	ipv6.method manual ipv6.addresses fd00:150::10/64
nmcli connection modify lab-v6 \
	ipv4.routes "10.150.0.0/24 192.168.150.254" \
	ipv6.routes "fd00:250::/64 fd00:150::fe"
nmcli connection up lab-v6

# Duplicate address detection takes a moment before the IPv6 address
# is usable
for _ in $(seq 1 20); do
	ip -6 -o addr show dev "$iface" scope global | grep -q tentative || break
	sleep 0.5
done

# Step 5 [user]
run_as_student "ip -br addr show $iface; ip -4 route show dev $iface; ip -6 route show dev $iface; ip route show default"
