#!/bin/bash
# storage-11 setup: records the package set and /etc/fstab (first start
# only) and removes what an earlier run left behind. Then it builds two
# image files that /etc/fstab mounts by path with the options loop and
# nofail:
#   /srv/storage-11-appdata.img  ext4, 200 MiB, on /srv/appdata
#   /srv/storage-11-archive.img  XFS, 320 MiB (sparse), on /srv/archive
# and breaks both:
#   - /srv/appdata is nearly full: a 70 MiB dump in .cache/core.<n> and
#     a 70 MiB log that is deleted while app-logger.service keeps it
#     open, so df and du disagree
#   - the fstab line of /srv/archive has the type ext4 while the image
#     holds XFS, so findmnt --verify reports an error, and /srv/archive
#     is not mounted
# The checksums of the data files, the name of the dump and the fstab
# after setup go to the state directory /opt/linux-labs/state/storage-11.
# Prints nothing on success.
set -eu
source /opt/linux-labs/lib/packages.sh

STATE_DIR=/opt/linux-labs/state
STATE=$STATE_DIR/storage-11
ORIG=$STATE_DIR/storage-11.orig
APP_IMG=/srv/storage-11-appdata.img
ARC_IMG=/srv/storage-11-archive.img
APP_MNT=/srv/appdata
ARC_MNT=/srv/archive
UNIT=/etc/systemd/system/app-logger.service
SCRIPT=/usr/local/bin/app-logger

fail() {
	echo "storage-11: $*" >&2
	exit 1
}

pkg_snapshot storage-11

for c in losetup findmnt mkfs.ext4 mkfs.xfs sha256sum systemctl; do
	command -v "$c" >/dev/null 2>&1 ||
		fail "the command $c is missing (util-linux, e2fsprogs and xfsprogs are required)"
done

for mnt in "$APP_MNT" "$ARC_MNT"; do
	if mountpoint -q "$mnt" 2>/dev/null; then
		src=$(findmnt -rn -M "$mnt" -o SOURCE 2>/dev/null | tail -n 1)
		case "$src" in
			/dev/loop*) ;;
			*) fail "$mnt is a mount point of something else; refusing to start" ;;
		esac
	fi
done

# Remove what an earlier run or its solution left behind
bash "$(dirname "$0")/cleanup.sh" --leftovers

for mnt in "$APP_MNT" "$ARC_MNT"; do
	mountpoint -q "$mnt" 2>/dev/null &&
		fail "$mnt is still mounted from something else; refusing to start"
done

# /etc/fstab as it was at the first start, so that a restart keeps the
# original
if [ ! -f "$ORIG/fstab" ]; then
	rm -rf "$ORIG"
	mkdir -p "$ORIG"
	chmod 700 "$ORIG"
	cp -p /etc/fstab "$ORIG/fstab"
fi

modprobe loop >/dev/null 2>&1 || true
[ -e /dev/loop-control ] || fail "loop devices are not available on this system"

rm -rf "$STATE"
mkdir -p "$STATE"
chmod 755 "$STATE"
mkdir -p /srv "$APP_MNT" "$ARC_MNT"

# The archive: XFS with a few files, written through a temporary mount
truncate -s 320M "$ARC_IMG"
chmod 600 "$ARC_IMG"
mkfs.xfs -q -f -L ARCHIVE "$ARC_IMG" >/dev/null 2>&1 ||
	fail "cannot create the XFS file system in $ARC_IMG"
mount -o loop "$ARC_IMG" "$ARC_MNT" || fail "cannot mount $ARC_IMG"
mkdir -p "$ARC_MNT/2025" "$ARC_MNT/2026"
for q in 1 2 3 4; do
	printf 'Quarterly report 2025 Q%s\nOrders: %s\nReturns: %s\n' \
		"$q" "$((1200 + q * 37))" "$((40 + q))" > "$ARC_MNT/2025/report-q$q.txt"
done
for q in 1 2 3; do
	printf 'Quarterly report 2026 Q%s\nOrders: %s\nReturns: %s\n' \
		"$q" "$((1500 + q * 41))" "$((30 + q))" > "$ARC_MNT/2026/report-q$q.txt"
