#!/bin/bash
# packages-02 setup: remove EPEL and htop so the lab starts from a
# clean state. Prints nothing on success. The package set and the
# repository files are recorded on the first start, so that reset can
# put them back.
set -eu
source /opt/linux-labs/lib/packages.sh

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/packages-02"

command -v dnf >/dev/null 2>&1 || { echo "setup: dnf not found" >&2; exit 1; }

# First start only: record the package set before any dnf change
pkg_snapshot packages-02

mkdir -p "$STATE_DIR"
echo packages-02 > "$STATE_FILE"
chmod 644 "$STATE_FILE"

if rpm -q htop >/dev/null 2>&1; then
	dnf -y -q remove htop >/dev/null 2>&1 || { echo "setup: cannot remove htop" >&2; exit 1; }
fi
if rpm -q epel-release >/dev/null 2>&1; then
	dnf -y -q remove epel-release >/dev/null 2>&1 || { echo "setup: cannot remove epel-release" >&2; exit 1; }
fi
# Repo files a student created by hand
rm -f /etc/yum.repos.d/epel*.repo
exit 0
