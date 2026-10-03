#!/bin/bash
# files-06 setup: builds the data tree /srv/projects on node 1 (owners
# projdev, projqa and root, group projteam, mixed modes, fixed times,
# three .tmp files), creates the lab users and group on both nodes with
# the same IDs, an empty /srv/restore on node 1 and an empty /srv/backup
# on node 2. The task user on node 1 gets the key ~/.ssh/id_ed25519 (an
# existing key there is used as it is), and its public key is added to
# the task user's authorized_keys on node 2 with the comment
# files-06-lab. The existing key logins stay as they are.
#
# The first run records each node's package set (lib/packages.sh) and in
# /var/tmp/files-06.pre on the node what existed before, so that
# cleanup.sh removes exactly what the lab added. The expected listing of
# the tree goes to the state file on the workstation for the grader.
# Prints nothing on success.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=files-06
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

if [ "$NODES_ENABLED" != "true" ]; then
	echo "$LAB needs multi-node labs: run 'sudo labctl configure interactive' and enable them" >&2
	exit 1
fi
if [ "$NODE_COUNT" -lt 2 ] 2>/dev/null; then
	echo "$LAB needs 2 nodes, NODE_COUNT is $NODE_COUNT: run 'sudo labctl configure set NODE_COUNT 2'" >&2
	exit 1
fi

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)
for n in 1 2; do
	ip=$(get_node_ip "$n")
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Cannot reach node $n ($ip) over SSH as $SSH_USER" >&2
		exit 1
	fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# manifest <dir>: one line per entry of the tree, sorted by path:
# <path> <type> <mode> <owner> <group> <mtime> <sha256>, where mtime and
# sha256 are "-" for anything but a regular file
manifest() (
	cd "$1" 2>/dev/null || exit 1
	find . | LC_ALL=C sort | while read -r p; do
		if [ -L "$p" ]; then t=l
		elif [ -d "$p" ]; then t=d
		elif [ -f "$p" ]; then t=f
		else t=o
		fi
		m=- s=-
		if [ "$t" = f ]; then
			m=$(stat -c %Y "$p")
			s=$(sha256sum < "$p" | cut -c 1-64)
		fi
		printf '%s %s %s %s %s\n' "$p" "$t" "$(stat -c '%a %U %G' "$p")" "$m" "$s"
	done
)

