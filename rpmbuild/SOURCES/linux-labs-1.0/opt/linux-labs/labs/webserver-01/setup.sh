#!/bin/bash

# Reset lab state
systemctl stop httpd > /dev/null 2>&1
yum remove -y httpd > /dev/null 2>&1

# Print task description
cat <<'EOF'

====================================================
LAB: Web Servers - Apache Installation (webserver-01)
====================================================

OBJECTIVE:
Install and start Apache HTTP Server, verify it is
running and accessible on port 80.

REQUIREMENTS:
- Install Apache HTTP Server package (httpd)
- Start the httpd service
- Enable httpd to start on boot
- Verify Apache is listening on port 80

NOTES:
- You may use any valid Linux commands
- The grading script checks only the final state
- Command history is NOT evaluated

When ready, run:
  sudo labctl grade webserver-01

====================================================

EOF

