#!/bin/bash
# Networking Lab 01: Static IP Configuration (Beginner)

cat <<'EOF'
====================================================
LAB: Networking 01 - Static IP Configuration
====================================================

OBJECTIVE
Configure static IP using NetworkManager (nmcli).

REQUIREMENTS
1) Create NetworkManager connection named 'labnet-static'.
    - IP Address: 192.168.1.100/24
    - Gateway: 192.168.1.1
    - DNS: 8.8.8.8
    - Apply to the interface with default route.

USEFUL COMMANDS
- nmcli connection add
- nmcli connection modify 
- nmcli connection up
- ip addr show
- ip route show

Run grading when done:
  sudo labctl grade networking-01
====================================================
EOF
