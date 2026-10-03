#!/bin/bash
# podman-03 cleanup: remove the pod apppod, the containers db and web,
# ~/dbdata and ~/podlab of the task user. When the user had no
# container storage before the lab, reset the whole storage and remove
# the configuration Podman created; otherwise remove only the lab's
# objects and the images the user did not have. Remove containers and
# container storage that root created during the lab. Then disable
# linger when it was off at the first start and restore the package set
# (pkg_restore). When the package set cannot be restored, the records
# stay for the next reset and the exit status is 1.
source /opt/linux-labs/lib/packages.sh

LAB=podman-03
STATE_FILE=/opt/linux-labs/state/$LAB
DB_IMAGE=quay.io/sclorg/mariadb-1011-c9s
WEB_IMAGE=registry.access.redhat.com/ubi9/php-81

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
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
	# Pod, containers and images
	if [ -r "$STATE_FILE" ] && [ "$(state_value storage_before)" = no ]; then
		if command -v podman >/dev/null 2>&1; then
			as_user podman pod rm -f -t 0 apppod || true
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
		as_user podman pod rm -f -t 0 apppod || true
		as_user podman rm -f -t 0 db web || true
		if [ "$(state_value db_image_before)" = no ]; then
			as_user podman rmi "$DB_IMAGE" || true
		fi
		if [ "$(state_value web_image_before)" = no ]; then
			as_user podman rmi "$WEB_IMAGE" || true
		fi
	fi

	# The database files belong to subordinate IDs of the user; root
	# removes them
	rm -rf "$home/dbdata" "$home/podlab"

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

# Containers of root: all of root's storage when root had none at the
# first start, else only the lab's names
if [ -e /var/lib/containers/storage ] && command -v podman >/dev/null 2>&1; then
	if [ -r "$STATE_FILE" ] && [ "$(state_value root_storage_before)" = no ]; then
		podman pod rm -a -f -t 0 </dev/null >/dev/null 2>&1 || true
		podman rm -a -f -t 0 </dev/null >/dev/null 2>&1 || true
		podman system reset --force </dev/null >/dev/null 2>&1 || true
		rm -rf /var/lib/containers/storage /run/containers/storage \
			/run/containers/networks /run/libpod
		rmdir /run/containers 2>/dev/null || true
	else
		podman pod rm -f -t 0 apppod </dev/null >/dev/null 2>&1 || true
		podman rm -f -t 0 db web </dev/null >/dev/null 2>&1 || true
	fi
fi

rc=0
pkg_restore "$LAB" || rc=1

# Root's Podman leaves /var/lib/containers behind when the package that
# owns it is gone
if [ -r "$STATE_FILE" ] && [ "$(state_value root_storage_before)" = no ] &&
	[ -d /var/lib/containers ] && ! rpm -qf /var/lib/containers >/dev/null 2>&1; then
	rmdir /var/lib/containers 2>/dev/null || true
fi

if [ "$rc" -eq 0 ]; then
	rm -f "$STATE_FILE"
fi
exit "$rc"
