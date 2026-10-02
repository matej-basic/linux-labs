#!/bin/bash
# podman-01 setup: web content in /srv/webapp for the task user, no lab
# container, no lab unit. Prints nothing on success.
#
# The first run records the package set (pkg_snapshot) and, in the state
# file, what cleanup.sh must put back: whether the task user had linger
# enabled, container storage and container configuration in the home
# directory, the lab image, and the firewall services and ports. A
# restarted lab keeps the records of its first start.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=podman-01
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
CONTENT=/srv/webapp
IMAGE=registry.access.redhat.com/ubi9/httpd-24
UNIT=container-webapp.service

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
	image=no
	if [ "$storage" = yes ] && command -v podman >/dev/null 2>&1 &&
		as_user podman image exists "$IMAGE" </dev/null >/dev/null 2>&1; then
		image=yes
	fi
	fw_services=
	fw_ports=
	if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
		fw_services=$(firewall-cmd --permanent --list-services 2>/dev/null || true)
		fw_ports=$(firewall-cmd --permanent --list-ports 2>/dev/null || true)
	fi
	token="podman-01 $(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
	mkdir -p "$STATE_DIR"
	{
		echo "user=$user"
		echo "token=$token"
		echo "linger_before=$linger"
		echo "storage_before=$storage"
		echo "config_before=$config"
		echo "image_before=$image"
		echo "home_dirs_before=$home_dirs"
		echo "fw_services=$fw_services"
		echo "fw_ports=$fw_ports"
	} >"$STATE_FILE"
	chmod 644 "$STATE_FILE"
fi
token=$(state_value token)

# Remove what an earlier attempt left: the lab unit, the container and
# linger when the user did not have it at the first start
if [ -S "/run/user/$uid/bus" ]; then
	as_user systemctl --user disable --now "$UNIT" </dev/null >/dev/null 2>&1 || true
fi
rm -f "$home/.config/systemd/user/$UNIT" \
	"$home/.config/systemd/user/default.target.wants/$UNIT" \
	"$home/.config/systemd/user/multi-user.target.wants/$UNIT" \
	"$home/.config/containers/systemd/container-webapp.container"
if [ -S "/run/user/$uid/bus" ]; then
	as_user systemctl --user daemon-reload </dev/null >/dev/null 2>&1 || true
	as_user systemctl --user reset-failed "$UNIT" </dev/null >/dev/null 2>&1 || true
fi
if command -v podman >/dev/null 2>&1 && [ -e "$home/.local/share/containers" ]; then
	as_user podman rm -f -t 0 webapp </dev/null >/dev/null 2>&1 || true
fi
if [ "$(state_value linger_before)" = no ] && [ -e "/var/lib/systemd/linger/$user" ]; then
	loginctl disable-linger "$user" >/dev/null 2>&1 || true
fi

# The web content, owned by the task user, with its default SELinux label
rm -rf "$CONTENT"
mkdir -p "$CONTENT"
printf '%s\n' "$token" >"$CONTENT/index.html"
chown -R "$user:" "$CONTENT"
chmod 755 "$CONTENT"
chmod 644 "$CONTENT/index.html"
restorecon -R "$CONTENT" >/dev/null 2>&1 || true

# A stopped container releases the port within a few seconds
for _ in 1 2 3 4 5 6 7 8 9 10; do
	[ -z "$(ss -H -tln 'sport = :8080' 2>/dev/null)" ] && break
	sleep 1
done
if [ -n "$(ss -H -tln 'sport = :8080' 2>/dev/null)" ]; then
	echo "Error: another service already listens on TCP port 8080." >&2
	exit 1
fi
