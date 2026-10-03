#!/bin/bash
# Reference solution for packages-06, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /etc/yum.repos.d/labrepo.repo
# solve: package zsh
# solve: package ksh
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]
run_as_student <<'STEPS'
dnf repolist --all >/dev/null
ls /etc/pki/rpm-gpg >/dev/null
STEPS

# Step 2 [sudo]: the key file name differs between the releases
el=$(. /etc/os-release && echo "${VERSION_ID%%.*}")
if [ "$el" = 8 ]; then
	key=RPM-GPG-KEY-rockyofficial
else
	key=RPM-GPG-KEY-Rocky-9
fi
sed "s/@KEY@/$key/" >/etc/yum.repos.d/labrepo.repo <<'EOF'
[lab-baseos]
name=Lab BaseOS
baseurl=https://dl.rockylinux.org/pub/rocky/$releasever/BaseOS/$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/@KEY@

[lab-appstream]
name=Lab AppStream
baseurl=https://dl.rockylinux.org/pub/rocky/$releasever/AppStream/$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/@KEY@
EOF

# Step 3 [user]
run_as_student <<'STEPS'
dnf repolist
dnf info zsh ksh >/dev/null
STEPS

# Step 4 [sudo]
rpm -q zsh >/dev/null || dnf -y install zsh >/dev/null
rpm -q ksh >/dev/null || dnf -y install ksh >/dev/null

# Step 5 [user]
run_as_student 'dnf list installed zsh ksh'
