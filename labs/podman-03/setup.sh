#!/bin/bash
# podman-03 setup: enable linger for the task user, write the page
# ~/podlab/index.php, and remove the pod apppod, the containers db and
# web and the directory ~/dbdata of an earlier attempt. Prints nothing
# on success.
#
# The first run records the package set (pkg_snapshot) and, in the state
# file, what cleanup.sh must put back: whether the task user had linger
# enabled, container storage and container configuration in the home
# directory, the two lab images, the directories Podman creates in a new
# home, and whether root had container storage. A restarted lab keeps
# the records of its first start.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=podman-03
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
DB_IMAGE=quay.io/sclorg/mariadb-1011-c9s
WEB_IMAGE=registry.access.redhat.com/ubi9/php-81
PORT=8082

pkg_snapshot "$LAB"

# Task user: LAB_USER from labctl, else the first regular user
user="${LAB_USER:-student}"
if ! id "$user" >/dev/null 2>&1; then
	user=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
fi
if [ -z "$user" ] || [ "$(id -u "$user" 2>/dev/null || echo 0)" -lt 1000 ]; then
	echo "Error: no regular user for the lab on this machine." >&2
	exit 1
fi
uid=$(id -u "$user")
home=$(getent passwd "$user" | cut -d: -f6)
if [ -z "$home" ] || [ ! -d "$home" ]; then
	echo "Error: the home directory of $user does not exist." >&2
	exit 1
fi
if ! grep -q "^$user:" /etc/subuid 2>/dev/null || ! grep -q "^$user:" /etc/subgid 2>/dev/null; then
	echo "Error: $user has no subordinate ID range in /etc/subuid and /etc/subgid." >&2
	echo "Rootless containers need one." >&2
	exit 1
fi

# as_user <command...>: run a command as the task user with the user's
# runtime directory and session bus, when the user manager runs
as_user() {
	local rt="/run/user/$uid"
	if [ -d "$rt" ]; then
		runuser -u "$user" -- env HOME="$home" XDG_RUNTIME_DIR="$rt" \
			DBUS_SESSION_BUS_ADDRESS="unix:path=$rt/bus" "$@"
	else
		runuser -u "$user" -- env HOME="$home" "$@"
	fi
}

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

if [ ! -r "$STATE_FILE" ]; then
	linger=no
	[ -e "/var/lib/systemd/linger/$user" ] && linger=yes
	storage=no
	[ -e "$home/.local/share/containers" ] && storage=yes
	config=no
	[ -e "$home/.config/containers" ] && config=yes
	# Directories Podman creates in a new home, for cleanup.sh
	home_dirs=
	for d in .config .config/cni .local .local/share .cache; do
		if [ -e "$home/$d" ]; then
			home_dirs="$home_dirs $d"
		fi
	done
	db_image=no
	web_image=no
	if [ "$storage" = yes ] && command -v podman >/dev/null 2>&1; then
		if as_user podman image exists "$DB_IMAGE" </dev/null >/dev/null 2>&1; then
			db_image=yes
		fi
		if as_user podman image exists "$WEB_IMAGE" </dev/null >/dev/null 2>&1; then
			web_image=yes
		fi
	fi
	root_storage=no
	[ -e /var/lib/containers/storage ] && root_storage=yes
	token="podman-03 $(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
	mkdir -p "$STATE_DIR"
	{
		echo "user=$user"
		echo "token=$token"
		echo "linger_before=$linger"
		echo "storage_before=$storage"
		echo "config_before=$config"
		echo "db_image_before=$db_image"
		echo "web_image_before=$web_image"
		echo "home_dirs_before=$home_dirs"
		echo "root_storage_before=$root_storage"
	} >"$STATE_FILE"
	chmod 644 "$STATE_FILE"
fi
token=$(state_value token)

# Linger keeps the user manager and /run/user/<uid> after logout, so
# the rootless containers and their Podman state survive the session
loginctl enable-linger "$user"
for _ in $(seq 1 30); do
	[ -S "/run/user/$uid/bus" ] && break
	sleep 1
done
if [ ! -S "/run/user/$uid/bus" ]; then
	echo "Error: the user manager of $user did not start." >&2
	exit 1
fi

# What an earlier attempt left: the pod and the containers of the task
# user and of root
if command -v podman >/dev/null 2>&1; then
	if [ -e "$home/.local/share/containers" ]; then
		as_user podman pod rm -f -t 0 apppod </dev/null >/dev/null 2>&1 || true
		as_user podman rm -f -t 0 db web </dev/null >/dev/null 2>&1 || true
	fi
	if [ -e /var/lib/containers/storage ]; then
		podman pod rm -f -t 0 apppod </dev/null >/dev/null 2>&1 || true
		podman rm -f -t 0 db web </dev/null >/dev/null 2>&1 || true
	fi
fi

# The database files belong to subordinate IDs of the user; root
# removes them
rm -rf "$home/dbdata"

# The page, owned by the task user
rm -rf "$home/podlab"
mkdir -p "$home/podlab"
cat >"$home/podlab/index.php" <<'END'
<?php
// Written by labctl start for podman-03. Do not change this file.
header('Content-Type: text/plain');
mysqli_report(MYSQLI_REPORT_OFF);
echo "@TOKEN@\n";
$db = @new mysqli('127.0.0.1', 'app', 'Inv3ntory', 'inventory', 3306);
if ($db->connect_errno) {
    echo "ERROR: cannot connect to the database inventory\n";
    exit;
}
$res = $db->query('SELECT id, name FROM items ORDER BY id');
if (!$res) {
    echo "ERROR: cannot read the table items\n";
    exit;
}
while ($row = $res->fetch_row()) {
    echo $row[0], ' ', $row[1], "\n";
}
END
sed -i "s/@TOKEN@/$token/" "$home/podlab/index.php"
chown -R "$user:" "$home/podlab"
chmod 755 "$home/podlab"
chmod 644 "$home/podlab/index.php"
restorecon -R "$home/podlab" >/dev/null 2>&1 || true

# A removed pod releases the port within a few seconds
for _ in 1 2 3 4 5 6 7 8 9 10; do
	[ -z "$(ss -H -tln "sport = :$PORT" 2>/dev/null)" ] && break
	sleep 1
done
if [ -n "$(ss -H -tln "sport = :$PORT" 2>/dev/null)" ]; then
	echo "Error: another service already listens on TCP port $PORT." >&2
	exit 1
fi
