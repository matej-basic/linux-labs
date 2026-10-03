#!/bin/bash
# storage-11 grader
source /opt/linux-labs/lib/grading.sh

STATE=/opt/linux-labs/state/storage-11
APP_IMG=/srv/storage-11-appdata.img
ARC_IMG=/srv/storage-11-archive.img
APP_MNT=/srv/appdata
ARC_MNT=/srv/archive

grade_begin storage-11
grade_require_state storage-11 "$STATE/appdata.sha256"

# True when the source of the mount on $1 is a loop device of image $2
mounted_from() {
	local src dev
	src=$(findmnt -rn -M "$1" -o SOURCE 2>/dev/null | tail -n 1)
	case "$src" in /dev/loop*) ;; *) return 1 ;; esac
	dev=${src#/dev/}
	[ "$(cat "/sys/block/$dev/loop/backing_file" 2>/dev/null)" = "$2" ]
}

app_mounted() {
	mounted_from "$APP_MNT" "$APP_IMG"
}

# Use% as df shows it, below 50
app_below_half() {
	local pct
	app_mounted || return 1
	pct=$(df -P "$APP_MNT" 2>/dev/null | awk 'NR == 2 { sub(/%/, "", $5); print $5 }')
	[ -n "$pct" ] && [ "$pct" -lt 50 ]
}

data_unchanged() {
	app_mounted || return 1
	(cd "$APP_MNT/data" && sha256sum -c --quiet "$STATE/appdata.sha256")
}

dump_gone() {
	local dump
	app_mounted || return 1
	dump=$(cat "$STATE/dump" 2>/dev/null)
	[ -n "$dump" ] && [ ! -e "$dump" ]
}

# No open file descriptor of any process points to a deleted file on
# /srv/appdata
no_deleted_open() {
	local fd t
	app_mounted || return 1
	for fd in /proc/[0-9]*/fd/*; do
		t=$(readlink "$fd" 2>/dev/null) || continue
		case "$t" in
			"$APP_MNT"/*" (deleted)") return 1 ;;
		esac
	done
	return 0
}

logger_active() {
	systemctl is-active --quiet app-logger.service
}

# An active fstab line names the archive image by path, mounts it on
# /srv/archive and has the option nofail
archive_fstab_ok() {
	awk -v img="$ARC_IMG" -v mnt="$ARC_MNT" '
		/^[[:space:]]*#/ { next }
		$1 == img && $2 == mnt {
			n = split($4, o, ",")
			for (i = 1; i <= n; i++) if (o[i] == "nofail") found = 1
		}
		END { exit !found }' /etc/fstab
}

archive_mounted() {
	mounted_from "$ARC_MNT" "$ARC_IMG"
}

archive_intact() {
	archive_mounted || return 1
	(cd "$ARC_MNT" && sha256sum -c --quiet "$STATE/archive.sha256")
}

# The active lines of an fstab without the /srv/archive line, fields
# separated by one space
active_lines() {
	awk -v mnt="$ARC_MNT" '
		/^[[:space:]]*#/ || NF == 0 { next }
		$2 == mnt { next }
		{ $1 = $1; print }' "$1"
}

others_unchanged() {
	[ -r "$STATE/fstab" ] || return 1
	[ "$(active_lines /etc/fstab)" = "$(active_lines "$STATE/fstab")" ]
}

criterion "$APP_MNT is mounted from $APP_IMG" app_mounted
criterion "$APP_MNT is less than 50% used" app_below_half
criterion "The files in $APP_MNT/data are unchanged" data_unchanged
criterion "The disposable files on $APP_MNT are deleted" dump_gone
criterion "No process keeps a deleted file on $APP_MNT open" no_deleted_open
criterion "app-logger.service is active" logger_active
criterion "/etc/fstab verifies without errors" findmnt --verify
criterion "fstab mounts $ARC_IMG on $ARC_MNT, nofail" archive_fstab_ok
criterion "$ARC_MNT is mounted from $ARC_IMG" archive_mounted
criterion "The files in $ARC_MNT are intact" archive_intact
criterion "The other lines of /etc/fstab are unchanged" others_unchanged
grade_end
