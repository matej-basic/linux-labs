#!/bin/bash
# ssh-02 grader: checks the effective SSH server configuration (sshd -T,
# with -C for the Match block), the listening sockets, the SELinux port
# type, the firewall and a real key login on both ports.
source /opt/linux-labs/lib/grading.sh

LAB=ssh-02
PORT=2222
STATE_FILE=/opt/linux-labs/state/$LAB
KEY=/opt/linux-labs/state/$LAB.d/svcbackup_ed25519

grade_begin ssh-02
grade_require_state ssh-02 "$STATE_FILE"

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}
owner=$(state_value owner)
zone=$(state_value zone)
pw_owner=$(state_value pw_owner)

# eff <user> <keyword>: the effective value of a keyword for a
# connection of <user> from localhost (Match blocks applied)
eff() {
	sshd -T -C "user=$1,host=localhost,addr=127.0.0.1" 2>/dev/null |
		awk -v k="$2" '$1 == k { print $2; exit }'
}

config_valid() {
	sshd -t
}

root_key_only() {
	case $(eff root permitrootlogin) in
	prohibit-password | without-password) return 0 ;;
	esac
	return 1
}

automation_no_password() {
	local u
	for u in svcbackup svcdeploy; do
		[ "$(eff "$u" passwordauthentication)" = no ] || return 1
	done
}

automation_pubkey() {
	local u
	for u in svcbackup svcdeploy; do
		[ "$(eff "$u" pubkeyauthentication)" = yes ] || return 1
	done
}

others_unchanged() {
	[ -n "$pw_owner" ] && [ "$(eff "$owner" passwordauthentication)" = "$pw_owner" ]
}

# The configured ports are exactly 22 and 2222
ports_configured() {
	[ "$(sshd -T 2>/dev/null | awk '$1 == "port" { print $2 }' | sort -n | tr '\n' ' ')" = "22 $PORT " ]
}

sshd_running() {
	systemctl is-active --quiet sshd && systemctl is-enabled --quiet sshd
}

# listens <port>: sshd has a listening TCP socket on the port
listens() {
	ss -Htlnp "sport = :$1" 2>/dev/null | grep -q '"sshd"'
}

selinux_port() {
	command -v semanage >/dev/null 2>&1 || return 1
	semanage port -l 2>/dev/null | awk -v p="$PORT" '
		$1 == "ssh_port_t" && $2 == "tcp" {
			for (i = 3; i <= NF; i++) { x = $i; sub(/,$/, "", x); if (x == p) f = 1 }
		}
		END { exit !f }'
}

# fw_open [--permanent]: 2222/tcp is open in the default zone, as a port
# or through a service that has the port
fw_open() {
	local svc
	firewall-cmd "$@" --zone="$zone" --query-port="$PORT/tcp" && return 0
	for svc in $(firewall-cmd "$@" --zone="$zone" --list-services); do
		firewall-cmd --permanent --service="$svc" --get-ports |
			tr ' ' '\n' | grep -qx "$PORT/tcp" && return 0
	done
	return 1
}

# key_login <port>: a batch-mode key login as svcbackup on localhost
key_login() {
	[ "$(ssh -F /dev/null -p "$1" -i "$KEY" -o IdentitiesOnly=yes \
		-o BatchMode=yes -o ConnectTimeout=10 -o LogLevel=ERROR \
		-o PreferredAuthentications=publickey \
		-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		svcbackup@127.0.0.1 id -un </dev/null 2>/dev/null)" = svcbackup ]
}

criterion "Root can log in over SSH with a key only" root_key_only
criterion "Group automation has password authentication off" automation_no_password
criterion "Group automation keeps public key authentication" automation_pubkey
criterion "Password authentication for $owner is unchanged" others_unchanged
criterion "sshd is configured for the ports 22 and $PORT" ports_configured
criterion "sshd is enabled and running" sshd_running
criterion "sshd listens on port 22" listens 22
criterion "sshd listens on port $PORT" listens "$PORT"
criterion "Port $PORT/tcp has the SELinux type ssh_port_t" selinux_port
criterion "Port $PORT/tcp is open in zone $zone (runtime)" fw_open
criterion "Port $PORT/tcp is open in zone $zone (permanent)" fw_open --permanent
criterion "Key login as svcbackup works on port 22" key_login 22
criterion "Key login as svcbackup works on port $PORT" key_login "$PORT"
criterion "The sshd configuration passes the syntax test" config_valid
grade_end
