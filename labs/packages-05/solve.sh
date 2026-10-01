#!/bin/bash
# Reference solution for packages-05, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /usr/bin/joe
# solve: path /etc/joe
# solve: path /usr/share/joe
# solve: path /home/student/src
# solve: path /home/student/joe-4.6.tar.gz
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
dnf -y install gcc make >/dev/null

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
make -C /home/student/src/joe-4.6 install >/dev/null