done
head -c 2M /dev/urandom > "$ARC_MNT/2025/ledger.bin"
printf 'Archive of closed reporting periods. Read only.\n' > "$ARC_MNT/README"
(cd "$ARC_MNT" && find . -type f | sort | xargs sha256sum) > "$STATE/archive.sha256"
umount "$ARC_MNT"

# The application file system: ext4 with the data directory
truncate -s 200M "$APP_IMG"
chmod 600 "$APP_IMG"
mkfs.ext4 -q -F -L APPDATA "$APP_IMG" >/dev/null 2>&1 ||
	fail "cannot create the ext4 file system in $APP_IMG"

cat >> /etc/fstab <<FSTAB
$APP_IMG $APP_MNT ext4 loop,nofail 0 0
$ARC_IMG $ARC_MNT ext4 loop,nofail 0 0
FSTAB
systemctl daemon-reload
mount "$APP_MNT" >/dev/null 2>&1 || fail "cannot mount $APP_MNT from /etc/fstab"

data=$APP_MNT/data
mkdir -p "$data/reports" "$APP_MNT/logs" "$APP_MNT/.cache"
head -c 16M /dev/urandom > "$data/orders.db"
head -c 3M /dev/urandom > "$data/customers.idx"
for i in $(seq 1 400); do
	printf '%04d,customer-%04d,%s\n' "$i" "$i" "$((i * 7 % 23 + 1))"
done > "$data/customers.csv"
printf '[app]\nname = orders\nlog = %s/logs/app.log\n' "$APP_MNT" > "$data/app.ini"
for m in 07 08 09; do
	printf 'Monthly summary 2026-%s\nOrders: %s\n' "$m" "$((300 + 10#$m))" \
		> "$data/reports/2026-$m.txt"
done
(cd "$data" && find . -type f | sort | xargs sha256sum) > "$STATE/appdata.sha256"

# The dump in a hidden directory
n=$((RANDOM % 9000 + 1000))
dump=$APP_MNT/.cache/core.$n
head -c 70M /dev/urandom > "$dump"
echo "$dump" > "$STATE/dump"

# The log that app-logger keeps open: written first, opened by the
# service, then deleted
yes "2026-10-01 03:12:45 app-logger: DEBUG request handled in 12 ms, cache miss, retry 0" |
	head -c 70M > "$APP_MNT/logs/app.log" || true

cat > "$SCRIPT" <<'SCR'
#!/bin/bash
# app-logger: writes a heartbeat line to the application log
LOG=/srv/appdata/logs/app.log
mkdir -p "${LOG%/*}"
exec 3>>"$LOG"
while :; do
	echo "$(date '+%F %T') app-logger: heartbeat" >&3
	sleep 10 3>&-
done
SCR
chmod 755 "$SCRIPT"

cat > "$UNIT" <<UNITFILE
[Unit]
Description=Application heartbeat logger (lab storage-11)
RequiresMountsFor=$APP_MNT

[Service]
ExecStart=$SCRIPT
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNITFILE
chmod 644 "$UNIT"
restorecon -R "$SCRIPT" "$UNIT" "$APP_MNT" >/dev/null 2>&1 || true
systemctl daemon-reload
systemctl enable app-logger.service >/dev/null 2>&1 ||
	fail "cannot enable app-logger.service"
systemctl start app-logger.service || fail "cannot start app-logger.service"

# Wait until the service has the log open, then delete it
pid=""
for _ in $(seq 1 50); do
	pid=$(systemctl show -p MainPID --value app-logger.service)
	if [ -n "$pid" ] && [ "$pid" != 0 ] &&
		[ "$(readlink "/proc/$pid/fd/3" 2>/dev/null)" = "$APP_MNT/logs/app.log" ]; then
		break
	fi
	pid=""
	sleep 0.2
done
[ -n "$pid" ] || fail "app-logger.service did not open its log"
rm -f "$APP_MNT/logs/app.log"

cp /etc/fstab "$STATE/fstab"
chmod 644 "$STATE"/*
