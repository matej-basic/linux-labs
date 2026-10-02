#!/bin/bash
# ssh-02 cleanup: puts the SSH server configuration back exactly as it
# was before the lab (sshd_config and the directory sshd_config.d),
# checks it with sshd -t and reloads sshd. Then removes the SELinux port
# mapping and the firewall rule for 2222/tcp unless they existed before,
# the lab accounts and key files, and restores the package set.
#
# sshd is reloaded (or started, when it is not running): sessions that
# are open, such as the one labctl runs this script through, stay open.
source /opt/linux-labs/lib/packages.sh

LAB=ssh-02
PORT=2222
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
BACKUP_DIR="$STATE_DIR/$LAB.d"
DROPIN_DIR=/etc/ssh/sshd_config.d

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

rc=0

# Without the state file the lab did not start: leave sshd and the
# accounts alone, only restore packages if a snapshot exists
if [ -f "$STATE_FILE" ]; then
	owner=$(state_value owner)
	home=$(state_value home)

	# 1. SSH server configuration
	if [ -f "$BACKUP_DIR/sshd_config" ]; then
		cp -a "$BACKUP_DIR/sshd_config" /etc/ssh/sshd_config
		rm -rf "$DROPIN_DIR"
		if [ "$(state_value dropin_dir)" = 1 ] && [ -d "$BACKUP_DIR/sshd_config.d" ]; then
			cp -a "$BACKUP_DIR/sshd_config.d" "$DROPIN_DIR"
		fi
		restorecon -R /etc/ssh >/dev/null 2>&1
		if sshd -t >/dev/null 2>&1; then
			systemctl reload-or-restart sshd >/dev/null 2>&1 || {
				echo "Error: sshd did not reload after the configuration was restored." >&2
				rc=1
			}
		else
			echo "Error: the restored SSH server configuration fails sshd -t; sshd was not reloaded." >&2
			rc=1
		fi
	fi

	# 2. SELinux port mapping (needs semanage, so before pkg_restore)
	if [ "$(state_value sel_local)" != 1 ] && command -v semanage >/dev/null 2>&1; then
		if semanage port -l -C 2>/dev/null | awk -v p="$PORT" '
			$2 == "tcp" { for (i = 3; i <= NF; i++) { x = $i; sub(/,$/, "", x); if (x == p) f = 1 } }
			END { exit !f }'; then
			semanage port -d -p tcp "$PORT" >/dev/null 2>&1 || true
		fi
	fi

	# 3. Firewall: remove 2222/tcp from every zone, except the default
	# zone of the start when the port was open there
	if systemctl is-active --quiet firewalld; then
		zone=$(state_value zone)
		for z in $(firewall-cmd --permanent --get-zones 2>/dev/null); do
			if [ "$z" != "$zone" ] || [ "$(state_value fw_perm)" != 1 ]; then
				firewall-cmd --permanent --zone="$z" --remove-port="$PORT/tcp" >/dev/null 2>&1 || true
			fi
		done
		for z in $(firewall-cmd --get-zones 2>/dev/null); do
			if [ "$z" != "$zone" ] || [ "$(state_value fw_rt)" != 1 ]; then
				firewall-cmd --zone="$z" --remove-port="$PORT/tcp" >/dev/null 2>&1 || true
			fi
		done
	fi

	# 4. Lab accounts and key files
	for u in svcbackup svcdeploy; do
		if getent passwd "$u" >/dev/null; then
			pkill -KILL -u "$u" >/dev/null 2>&1
			userdel -r -f "$u" >/dev/null 2>&1
		fi
		groupdel "$u" >/dev/null 2>&1
		rm -rf "/home/${u:?}"
	done
	groupdel automation >/dev/null 2>&1
	if [ -n "$home" ] && [ -n "$owner" ]; then
		rm -f "$home/svcbackup_ed25519" "$home/svcbackup_ed25519.pub"
	fi
fi

pkg_restore "$LAB" || rc=1

if [ "$rc" -eq 0 ]; then
	rm -rf "$BACKUP_DIR"
	rm -f "$STATE_FILE"
fi
exit "$rc"
