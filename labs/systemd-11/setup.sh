#!/bin/bash
# systemd-11 setup: undo an earlier run, record the runtime values of
# the lab's kernel parameters, a copy of /etc/sysctl.conf, /etc/sysctl.d
# and /etc/tmpfiles.d, the sysctl files that already set one of the
# parameters, the task user and the boot id. Then plant a legacy sysctl
# file that sets net.core.somaxconn back to 128 and apply it. Prints
# nothing on success.
set -eu

LAB=systemd-11
STATE=/opt/linux-labs/state/$LAB
LEGACY=/etc/sysctl.d/99-zz-legacy.conf
PARAMS="fs.inotify.max_user_watches net.core.somaxconn kernel.panic vm.vfs_cache_pressure"

fail() {
	echo "$LAB: $*" >&2
	exit 1
}

# Restore what an earlier run changed, so the record is the original.
# cleanup.sh is safe on a system where the lab never ran.
bash "$(dirname "$0")/cleanup.sh" >/dev/null ||
	fail "cannot restore the configuration of an earlier run"
[ ! -e "$STATE" ] || fail "$STATE is still present after the cleanup"

for cmd in sysctl systemd-tmpfiles; do
	command -v "$cmd" >/dev/null 2>&1 || fail "the command $cmd is missing"
done
[ -d /etc/sysctl.d ] || fail "the directory /etc/sysctl.d is missing"
[ -d /etc/tmpfiles.d ] || fail "the directory /etc/tmpfiles.d is missing"

# Task user: LAB_USER from labctl, else the first regular user
owner="${LAB_USER:-student}"
if ! id "$owner" >/dev/null 2>&1; then
	owner=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
	[ -n "$owner" ] || fail "no regular user for the lab"
fi

mkdir -p "$STATE"
chmod 755 "$STATE"
echo "$owner" > "$STATE/owner"
for p in $PARAMS; do
	v=$(sysctl -n "$p" 2>/dev/null) || fail "the kernel has no parameter $p"
	printf '%s=%s\n' "$p" "$v"
done > "$STATE/runtime"
cp -a /etc/sysctl.d "$STATE/sysctl.d"
cp -a /etc/tmpfiles.d "$STATE/tmpfiles.d"
[ ! -e /etc/sysctl.conf ] || cp -a /etc/sysctl.conf "$STATE/sysctl.conf"
# For the record: files that already set one of the parameters
grep -lsE '^[[:space:]]*-?(fs.inotify.max_user_watches|net.core.somaxconn|kernel.panic|vm.vfs_cache_pressure)[[:space:]]*=' \
	/etc/sysctl.conf /etc/sysctl.d/*.conf /run/sysctl.d/*.conf \
	/usr/local/lib/sysctl.d/*.conf /usr/lib/sysctl.d/*.conf \
	> "$STATE/sysctl-files" || true
cat /proc/sys/kernel/random/boot_id > "$STATE/boot-id"
chmod 644 "$STATE/owner" "$STATE/runtime" "$STATE/sysctl-files" "$STATE/boot-id"

# Starting point: the legacy file, applied at runtime
cat > "$LEGACY" <<'CONF'
# Tuning left from an earlier application server on this host
net.core.somaxconn = 128
vm.vfs_cache_pressure = 150
CONF
chmod 644 "$LEGACY"
restorecon "$LEGACY" 2>/dev/null || true
sysctl -q -p "$LEGACY" >/dev/null || fail "cannot apply $LEGACY"

echo "$LAB baseline recorded $(date '+%F %T')" > "$STATE/baseline"
chmod 644 "$STATE/baseline"
