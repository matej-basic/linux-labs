#!/bin/bash
# ssh-02 setup: a copy of the SSH server configuration as it is now, the
# group automation with the members svcbackup and svcdeploy (password
# and key login), a key pair for svcbackup and a record of the SELinux
# and firewall state of port 2222/tcp. When the configuration does not
# allow root password logins yet and sshd reads /etc/ssh/sshd_config.d,
# setup adds the drop-in that the installer writes for "allow root SSH
# login with password", so the lab starts from the same weak state on
# Rocky 8 and 9. Prints nothing on success.
#
# Safety: setup never changes Port, PubkeyAuthentication or anything
# else that labctl needs for key logins as the task user on port 22.
# It validates with sshd -t before every reload.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=ssh-02
PORT=2222
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
BACKUP_DIR="$STATE_DIR/$LAB.d"
DROPIN_DIR=/etc/ssh/sshd_config.d
ROOT_DROPIN="$DROPIN_DIR/01-permitrootlogin.conf"
LAB_PASSWORD='Ssh02.lab'

# Restart: undo the previous run (and its solution) first, so the copy
# below is the configuration from before the lab
if [ -f "$STATE_FILE" ]; then
	bash "$(dirname "$0")/cleanup.sh"
fi

pkg_snapshot "$LAB"

# Task user: LAB_USER from labctl, else the first regular user
owner="${LAB_USER:-student}"
if ! id "$owner" &>/dev/null; then
	owner=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
fi
if [ -z "$owner" ] || ! id "$owner" &>/dev/null; then
	echo "Error: no regular user account found for the lab." >&2
	exit 1
fi
home=$(getent passwd "$owner" | cut -d: -f6)
if [ -z "$home" ] || [ ! -d "$home" ]; then
	echo "Error: the home directory of $owner does not exist." >&2
	exit 1
fi

# Refuse to take over accounts or files that this lab did not create
for a in svcbackup svcdeploy automation; do
	if getent passwd "$a" >/dev/null || getent group "$a" >/dev/null; then
		echo "Error: user or group $a already exists and was not created by this lab." >&2
		exit 1
	fi
done
for d in /home/svcbackup /home/svcdeploy "$home/svcbackup_ed25519"; do
	if [ -e "$d" ]; then
		echo "Error: $d already exists and was not created by this lab." >&2
		exit 1
	fi
done
if [ -n "$(ss -Htln "sport = :$PORT" 2>/dev/null)" ]; then
	echo "Error: a service already listens on port $PORT/tcp." >&2
	exit 1
fi
if ! sshd -t >/dev/null 2>&1; then
	echo "Error: the SSH server configuration does not pass sshd -t." >&2
	exit 1
fi
if ! systemctl is-active --quiet firewalld; then
	echo "Error: firewalld is not running." >&2
	exit 1
fi

# Copy of the SSH server configuration, restored exactly by cleanup.sh
mkdir -p "$STATE_DIR"
rm -rf "$BACKUP_DIR"
mkdir -m 700 "$BACKUP_DIR"
cp -a /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config"
dropin_dir=0
if [ -d "$DROPIN_DIR" ]; then
	dropin_dir=1
	cp -a "$DROPIN_DIR" "$BACKUP_DIR/sshd_config.d"
fi

# SELinux: a local port mapping for 2222/tcp that existed before the lab
sel_local=0
if grep -qsE "(^|[^0-9])$PORT([^0-9]|$)" /var/lib/selinux/targeted/active/ports.local; then
	sel_local=1
fi

# Firewall: is the port open in the default zone already
zone=$(firewall-cmd --get-default-zone)
fw_rt=0
fw_perm=0
firewall-cmd --zone="$zone" --query-port="$PORT/tcp" >/dev/null 2>&1 && fw_rt=1
firewall-cmd --permanent --zone="$zone" --query-port="$PORT/tcp" >/dev/null 2>&1 && fw_perm=1

# Password authentication for the task user before the lab
pw_owner=$(sshd -T -C "user=$owner,host=localhost,addr=127.0.0.1" 2>/dev/null |
	awk '$1 == "passwordauthentication" { print $2; exit }')

{
	echo "owner=$owner"
	echo "home=$home"
	echo "dropin_dir=$dropin_dir"
	echo "sel_local=$sel_local"
	echo "zone=$zone"
	echo "fw_rt=$fw_rt"
	echo "fw_perm=$fw_perm"
	echo "pw_owner=$pw_owner"
} > "$STATE_FILE"
chmod 644 "$STATE_FILE"

# The group automation and its two members, with a password
groupadd automation
for u in svcbackup svcdeploy; do
	useradd -m -G automation -c "ssh-02 lab account" "$u"
	echo "$u:$LAB_PASSWORD" | chpasswd
done

# Key pair for svcbackup: the grader keeps its own copy, the task user
# gets one to test with
ssh-keygen -q -t ed25519 -N '' -C "$LAB" -f "$BACKUP_DIR/svcbackup_ed25519"
install -d -m 700 -o svcbackup -g svcbackup /home/svcbackup/.ssh
install -m 600 -o svcbackup -g svcbackup "$BACKUP_DIR/svcbackup_ed25519.pub" \
	/home/svcbackup/.ssh/authorized_keys
restorecon -R /home/svcbackup/.ssh
install -m 600 -o "$owner" -g "$(id -gn "$owner")" "$BACKUP_DIR/svcbackup_ed25519" \
	"$home/svcbackup_ed25519"

# Start state: root may log in with a password. Rocky 8 has that in
# sshd_config; Rocky 9 needs the installer's drop-in.
root_login=$(sshd -T 2>/dev/null | awk '$1 == "permitrootlogin" { print $2; exit }')
if [ "$root_login" != yes ] && [ -d "$DROPIN_DIR" ] &&
	grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config; then
	printf '%s\n' "PermitRootLogin yes" > "$ROOT_DROPIN"
	chmod 600 "$ROOT_DROPIN"
	restorecon "$ROOT_DROPIN"
	if ! sshd -t >/dev/null 2>&1; then
		rm -f "$ROOT_DROPIN"
		echo "Error: sshd -t failed after adding $ROOT_DROPIN." >&2
		exit 1
	fi
	systemctl reload sshd
fi

exit 0
