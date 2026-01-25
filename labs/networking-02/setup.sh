#!/bin/bash
# Networking Lab 02: VLAN and Hostname Configuration (Intermediate)

cat <<'EOF'
====================================================
LAB: Networking 02 - VLAN and Hostname
====================================================

OBJECTIVE
Create VLAN interface and configure hostname/FQDN.

REQUIREMENTS
1) Create VLAN interface vlan10 on default route interface with VLAN ID 10.
    - IP Address: 192.168.10.1/24
    - Make persistent in NetworkManager.
    - Set hostname to: labhost
    - Add FQDN to /etc/hosts: labhost.example.com

USEFUL COMMANDS
- nmcli connection add 
- nmcli connection modify 
- hostnamectl 
- ip addr show
- hostname
- hostnamectl

Run grading when done:
  sudo labctl grade networking-02
====================================================
EOF
