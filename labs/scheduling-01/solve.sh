#!/bin/bash
# Reference solution for scheduling-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /var/log/daily-task.log
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 3 [sudo]: equivalent of crontab -e and crontab -l
{
	crontab -u root -l 2>/dev/null || true
	echo "0 2 * * * echo 'Daily task executed' >> /var/log/daily-task.log"
} | crontab -u root -
crontab -u root -l
