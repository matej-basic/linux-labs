#!/bin/bash
# Reference solution for storage-05, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /srv/growvg
# solve: path /mnt/xfsdata
# solve: path /mnt/extdata
# solve: path /dev/growvg
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
vgs growvg
lvs growvg

# Step 2 [sudo]
LOOP=$(losetup --find --show /srv/growvg/disk2.img)
vgextend growvg "$LOOP"
pvs -S vg_name=growvg

# Step 3 [sudo]
lvextend -L 512M /dev/growvg/xfslv
xfs_growfs /mnt/xfsdata

# Step 4 [sudo]
lvextend -r -L 256M /dev/growvg/extlv
