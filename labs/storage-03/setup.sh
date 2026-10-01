#!/bin/bash
# storage-03 setup: no snapvg, no /tmp/snap.img, no lab mounts. Prints
# nothing on success. Refuses to start if a volume group named snapvg
# lives on something other than loop devices (not ours to remove).
set -eu

if vgs --noheadings snapvg >/dev/null 2>&1; then
	pvs=$(pvs --noheadings -o pv_name -S vg_name=snapvg 2>/dev/null || true)
	for pv in $pvs; do
		case "$pv" in
			/dev/loop*) ;;
			*)
				echo "Error: volume group snapvg exists on $pv, not on a loop device. Refusing to remove it." >&2
				exit 1
				;;
		esac
	done
fi

# Remove anything a previous run or solution left behind
"$(dirname "$0")/cleanup.sh"
