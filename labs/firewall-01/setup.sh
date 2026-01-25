#!/bin/bash

# Print that we are setting up the lab
echo "Setting up firewall-01 lab..."

# Reset lab state - remove any test rules if they exist
firewall-cmd --remove-service=http --zone=public --permanent >/dev/null 2>&1
firewall-cmd --remove-port=8080/tcp --zone=public --permanent >/dev/null 2>&1
firewall-cmd --reload >/dev/null 2>&1

# Print task description
cat <<'EOF'

====================================================
LAB: Firewalld Basics (firewall-01)
====================================================

OBJECTIVE:
Learn firewalld fundamentals by managing services
and ports in the default public zone.

REQUIREMENTS:
1. Add HTTP service to the public zone

2. Add custom port 8080/tcp to the public zone

3. Verify the rules are active

4. Verify both are removed

NOTES:
- All changes must be made without --permanent flag (temporary)
- Changes apply immediately to the running firewall
- The grading checks that both http service and port 8080 are active
- Run 'sudo firewall-cmd --list-all' to see current rules
- Run 'sudo firewall-cmd --reload' to reload from disk configuration

When ready, run:
  sudo labctl grade firewall-01

====================================================

EOF

