#!/bin/bash
# Reference solution for firewall-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /etc/firewalld/services/custom-app.xml
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
systemctl enable --now firewalld

# Step 2 [sudo]
firewall-cmd --permanent --zone=internal --add-masquerade
firewall-cmd --permanent --zone=public \
	--add-forward-port=port=8443:proto=tcp:toport=443
firewall-cmd --permanent --zone=public --add-service=http

# Step 3 [sudo]
firewall-cmd --permanent --new-service=custom-app
firewall-cmd --permanent --service=custom-app \
	--set-description="Sample Custom Application Service"
firewall-cmd --permanent --service=custom-app --add-port=9090/tcp
firewall-cmd --permanent --service=custom-app --add-port=9090/udp

# Step 4 [sudo]
firewall-cmd --permanent --zone=public --add-service=custom-app
firewall-cmd --reload
