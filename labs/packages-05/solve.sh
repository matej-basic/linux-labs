#!/bin/bash
# Reference solution for packages-05, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /usr/bin/joe
# solve: path /etc/joe
# solve: path /usr/share/joe
# solve: path /home/opsadmin/src
# solve: path /home/opsadmin/joe-4.6.tar.gz
#
# gcc and make are not declared as packages: some base images already
# have them (Rocky 9 with gcc from the installer), and then reset keeps
# them. test-lab.sh compares the whole package set before and after,
# which catches a gcc the lab installed and reset left behind.
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q gcc make &>/dev/null || dnf -y install gcc make >/dev/null

# Steps 2 to 4 [user]
run_as_student <<'STEPS'
curl -fsSL -o joe-4.6.tar.gz "https://sourceforge.net/projects/joe-editor/files/JOE%20sources/joe-4.6/joe-4.6.tar.gz/download"
mkdir -p ~/src
tar xf joe-4.6.tar.gz -C ~/src
cd ~/src/joe-4.6
./configure --prefix=/usr --sysconfdir=/etc >/dev/null
make >/dev/null
STEPS

# Step 5 [sudo]
home=$(getent passwd "${SOLVE_USER:-opsadmin}" | cut -d: -f6)
make -C "$home/src/joe-4.6" install >/dev/null
