#!/bin/bash
# Reference solution for networking-05, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

iface=$(sed -n 1p /opt/linux-labs/state/networking-05)

# Step 1 [user]
run_as_student <<'STEPS'
head -n 1 /opt/linux-labs/state/networking-05
ip route show default
nmcli device status
nmcli connection show
STEPS

# Step 2 [sudo]: the activation fails while the faults are there
if nmcli connection up labnet; then
	echo "labnet came up before it was fixed" >&2
	exit 1
fi

# Step 3 [user]
run_as_student "nmcli -f connection.interface-name,connection.autoconnect,ipv4.method,ipv4.addresses,ipv4.gateway connection show labnet"

# Steps 4 to 6 [sudo]
nmcli connection modify labnet \
	connection.interface-name "$iface" ipv4.method manual \
	connection.autoconnect yes
nmcli connection delete labnet-old
nmcli connection up labnet

# Step 7 [user]
run_as_student "ip -br addr show $iface; ip route show default; nmcli -f NAME,AUTOCONNECT,AUTOCONNECT-PRIORITY,DEVICE connection show"