# Lab users and group with fixed IDs, the same on both nodes
cat > "$tmp/accounts.sh" <<'REMOTE'
accounts() {
	local g u name id cur
	g=$(getent group projteam | cut -d: -f3)
	if [ -z "$g" ]; then
		if getent group 3600 >/dev/null; then
			echo "GID 3600 is used by another group" >&2
			return 1
		fi
		groupadd -g 3600 projteam || return 1
	elif [ "$g" != 3600 ]; then
		echo "group projteam exists with GID $g, the lab needs GID 3600" >&2
		return 1
	fi
	for u in projdev:3601 projqa:3602; do
		name=${u%%:*}
		id=${u#*:}
		cur=$(getent passwd "$name" | cut -d: -f3)
		if [ -z "$cur" ]; then
			if getent passwd "$id" >/dev/null; then
				echo "UID $id is used by another user" >&2
				return 1
			fi
			useradd -u "$id" -g projteam -M -s /sbin/nologin \
				-c "files-06 lab user" "$name" || return 1
		elif [ "$cur" != "$id" ]; then
			echo "user $name exists with UID $cur, the lab needs UID $id" >&2
			return 1
		fi
	done
}
REMOTE

# Node 1: records, accounts, data tree, key. Prints "KEY <public key>"
# and then the manifest of the tree, each line prefixed with "M ".
cat > "$tmp/node1.sh" <<'REMOTE'
pre=/var/tmp/files-06.pre
home=$(getent passwd "$LABU" | cut -d: -f6)
if [ -z "$home" ] || [ ! -d "$home" ]; then
	echo "user $LABU has no home directory" >&2
	exit 1
fi
key="$home/.ssh/id_ed25519"
khu="$home/.ssh/known_hosts"
khr=/root/.ssh/known_hosts

has_host() {
	[ -f "$1" ] && ssh-keygen -F "$N2" -f "$1" >/dev/null 2>&1
}

# First run only: what existed before the lab
if [ ! -d "$pre" ]; then
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp" || exit 1
	{
		getent group projteam >/dev/null && echo acct-existed
		[ -e /srv/restore ] && echo restore-existed
		[ -e "$key" ] && echo key-existed
		[ -e "$home/.ssh" ] && echo sshdir-existed
		[ -e "$khu" ] && echo khu-existed
		[ -e "$khu.old" ] && echo khu-old-existed
		has_host "$khu" && echo khu-host
		[ -e "$khr" ] && echo khr-existed
		[ -e "$khr.old" ] && echo khr-old-existed
		has_host "$khr" && echo khr-host
	} > "$pre.tmp/flags"
	mv "$pre.tmp" "$pre" || exit 1
fi

had() {
	grep -qx "$1" "$pre/flags"
}

# Host keys of node 2 learned since the first start go, so a restarted
# lab begins as the first start did
if ! had khu-host && [ -f "$khu" ]; then
	runuser -u "$LABU" -- ssh-keygen -R "$N2" -f "$khu" </dev/null >/dev/null 2>&1
	had khu-old-existed || rm -f "$khu.old"
fi
if ! had khr-host && [ -f "$khr" ]; then
	ssh-keygen -R "$N2" -f "$khr" </dev/null >/dev/null 2>&1
	had khr-old-existed || rm -f "$khr.old"
fi

# Lab paths from an earlier run or a solution
rm -rf /srv/projects /srv/projects.tar.xz
if had restore-existed; then
	rm -rf /srv/restore/projects
else
	rm -rf /srv/restore
fi
mkdir -p /srv/restore || exit 1
if ! had restore-existed; then
	chown root:root /srv/restore && chmod 0755 /srv/restore || exit 1
fi

accounts || exit 1

# d <mode> <owner:group> <path>: a directory
d() {
	mkdir "$3" && chown "$2" "$3" && chmod "$1" "$3"
}
# f <mode> <owner:group> <mtime> <path> <content>: a regular file
f() {
	printf '%b' "$5" > "$4" && chown "$2" "$4" && chmod "$1" "$4" &&
		touch -d "$3" "$4"
}

set -e
umask 022
P=/srv/projects
d 0755 root:root $P
d 2775 projdev:projteam $P/alpha
d 2775 projdev:projteam $P/alpha/src
d 0750 projqa:projteam $P/beta
d 1770 root:projteam $P/shared
f 0644 root:root "2025-01-06 08:15:00" $P/README.txt \
	"Shared project data of the alpha and beta teams.\nOwners: projdev (alpha), projqa (beta).\n"
f 0664 projdev:projteam "2025-02-03 10:20:31" $P/alpha/plan.txt \
	"Milestone 1: prototype\nMilestone 2: field test\nMilestone 3: release\n"
f 0664 projdev:projteam "2025-02-10 16:45:12" $P/alpha/draft.tmp \
	"unsaved draft\n"
f 0755 projdev:projteam "2025-02-11 09:05:47" $P/alpha/src/build.sh \
	"#!/bin/bash\n# Build the alpha prototype\necho 'Building alpha'\n"
f 0644 projdev:projteam "2025-02-11 09:06:02" $P/alpha/src/build.tmp \
	"build cache\n"
f 0640 projqa:projteam "2025-03-03 13:30:00" $P/beta/results.csv \
	"test,result\nboot,pass\nnetwork,pass\nstorage,fail\n"
f 0600 projqa:projteam "2025-03-04 07:55:19" $P/beta/token.key \
	"b3f1c9a7e2d84f06\n"
f 0600 projqa:projteam "2025-03-04 08:12:44" $P/beta/cache.tmp \
	"session cache\n"
f 0444 projdev:projteam "2024-11-20 12:00:00" $P/shared/handbook.txt \
	"Team handbook, read only.\n"
f 0664 projqa:projteam "2025-03-15 18:22:05" $P/shared/schedule.txt \
	"Mon review\nWed test run\nFri release meeting\n"
for dir in $P/alpha/src $P/alpha $P/beta $P/shared $P; do
	touch -d "2025-03-15 18:30:00" "$dir"
done
restorecon -R $P /srv/restore 2>/dev/null || true
set +e

# The key of the task user on node 1
if ! had key-existed; then
	rm -f "$key" "$key.pub"
	runuser -u "$LABU" -- mkdir -p -m 0700 "$home/.ssh" || exit 1
	runuser -u "$LABU" -- ssh-keygen -q -t ed25519 -N '' -C files-06-lab \
		-f "$key" </dev/null >/dev/null || exit 1
	restorecon -R "$home/.ssh" 2>/dev/null
fi
if [ ! -f "$key.pub" ]; then
	echo "$key exists, but $key.pub is missing" >&2
	exit 1
fi

echo "KEY $(awk '{ print $1, $2; exit }' "$key.pub")"
manifest $P | sed 's/^/M /'
exit 0
REMOTE

# Node 2: records, accounts, /srv/backup, authorization of the key
cat > "$tmp/node2.sh" <<'REMOTE'
pre=/var/tmp/files-06.pre
home=$(getent passwd "$LABU" | cut -d: -f6)
if [ -z "$home" ] || [ ! -d "$home" ]; then
	echo "user $LABU has no home directory" >&2
	exit 1
fi
ak="$home/.ssh/authorized_keys"

if [ ! -d "$pre" ]; then
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp" || exit 1
	{
		getent group projteam >/dev/null && echo acct-existed
		[ -e /srv/backup ] && echo backup-existed
		[ -e "$home/.ssh" ] && echo sshdir-existed
		[ -e "$ak" ] && echo ak-existed
	} > "$pre.tmp/flags"
	mv "$pre.tmp" "$pre" || exit 1
fi

had() {
	grep -qx "$1" "$pre/flags"
}

if had backup-existed; then
	rm -rf /srv/backup/projects
else
	rm -rf /srv/backup
fi
mkdir -p /srv/backup || exit 1
if ! had backup-existed; then
	chown root:root /srv/backup && chmod 0755 /srv/backup || exit 1
	restorecon /srv/backup 2>/dev/null
fi

accounts || exit 1

# authorized_keys: drop an earlier lab line, then add the current key.
# The file is rewritten in place, so owner, mode and context stay.
if [ ! -f "$ak" ]; then
	runuser -u "$LABU" -- mkdir -p -m 0700 "$home/.ssh" || exit 1
	runuser -u "$LABU" -- touch "$ak" || exit 1
	chmod 0600 "$ak"
	restorecon -R "$home/.ssh" 2>/dev/null
fi
grep -v ' files-06-lab$' "$ak" > "$pre/ak.new"
cat "$pre/ak.new" > "$ak" || exit 1
rm -f "$pre/ak.new"
if [ -s "$ak" ] && [ -n "$(tail -c 1 "$ak")" ]; then
	echo >> "$ak"
fi
printf '%s files-06-lab\n' "$PUB" >> "$ak" || exit 1
exit 0
REMOTE

# send <node> <script> <variables>: run the script as root on the node
send() {
	{
		printf '%s\n' "$3"
		cat "$tmp/accounts.sh"
		declare -f manifest
		cat "$tmp/$2"
	} | run_on_node "$1" "sudo -n bash -s"
}

for n in 1 2; do
	ip=$(get_node_ip "$n")
	if ! pkg_snapshot_node "$ip" "$LAB" > "$tmp/out" 2>&1; then
		echo "Recording the packages of node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
done

if ! send "$N1" node1.sh "LABU='$SSH_USER'; N2='$N2'" > "$tmp/out1" 2> "$tmp/err"; then
	echo "Preparing node 1 ($N1) failed:" >&2
	grep -v "^Warning: Permanently added" "$tmp/err" >&2
	exit 1
fi
pub=$(sed -n 's/^KEY //p' "$tmp/out1")
sed -n 's/^M //p' "$tmp/out1" > "$tmp/manifest"
if [ -z "$pub" ] || [ ! -s "$tmp/manifest" ]; then
	echo "Preparing node 1 ($N1) failed: no key or no data tree" >&2
	exit 1
fi

if ! send "$N2" node2.sh "LABU='$SSH_USER'; PUB='$pub'" > /dev/null 2> "$tmp/err"; then
	echo "Preparing node 2 ($N2) failed:" >&2
	grep -v "^Warning: Permanently added" "$tmp/err" >&2
	exit 1
fi

# The expected tree for the grader
mkdir -p "$STATE_DIR"
cp "$tmp/manifest" "$STATE_FILE"
chmod 0644 "$STATE_FILE"
