#!/bin/bash
# Networking Lab 02: Cleanup

nmcli connection delete vlan10 &>/dev/null || true
ip link delete vlan10 &>/dev/null 2>&1 || true
hostnamectl set-hostname localhost &>/dev/null || true
sed -i '/labhost\.example\.com/d' /etc/hosts 2>/dev/null || true

echo "Cleanup complete."
