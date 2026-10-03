#!/bin/bash
# users-05 setup: records the content of /etc/sudoers.d, creates the
# group helpdesk and the users webops (member of helpdesk) and auditor
# with a known password. Prints nothing on success.
set -eu

LAB=users-05
STATE_DIR=/opt/linux-labs/state/$LAB
STATE=$STATE_DIR/state
LIST=$STATE_DIR/sudoers.d.list
DROPIN=/etc/sudoers.d/50-lab
PASSWORD='Desk-Lamp-4721'

fail() {
	echo "Error: $*" >&2
	exit 1
}

# A restart first undoes the previous run and its solution completely
if [ -f "$STATE" ]; then
	bash "$(dirname "$0")/cleanup.sh" >/dev/null ||
		fail "cleanup of the previous run of $LAB failed."
fi

command -v visudo >/dev/null 2>&1 || fail "visudo (sudo) is not installed."
[ -d /etc/sudoers.d ] || fail "/etc/sudoers.d does not exist."
grep -Eq '^[#@]includedir[[:space:]]+/etc/sudoers.d' /etc/sudoers ||
	fail "/etc/sudoers does not include /etc/sudoers.d."
visudo -c >/dev/null 2>&1 ||
	fail "the sudo configuration has errors before the lab (visudo -c)."
[ -e "$DROPIN" ] && fail "$DROPIN already exists."
for u in webops auditor; do
	getent passwd "$u" >/dev/null &&
		fail "user $u already exists and was not created by this lab."
done
getent group helpdesk >/dev/null &&
	fail "group helpdesk already exists and was not created by this lab."

rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
chmod 0755 "$STATE_DIR"
# Every file in /etc/sudoers.d that is not in this list is removed by
# cleanup.sh
find /etc/sudoers.d -mindepth 1 -maxdepth 1 -print > "$LIST"
chmod 0644 "$LIST"
echo "LAB_USER=${LAB_USER:-student}" > "$STATE"
chmod 0644 "$STATE"

groupadd helpdesk || fail "cannot create group helpdesk."
useradd -m -s /bin/bash -G helpdesk webops || fail "cannot create user webops."
useradd -m -s /bin/bash auditor || fail "cannot create user auditor."
for u in webops auditor; do
	echo "$u:$PASSWORD" | chpasswd || fail "cannot set the password of $u."
done

exit 0
