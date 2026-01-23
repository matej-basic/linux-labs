#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

dnf repolist | grep -qi "epel" && pass "EPEL repository is enabled" || { fail "EPEL repository not found"; rc=1; }
rpm -q htop &>/dev/null && pass "htop package is installed" || { fail "htop package not installed"; rc=1; }
which htop &>/dev/null && pass "htop command is available" || { fail "htop command not found"; rc=1; }

exit $rc

