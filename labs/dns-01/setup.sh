#!/bin/bash

# Reset lab state
systemctl stop named > /dev/null 2>&1
dnf remove -y bind bind-utils > /dev/null 2>&1

# Print task description
cat <<'EOF'

====================================================
LAB: DNS - BIND Installation (dns-01)
====================================================

OBJECTIVE:
Install BIND DNS server and start the named service,
verify it is running and accessible on port 53 (UDP
and TCP).

REQUIREMENTS:
- Install BIND DNS server packages (bind and bind-utils)
- Start the named service
- Enable named to start on boot
- Verify BIND is listening on port 53 (UDP and TCP)

NOTES:
- You may use any valid Linux commands
- The grading script checks only the final state
- Command history is NOT evaluated

When ready, run:
  sudo labctl grade dns-01

====================================================

EOF

