#!/bin/bash
# files-05 setup: creates the lab users analyst, builder and tester, a
# fixed data tree under /srv/search (owners, sizes, modification times,
# special permissions, symbolic links, unreadable directories and a log
# file) and an empty answers directory in the home of the task user.
# Prints nothing on success.
set -eu

LAB=files-05
ROOT=/srv/search
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
MARK="linux-labs $LAB"
LAB_USERS="analyst builder tester"
ANSWERS="large-files.txt old-files.txt setuid.txt link-count.txt
errors.txt report-files.txt denied.txt"

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

# Lab users: remove the ones a previous run left behind, refuse to touch
# accounts the lab did not create
for u in $LAB_USERS; do
	if getent passwd "$u" >/dev/null; then
		[ "$(getent passwd "$u" | cut -d: -f5)" = "$MARK" ] ||
			fail "user $u already exists and was not created by this lab."
		userdel -r -f "$u" >/dev/null 2>&1 || true
	fi
	getent group "$u" >/dev/null && groupdel "$u" >/dev/null 2>&1 || true
done
for u in $LAB_USERS; do
	useradd -c "$MARK" "$u" || fail "cannot create user $u."
done

# Fresh tree
rm -rf "$ROOT"
mkdir -p "$ROOT"

# mkd <path> <owner> <mode>
mkd() {
	mkdir -p "$ROOT/$1"
	chown "$2": "$ROOT/$1"
	chmod "$3" "$ROOT/$1"
}

# mkf <path> <owner> <mode> <size in bytes> <age> [<content>]
# Size 0 with content writes the content, otherwise a file of that size.
# Ownership before mode, because chown clears the SUID and SGID bits.
mkf() {
	local f="$ROOT/$1"
	if [ "$4" -eq 0 ]; then
		printf '%s\n' "${6:-}" > "$f"
	else
		truncate -s "$4" "$f"
	fi
	chown "$2": "$f"
	chmod "$3" "$f"
	touch -d "$5" "$f"
}

KIB=1024
MIB=1048576

mkd projects root 755
mkd projects/alpha builder 755
mkd projects/beta analyst 755
mkd projects/beta/docs analyst 755
mkd projects/beta/tools root 755
mkd projects/gamma tester 755
mkd projects/gamma/keys analyst 700
mkd logs root 755
mkd shared root 1777
mkd private root 700

mkf projects/alpha/build.tar builder 644 $((3 * MIB)) "5 days ago"
mkf projects/alpha/cache.bin builder 644 $((900 * KIB)) "2 days ago"
mkf projects/alpha/notes.txt builder 644 0 "90 days ago" "Build notes for alpha."
mkf projects/alpha/report.txt analyst 644 0 "3 days ago" "Alpha status report."
mkf projects/alpha/run.sh builder 4755 0 "10 days ago" "#!/bin/sh"
ln -s build.tar "$ROOT/projects/alpha/latest"

mkf projects/beta/data.csv analyst 644 $((5 * MIB)) "45 days ago"
mkf projects/beta/image.iso builder 644 $((2 * MIB)) "400 days ago"
mkf projects/beta/exact.img builder 644 "$MIB" "12 days ago"
mkf projects/beta/docs/report.txt analyst 644 0 "60 days ago" "Beta status report."
mkf projects/beta/docs/manual.txt tester 644 0 "7 days ago" "Beta manual."
ln -s manual.txt "$ROOT/projects/beta/docs/current"
mkf projects/beta/tools/helper root 4755 0 "200 days ago" "#!/bin/sh"
mkf projects/beta/tools/sync root 2755 0 "8 days ago" "#!/bin/sh"

mkf projects/gamma/dump.sql builder 644 $((1536 * KIB)) "14 days ago"
mkf projects/gamma/config.ini tester 666 0 "9 days ago" "[gamma]"
mkf projects/gamma/keys/id.key analyst 600 0 "1 day ago" "key"
mkf projects/gamma/keys/report.txt analyst 644 0 "1 day ago" "Key report."
ln -s missing.txt "$ROOT/projects/gamma/broken"

mkf shared/report.txt tester 644 0 "4 days ago" "Shared report."
mkf shared/upload.bin builder 644 $((1100 * KIB)) "1 day ago"
ln -s /srv/search/logs/app.log "$ROOT/shared/app.lnk"

mkf private/report.txt root 600 0 "6 days ago" "Private report."
mkf private/secret.bin root 600 $((64 * KIB)) "6 days ago"

cat > "$ROOT/logs/app.log" <<'LOG'
INFO [web] service started on port 8080
ERROR [storage] disk /dev/sdb1 is full
WARN [storage] disk usage above 90 percent
ERROR [web] upstream timeout after 30 seconds
error [storage] disk check skipped
ERROR [storage] disks rescanned, 2 found
INFO [storage] ERROR counter reset for disk /dev/sdc1
ERROR [backup] cannot write to disk /dev/sdc1
 ERROR [storage] disk quota exceeded for user analyst
ERROR [storage] diskless node detected
ERROR [db] Disk latency high on /dev/sda
DEBUG [storage] polling disk /dev/sdb1
ERROR [storage] read error on disk /dev/sdb2, retrying
INFO [backup] job finished
ERROR [auth] login failed for user tester
WARN [web] slow response from disk cache
LOG
chown tester: "$ROOT/logs/app.log"
chmod 644 "$ROOT/logs/app.log"
touch -d "1 day ago" "$ROOT/logs/app.log"

# Answers directory of the task user, without old answers
mkdir -p "$home/answers"
for a in $ANSWERS; do
	rm -f "$home/answers/$a"
done
chown "$user": "$home/answers"
chmod 755 "$home/answers"

# State for the grader: the task user and the answers directory
mkdir -p "$STATE_DIR"
printf '%s\n%s\n' "$user" "$home/answers" > "$STATE_FILE"
chmod 644 "$STATE_FILE"
