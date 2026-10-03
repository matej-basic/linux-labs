#!/bin/bash
# storage-08 setup: removes what an earlier run left behind, creates the
# sparse, unformatted 512 MiB image /srv/storage-08.img, the users qalice
# and qbob, the group qteam with both as members, and the state file.
# Prints nothing on success.
set -eu

IMG=/srv/storage-08.img
MNT=/srv/projects
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/storage-08"

fail() {
	echo "storage-08: $*" >&2
	exit 1
}

for c in losetup blkid mkfs.xfs xfs_quota findmnt; do
	command -v "$c" >/dev/null 2>&1 ||
		fail "the command $c is missing (util-linux and xfsprogs are required)"
done

# Remove what an earlier run or its solution left behind
bash "$(dirname "$0")/cleanup.sh"

if mountpoint -q "$MNT" 2>/dev/null; then
	fail "$MNT is a mount point of something else; refusing to start"
fi
for x in qalice qbob qteam; do
	if getent passwd "$x" >/dev/null || getent group "$x" >/dev/null; then
		fail "cannot remove the old user or group $x"
	fi
done

modprobe loop >/dev/null 2>&1 || true
[ -e /dev/loop-control ] || fail "loop devices are not available on this system"

mkdir -p /srv
truncate -s 512M "$IMG"
chmod 600 "$IMG"

groupadd qteam || fail "cannot create the group qteam"
for u in qalice qbob; do
	useradd -m -G qteam -c "storage-08 lab account" "$u" ||
		fail "cannot create the user $u"
done

mkdir -p "$STATE_DIR"
printf '%s\n' "$IMG" > "$STATE_FILE"
chmod 644 "$STATE_FILE"
