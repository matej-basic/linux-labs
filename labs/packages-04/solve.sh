#!/bin/bash
# Reference solution for packages-04, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /home/student/joe.rpm
# solve: package joe
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]: find the file name in the EPEL directory and download it
run_as_student <<'STEPS'
MAJOR=$(. /etc/os-release && echo "${VERSION_ID%%.*}")
ARCH=$(uname -m)
URL="https://dl.fedoraproject.org/pub/epel/$MAJOR/Everything/$ARCH/Packages/j/"
# dl.fedoraproject.org intermittently answers 404 (observed on 2026-10-02), so retry
get() { for i in 1 2 3 4 5 6; do curl -fsSL "$@" && return 0; sleep 3; done; return 1; }
NAME=$(get "$URL" | grep -o 'joe-[0-9][^"<]*\.rpm' | sort -uV | tail -n 1)
get -o joe.rpm "$URL$NAME"
STEPS

# Step 2 [sudo]: install from the file
home=$(getent passwd student | cut -d: -f6)
dnf -y install "$home/joe.rpm"

# Step 3 is the interactive editor test and is skipped here.
# Step 4 [user]: locate the command
run_as_student 'command -v joe; rpm -ql joe | grep bin'

# Step 5 [sudo]: remove the package
dnf -y remove joe
