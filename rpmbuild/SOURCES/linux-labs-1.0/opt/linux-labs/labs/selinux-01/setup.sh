#!/bin/bash

# Set SELinux to permissive mode for the lab to start
sudo setenforce 0 2>/dev/null || true
sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true

cat <<'EOF'
====================================================
LAB: SELinux 01 - Enforcing Mode
====================================================

OBJECTIVE
Configure SELinux to run in enforcing mode.

REQUIREMENTS
1) Set SELinux to enforcing mode immediately

2) Make the enforcing mode persistent

3) Understand SELinux modes:
   - enforcing: Policy enforced, violations blocked and logged
   - permissive: Policy not enforced, violations only logged
   - disabled: SELinux completely disabled

USEFUL COMMANDS
- getenforce (check current mode)
- setenforce 0|1 (set permissive|enforcing temporarily)
- sestatus (detailed SELinux status)
- /etc/selinux/config (persistent configuration)

Run grading when done:
  sudo labctl grade selinux-01
====================================================
EOF
