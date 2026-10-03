#!/bin/bash
# packages-07 setup: the aftermath of a botched update on servera.
#   - /etc/chrony.conf is an old local configuration: the two local
#     lines allow 172.25.250.0/24 and local stratum 10, old server
#     lines, and two ntpd access rules (restrict) that chronyd rejects
#   - the default chrony.conf of the installed package is next to it as
#     /etc/chrony.conf.rpmnew, as rpm leaves it when an update meets a
#     changed configuration file
#   - chronyd is enabled, and setup restarts it once, so it is failed
#     and the error is in the journal
#   - a dnf transaction of its own installed mc, which pulls in the new
#     dependency gpm-libs
# Prints nothing on success.
#
# The first run records the package set (pkg_snapshot), and in
# /opt/linux-labs/state/packages-07.d a copy of /etc/chrony.conf as it
# was (for cleanup.sh), the package default (the reference for the
# grader; the file must be unchanged at the first start, which rpm -V
# confirms), any chrony .rpmnew or .rpmsave file that already existed,
# and the boot and running state of chronyd.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=packages-07
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
CONF=/etc/chrony.conf
EXTRA=mc

command -v dnf >/dev/null 2>&1 || { echo "Error: dnf not found." >&2; exit 1; }
if ! rpm -q chrony >/dev/null 2>&1; then
	echo "Error: the package chrony is not installed; this lab needs it." >&2
	exit 1
fi

# Chrony .rpmnew and .rpmsave files under /etc
chrony_leftovers() {
	find /etc \( -name 'chrony*.rpmnew' -o -name 'chrony*.rpmsave' \) \
		-print 2>/dev/null
}

pkg_snapshot "$LAB"

if pkg_was_installed "$LAB" "$EXTRA"; then
	echo "Error: the package $EXTRA was installed before the lab." \
		"Remove it, then start the lab again." >&2
	exit 1
fi

# First run only: what the machine looked like before the lab
if [ ! -d "$REC_DIR" ]; then
	# The verify flags of chrony.conf; 5 (digest) or S (size) means
	# that the content differs from the package
	flags=$(rpm -V chrony 2>/dev/null | awk -v f="$CONF" '$NF == f { print $1 }')
	case "$flags" in
	*5* | *S* | missing)
		echo "Error: $CONF differs from the default of the chrony" \
			"package. Restore the default, then start the lab again." >&2
		exit 1
		;;
	esac
	[ -f "$CONF" ] || { echo "Error: $CONF does not exist." >&2; exit 1; }
	rm -rf "$REC_DIR.tmp"
	mkdir -p "$STATE_DIR"
	mkdir -m 0700 "$REC_DIR.tmp" "$REC_DIR.tmp/leftovers"
	cp -a "$CONF" "$REC_DIR.tmp/chrony.conf.orig"
	cp "$CONF" "$REC_DIR.tmp/chrony.conf.default"
	chrony_leftovers > "$REC_DIR.tmp/leftovers.list"
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		cp -a "$f" "$REC_DIR.tmp/leftovers/$(printf '%s' "$f" | tr / _)"
	done < "$REC_DIR.tmp/leftovers.list"
	{
		systemctl is-enabled --quiet chronyd 2>/dev/null && echo chronyd-enabled
		systemctl is-active --quiet chronyd 2>/dev/null && echo chronyd-active
	} > "$REC_DIR.tmp/flags" || true
	mv "$REC_DIR.tmp" "$REC_DIR"
fi

# Left over from an earlier start or a solution: the packages of the
# earlier setup transaction
if [ -r "$STATE_FILE" ]; then
	old=$(sed -n 's/^new=//p' "$STATE_FILE" | head -n 1)
	gone=
	for p in $old; do
		rpm -q "$p" >/dev/null 2>&1 && gone="$gone $p"
	done
	if [ -n "$gone" ]; then
		# shellcheck disable=SC2086 # one word per package
		if ! out=$(dnf -y --disablerepo='*' remove $gone </dev/null 2>&1); then
			printf '%s\n' "$out" >&2
			echo "Error: cannot remove$gone." >&2
			exit 1
		fi
	fi
	rm -f "$STATE_FILE"
fi
rm -f /root/chrony.conf.old

# The configuration as the update left it
cp "$REC_DIR/chrony.conf.default" "$CONF.rpmnew"
chmod 0644 "$CONF.rpmnew"
rm -f "$CONF.rpmsave"
cat > "$CONF" <<'CONF'
# chrony configuration for servera, migrated from ntpd

# Time sources
server 0.rocky.pool.ntp.org iburst
server 1.rocky.pool.ntp.org iburst
server 2.rocky.pool.ntp.org iburst

# Access rules taken over from the old ntp.conf
restrict default kod nomodify notrap nopeer noquery
restrict 127.0.0.1

# Record the rate at which the system clock gains or loses time.
driftfile /var/lib/chrony/drift

# Step the clock in the first three updates if the offset is large.
makestep 10 3

# Keep the real-time clock in sync.
rtcsync

# Local settings: serve time to the classroom network, also when no
# time source is reachable.
allow 172.25.250.0/24
local stratum 10

# Key file and log directory.
keyfile /etc/chrony.keys
logdir /var/log/chrony
CONF
chmod 0644 "$CONF"
restorecon "$CONF" "$CONF.rpmnew" >/dev/null 2>&1 || true

# chronyd is enabled, tried once and failed
systemctl enable chronyd >/dev/null 2>&1
if systemctl restart chronyd >/dev/null 2>&1; then
	echo "Error: chronyd started although its configuration is invalid." >&2
	exit 1
fi

# The unwanted package, in a dnf transaction of its own. The packages
# that are new after it are what the grader checks.
before=$(rpm -qa --qf '%{NAME}.%{ARCH}\n' | LC_ALL=C sort -u)
if ! out=$(dnf -y install "$EXTRA" </dev/null 2>&1); then
	printf '%s\n' "$out" >&2
	echo "Error: could not install the package $EXTRA." >&2
	exit 1
fi
# A repo key that dnf imported is no package of the transaction;
# pkg_restore removes it at reset
new=$(rpm -qa --qf '%{NAME}.%{ARCH}\n' | LC_ALL=C sort -u |
	LC_ALL=C comm -13 <(printf '%s\n' "$before") - |
	grep -v '^gpg-pubkey\.' | tr '\n' ' ')

tmp="$STATE_FILE.tmp"
echo "new=${new% }" > "$tmp"
chmod 0644 "$tmp"
mv "$tmp" "$STATE_FILE"
exit 0
