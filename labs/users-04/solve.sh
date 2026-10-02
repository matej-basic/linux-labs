#!/bin/bash
# Reference solution for users-04, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /etc/security/pwquality.conf.d/50-policy.conf
# solve: path /home/pamtest
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
authselect current >/dev/null
authselect enable-feature with-faillock >/dev/null
authselect enable-feature with-pwhistory >/dev/null
authselect check >/dev/null

# Step 2 [sudo]
tee /etc/security/pwquality.conf.d/50-policy.conf >/dev/null <<'CONF'
minlen = 12
minclass = 3
dictcheck = 1
enforce_for_root
CONF

# Step 3 [sudo]
sed -i -E \
	-e 's/^#? *deny *=.*/deny = 3/' \
	-e 's/^#? *unlock_time *=.*/unlock_time = 600/' \
	/etc/security/faillock.conf

# Step 4 [sudo]
sed -i -E \
	-e 's/^#? *remember *=.*/remember = 5/' \
	-e 's/^#? *enforce_for_root.*/enforce_for_root/' \
	/etc/security/pwhistory.conf

# The task user still logs in and uses sudo after the PAM change
run_as_student 'sudo -n true'
