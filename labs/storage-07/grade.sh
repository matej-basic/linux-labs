#!/bin/bash
# storage-07 grader
source /opt/linux-labs/lib/grading.sh

IMG=/srv/storage-07.img
STATE_FILE=/opt/linux-labs/state/storage-07
PASS_COPY=/opt/linux-labs/state/storage-07.orig/passphrase
NAME=securedata
MAP=/dev/mapper/$NAME
MNT=/mnt/secure
KEYDIR=/etc/luks-keys
KEY=$KEYDIR/secret.key

grade_begin storage-07
grade_require_state storage-07 "$STATE_FILE"

# The loop device of the image right now (the student may have attached
# it again under another name), else the one from the state file
loop=$(losetup -j "$IMG" -O NAME -n 2>/dev/null | head -n 1)
[ -n "$loop" ] || loop=$(head -n 1 "$STATE_FILE")
n=${loop#/dev/}

image_attached() {
	[ -e "$IMG" ] && losetup -j "$IMG" -O NAME -n 2>/dev/null | grep -q .
}

# The key slot that unlocks the LUKS header with the given key source
# (empty when nothing unlocks it). The message is the same in
# cryptsetup 2.3 (EL8) and 2.6 or later (EL9).
slot_of() {
	LC_ALL=C cryptsetup open -v --test-passphrase "$@" "$loop" 2>&1 |
		sed -n 's/^Key slot \([0-9][0-9]*\) unlocked.*/\1/p' | head -n 1
}

is_luks2() {
	image_attached || return 1
	command -v cryptsetup >/dev/null 2>&1 || return 1
	cryptsetup isLuks --type luks2 "$loop"
}

key_slot=""
pass_slot=""
if is_luks2; then
	[ -f "$KEY" ] && key_slot=$(slot_of --key-file "$KEY" < /dev/null)
	if [ -r "$PASS_COPY" ]; then
		pass_slot=$(head -n 1 "$PASS_COPY" | tr -d '\n' |
			slot_of --key-file -)
	fi
fi

# The key file unlocks a key slot other than the one of the passphrase
key_file_opens() {
	[ -n "$key_slot" ] && [ "$key_slot" != "$pass_slot" ]
}

passphrase_opens() {
	[ -n "$pass_slot" ]
}

owner_mode() {
	[ -e "$1" ] && [ ! -L "$1" ] &&
		[ "$(stat -c '%U %a' "$1" 2>/dev/null)" = "root $2" ]
}

# securedata is an open LUKS2 mapping on the loop device of the lab
mapping_ok() {
	local dm
	image_attached || return 1
	[ -b "$MAP" ] || return 1
	dm=$(readlink -f "$MAP")
	dm=${dm#/dev/}
	[ -e "/sys/block/$dm/slaves/$n" ] || return 1
	grep -q '^CRYPT-LUKS2-' "/sys/block/$dm/dm/uuid" 2>/dev/null
}

xfs_secure() {
	mapping_ok || return 1
	[ "$(blkid -p -o value -s TYPE "$MAP" 2>/dev/null)" = xfs ] &&
		[ "$(blkid -p -o value -s LABEL "$MAP" 2>/dev/null)" = SECURE ]
}

mounted_from_map() {
	local src
	mapping_ok || return 1
	src=$(findmnt -rn -M "$MNT" -o SOURCE 2>/dev/null | tail -n 1)
	[ -n "$src" ] && [ "$(readlink -f "$src")" = "$(readlink -f "$MAP")" ]
}

# An active crypttab line: securedata, UUID=<uuid of the LUKS header>
# (quotes allowed, any case), the key file and the option nofail
crypttab_ok() {
	local uuid
	image_attached || return 1
	uuid=$(blkid -p -o value -s UUID "$loop" 2>/dev/null)
	[ -n "$uuid" ] && [ -f /etc/crypttab ] || return 1
	awk -v u="$uuid" -v name="$NAME" -v key="$KEY" '
		/^[[:space:]]*#/ { next }
		$1 == name {
			src = $2
			gsub(/"/, "", src)
			if (toupper(src) != toupper("UUID=" u) || $3 != key) next
			k = split($4, o, ",")
			for (i = 1; i <= k; i++) if (o[i] == "nofail") found = 1
		}
		END { exit !found }' /etc/crypttab
}

# An active fstab line: /dev/mapper/securedata or UUID=<uuid of the
# XFS>, /mnt/secure, xfs and the option nofail
fstab_ok() {
	local uuid
	mapping_ok || return 1
	uuid=$(blkid -p -o value -s UUID "$MAP" 2>/dev/null)
	[ -n "$uuid" ] || return 1
	awk -v u="$uuid" -v map="$MAP" -v mnt="$MNT" '
		/^[[:space:]]*#/ { next }
		{
			src = $1
			gsub(/"/, "", src)
			if (src != map && toupper(src) != toupper("UUID=" u)) next
			if ($2 != mnt || $3 != "xfs") next
			k = split($4, o, ",")
			for (i = 1; i <= k; i++) if (o[i] == "nofail") found = 1
		}
		END { exit !found }' /etc/fstab
}

# The crypttab generator turns the line into a unit after a reload
unit_generated() {
	local unit
	unit=$(systemd-escape --template=systemd-cryptsetup@.service "$NAME")
	systemctl daemon-reload || return 1
	[ "$(systemctl show -p LoadState --value "$unit")" = loaded ] &&
		[ "$(systemctl show -p SourcePath --value "$unit")" = /etc/crypttab ]
}

criterion "$IMG is attached to a loop device" image_attached
criterion "The loop device holds a LUKS2 header" is_luks2
criterion "The passphrase from setup unlocks the LUKS volume" passphrase_opens
criterion "The key file unlocks a second key slot" key_file_opens
criterion "$KEY is owned by root with mode 0400" owner_mode "$KEY" 400
criterion "$KEYDIR is owned by root with mode 0700" owner_mode "$KEYDIR" 700
criterion "$MAP is open on the loop device" mapping_ok
criterion "$MAP holds XFS with the label SECURE" xfs_secure
criterion "$MAP is mounted on $MNT" mounted_from_map
criterion "crypttab opens $NAME by UUID with the key file, nofail" crypttab_ok
criterion "fstab mounts $NAME on $MNT as xfs, nofail" fstab_ok
criterion "/etc/fstab verifies without errors" findmnt --verify
criterion "systemd has a unit for $NAME from /etc/crypttab" unit_generated
grade_end
