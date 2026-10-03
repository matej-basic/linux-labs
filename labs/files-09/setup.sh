#!/bin/bash
# files-09 setup: builds the tree /srv/linklab, owned by the task user,
# with files that have several hard links, a broken symbolic link and a
# symbolic link to a directory, and an empty answers directory in the
# home of the task user. Records the user, the answers directory and the
# inode numbers the grader needs. Prints nothing on success.
set -eu

LAB=files-09
ROOT=/srv/linklab
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

fail() {
	echo "Error: $*" >&2
	exit 1
}

# Task user: LAB_USER from labctl, else the first regular user
user="${LAB_USER:-student}"
if ! id "$user" &>/dev/null; then
	user=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
	[ -n "$user" ] || fail "no regular user found for the lab."
fi
home=$(getent passwd "$user" | cut -d: -f6)
[ -n "$home" ] && [ -d "$home" ] || fail "home directory of $user not found."

# Fresh tree
rm -rf "$ROOT"
mkdir -p "$ROOT"/data "$ROOT"/backup "$ROOT"/etc/cache \
	"$ROOT"/releases/v1 "$ROOT"/releases/v2 \
	"$ROOT"/archive/2023 "$ROOT"/archive/2024

printf 'Quarterly report: 42 tickets closed, 3 open.\n' > "$ROOT/data/report.txt"
printf 'Legacy data, kept for reference.\n' > "$ROOT/data/old.txt"
ln "$ROOT/data/old.txt" "$ROOT/archive/2024/old-copy.txt"

printf 'release v1\n' > "$ROOT/releases/v1/VERSION"
printf 'release v2\n' > "$ROOT/releases/v2/VERSION"
ln -s releases/v1 "$ROOT/latest"

printf 'listen=8080\nlog_level=info\n' > "$ROOT/etc/app.conf"
ln -s /srv/linklab/config/app.conf "$ROOT/app.conf"

# shared.dat has three names. A copy with the same content and a
# symbolic link to it are decoys: neither is a name of its inode.
printf 'shared dataset, block 0001\n' > "$ROOT/data/shared.dat"
ln "$ROOT/data/shared.dat" "$ROOT/archive/2023/blob.dat"
ln "$ROOT/data/shared.dat" "$ROOT/etc/cache/store.dat"
cp "$ROOT/data/shared.dat" "$ROOT/archive/2024/shared.dat"
ln -s ../data/shared.dat "$ROOT/etc/shared.lnk"

chown -R -h "$user": "$ROOT"
find "$ROOT" -type d -exec chmod 755 {} +
find "$ROOT" -type f -exec chmod 644 {} +

# Answers directory of the task user, without an old answer
mkdir -p "$home/answers"
rm -f "$home/answers/inode-names.txt"
chown "$user": "$home/answers"
chmod 755 "$home/answers"

# State for the grader
mkdir -p "$STATE_DIR"
{
	echo "user=$user"
	echo "answers=$home/answers"
	echo "report_inode=$(stat -c %i "$ROOT/data/report.txt")"
	echo "old_inode=$(stat -c %i "$ROOT/data/old.txt")"
	echo "shared_inode=$(stat -c %i "$ROOT/data/shared.dat")"
	echo "conf_inode=$(stat -c %i "$ROOT/etc/app.conf")"
} > "$STATE_FILE"
chmod 644 "$STATE_FILE"
