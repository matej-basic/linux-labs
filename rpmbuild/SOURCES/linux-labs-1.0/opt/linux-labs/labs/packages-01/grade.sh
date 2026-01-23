#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

rpm -q git &>/dev/null && pass "git package is installed" || { fail "git package not installed"; rc=1; }
which git &>/dev/null && pass "git command is available" || { fail "git command not found"; rc=1; }
dnf list --installed &>/dev/null && pass "dnf list --installed works" || { fail "dnf list --installed failed"; rc=1; }

exit $rc

