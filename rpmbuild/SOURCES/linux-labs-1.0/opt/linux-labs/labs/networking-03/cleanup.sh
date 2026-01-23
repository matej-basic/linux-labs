#!/bin/bash
# Networking Lab 03: Cleanup

nmcli connection delete team0-eth0 &>/dev/null 2>&1 || true
nmcli connection delete team0-eth1 &>/dev/null 2>&1 || true
nmcli connection delete team0 &>/dev/null || true

nmcli connection delete bond0-eth0 &>/dev/null 2>&1 || true
nmcli connection delete bond0-eth1 &>/dev/null 2>&1 || true
nmcli connection delete bond0 &>/dev/null || true

ip link delete team0 &>/dev/null 2>&1 || true
ip link delete bond0 &>/dev/null 2>&1 || true

for iface in eth0 eth1 eth2 ens0 ens1 ens2; do
    ip link set "$iface" up &>/dev/null 2>&1 || true
done

echo "Cleanup complete."
