#!/bin/bash
# Networking Lab 03: Network Teaming/Bonding with Failover (Advanced)

cat <<'EOF'
====================================================
LAB: Networking 03 - Network Teaming/Bonding
====================================================

OBJECTIVE
Configure network teaming or bonding with failover.

REQUIREMENTS
1) Create team0 (or bond0) interface.
2) Add two available slave interfaces (use ip link to find).
3) IP Address: 192.168.100.1/24 on team/bond.
4) Make persistent in NetworkManager.

USEFUL COMMANDS (TEAMING)
- Find interfaces: ip link show | grep -E '^[0-9]+: (eth|ens)' | cut -d: -f2 | tr -d ' '
- nmcli connection add 
- nmcli connection modify 
- nmcli connection up

TESTING FAILOVER
- ip link set eth0 down
- ping 192.168.100.1
- ip link set eth0 up

Run grading when done:
  sudo labctl grade networking-03
====================================================
EOF
