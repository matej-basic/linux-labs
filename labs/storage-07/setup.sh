#!/bin/bash
# storage-07 setup: records the package set, /etc/crypttab and whether
# /etc/luks-keys exists (first start only), removes what an earlier run
# left behind, creates the sparse 512 MiB image /srv/storage-07.img,
# attaches it to a loop device, writes the loop device name as the first
# line of the state file and a random starting passphrase to
# /root/luks-passphrase (root only). Prints nothing on success. Only the
# loop device of the image is touched, never the disk of the system.
set -eu
source /opt/linux-labs/lib/packages.sh

IMG=/srv/storage-07.img
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/storage-07"
ORIG="$STATE_DIR/storage-07.orig"
PASS_FILE=/root/luks-passphrase

pkg_snapshot storage-07

for c in losetup blkid mkfs.xfs dmsetup; do
	if ! command -v "$c" >/dev/null 2>&1; then
		echo "storage-07: the command $c is missing (util-linux, xfsprogs and device-mapper are required)" >&2
		exit 1
	fi
done

# What the lab changes outside its own files, recorded once at the first
# start so that a restart keeps the original
if [ ! -e "$ORIG/recorded" ]; then
	rm -rf "$ORIG"
	mkdir -p "$ORIG"
	chmod 700 "$ORIG"
	if [ -e /etc/crypttab ]; then
		cp -p /etc/crypttab "$ORIG/crypttab"
	fi
	if [ -d /etc/luks-keys ]; then
		touch "$ORIG/keydir-existed"
		[ -e /etc/luks-keys/secret.key ] && touch "$ORIG/key-existed"
	fi
	touch "$ORIG/recorded"
fi

# Remove what an earlier run or its solution left behind
bash "$(dirname "$0")/cleanup.sh" --leftovers

if mountpoint -q /mnt/secure 2>/dev/null; then
	echo "storage-07: /mnt/secure is a mount point of something else; refusing to start" >&2
	exit 1
fi
if [ -e /dev/mapper/securedata ]; then
	echo "storage-07: the device mapping securedata belongs to something else; refusing to start" >&2
	exit 1
fi

modprobe loop >/dev/null 2>&1 || true
if [ ! -e /dev/loop-control ]; then
	echo "storage-07: loop devices are not available on this system" >&2
	exit 1
fi

mkdir -p /srv
truncate -s 512M "$IMG"
chmod 600 "$IMG"
if ! loop=$(losetup --find --show "$IMG" 2>&1); then
	echo "storage-07: cannot attach $IMG to a loop device: $loop" >&2
	rm -f "$IMG"
	exit 1
fi
udevadm settle >/dev/null 2>&1 || true

# A random passphrase that passes the password quality check of
# cryptsetup: 20 letters and digits with at least one of each kind
pass=""
while ! { printf '%s' "$pass" | grep -q '[a-z]' &&
	printf '%s' "$pass" | grep -q '[A-Z]' &&
	printf '%s' "$pass" | grep -q '[0-9]'; }; do
	pass=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20 || true)
done
(
	umask 077
	printf '%s\n' "$pass" > "$PASS_FILE"
	printf '%s\n' "$pass" > "$ORIG/passphrase"
)
chown root:root "$PASS_FILE"
chmod 600 "$PASS_FILE" "$ORIG/passphrase"
restorecon "$PASS_FILE" >/dev/null 2>&1 || true

mkdir -p "$STATE_DIR"
printf '%s\n' "$loop" > "$STATE_FILE"
chmod 644 "$STATE_FILE"
