#!/bin/bash
# podman-01 cleanup: stop and remove the user unit and the webapp
# container, remove the container storage and configuration that the
# lab created in the task user's home (or only the lab image, when the
# user had container storage before), disable linger when it was off at
# the first start, delete /srv/webapp, restore the firewall services and
# ports, then the package set (pkg_restore). When the package set cannot
# be restored, the records stay for the next reset and the exit status
# is 1.
source /opt/linux-labs/lib/packages.sh

LAB=podman-01
STATE_FILE=/opt/linux-labs/state/$LAB
CONTENT=/srv/webapp
IMAGE=registry.access.redhat.com/ubi9/httpd-24
UNIT=container-webapp.service

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# fw_restore <kind> <recorded list>: kind is service or port
fw_restore() {
	local kind=$1 want=$2 have x
	have=$(firewall-cmd --permanent "--list-${kind}s" 2>/dev/null)
	for x in $have; do
		case " $want " in
		*" $x "*) ;;
		*)
			firewall-cmd --permanent "--remove-$kind=$x" >/dev/null 2>&1 || true
			firewall-cmd "--remove-$kind=$x" >/dev/null 2>&1 || true
			;;
		esac
	done
	for x in $want; do
		case " $have " in
		*" $x "*) ;;
		*)
			firewall-cmd --permanent "--add-$kind=$x" >/dev/null 2>&1 || true
			firewall-cmd "--add-$kind=$x" >/dev/null 2>&1 || true
			;;
		esac
	done
}

user=$(state_value user)
[ -n "$user" ] || user="${LAB_USER:-}"
uid=
home=
if [ -n "$user" ] && id "$user" >/dev/null 2>&1 && [ "$(id -u "$user")" -ge 1000 ]; then
	uid=$(id -u "$user")
	home=$(getent passwd "$user" | cut -d: -f6)
fi

as_user() {
	local rt="/run/user/$uid"
	if [ -d "$rt" ]; then
		runuser -u "$user" -- env HOME="$home" XDG_RUNTIME_DIR="$rt" \
			DBUS_SESSION_BUS_ADDRESS="unix:path=$rt/bus" "$@" </dev/null >/dev/null 2>&1
	else
		runuser -u "$user" -- env HOME="$home" "$@" </dev/null >/dev/null 2>&1
	fi
}

if [ -n "$uid" ] && [ -n "$home" ] && [ -d "$home" ]; then
	# The unit, in a unit file or a quadlet file of that name
	if [ -S "/run/user/$uid/bus" ]; then
		as_user systemctl --user disable --now "$UNIT" || true
	fi
	rm -f "$home/.config/systemd/user/$UNIT" \
		"$home/.config/systemd/user/default.target.wants/$UNIT" \
		"$home/.config/systemd/user/multi-user.target.wants/$UNIT" \
		"$home/.config/containers/systemd/container-webapp.container"
	# Unit directories the solution created, when they are empty now
	rmdir "$home/.config/systemd/user/default.target.wants" \
		"$home/.config/systemd/user" "$home/.config/systemd" 2>/dev/null || true
	if [ -S "/run/user/$uid/bus" ]; then
		as_user systemctl --user daemon-reload || true
		as_user systemctl --user reset-failed "$UNIT" || true
	fi

	# Containers and images
	if [ -r "$STATE_FILE" ] && [ "$(state_value storage_before)" = no ]; then
		if command -v podman >/dev/null 2>&1; then
			as_user podman system reset --force || true
		fi
		# Podman's pause process and leftover container processes
		pkill -u "$uid" -x conmon >/dev/null 2>&1 || true
		pkill -u "$uid" -f '^catatonit -P' >/dev/null 2>&1 || true
		rm -rf "$home/.local/share/containers" "$home/.cache/containers" \
			"/run/user/$uid/containers" "/run/user/$uid/libpod" \
			"/tmp/podman-run-$uid" "/tmp/containers-user-$uid" \
			"/tmp/storage-run-$uid"
		if [ "$(state_value config_before)" = no ]; then
			rm -rf "$home/.config/containers"
		fi
	elif command -v podman >/dev/null 2>&1; then
		as_user podman rm -f -t 0 webapp || true
		if [ "$(state_value image_before)" = no ]; then
			as_user podman rmi "$IMAGE" || true
		fi
	fi

	# Directories Podman created in the home: the rootless CNI
	# configuration, and the parents when they are empty now
	if [ -r "$STATE_FILE" ]; then
		before=" $(state_value home_dirs_before) "
		case "$before" in
		*" .config/cni "*) ;;
		*) rm -rf "$home/.config/cni" ;;
		esac
		for d in .local/share .local .cache .config; do
			case "$before" in
			*" $d "*) ;;
			*) rmdir "$home/$d" 2>/dev/null || true ;;
			esac
		done
	fi

	if [ -r "$STATE_FILE" ] && [ "$(state_value linger_before)" = no ]; then
		loginctl disable-linger "$user" >/dev/null 2>&1 || true
	fi
fi

rm -rf "$CONTENT"

if [ -r "$STATE_FILE" ] && command -v firewall-cmd >/dev/null 2>&1 &&
	systemctl is-active --quiet firewalld 2>/dev/null; then
	fw_restore service "$(state_value fw_services)"
	fw_restore port "$(state_value fw_ports)"
fi

rc=0
pkg_restore "$LAB" || rc=1

if [ "$rc" -eq 0 ]; then
	rm -f "$STATE_FILE"
fi
exit "$rc"
