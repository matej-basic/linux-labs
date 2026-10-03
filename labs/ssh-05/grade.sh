#!/bin/bash
# ssh-05 grader: the CA key pair in /etc/ssh, the effective sshd
# configuration of deploy and of the task user (sshd -T, with -C for
# the Match blocks), the certificate as ssh-keygen -L shows it, and two
# real logins as deploy with the lab key: one with the certificate,
# which must work, and one without it, which must be refused. The
# clients use a throwaway known_hosts, so no known_hosts file changes.
source /opt/linux-labs/lib/grading.sh

LAB=ssh-05
ACCOUNT=deploy
CA=/etc/ssh/lab_user_ca
STATE_FILE=/opt/linux-labs/state/$LAB
REC_DIR=/opt/linux-labs/state/$LAB.d
KEY=$REC_DIR/deploy_ed25519
# 52 weeks, plus 10 minutes for the start time that ssh-keygen sets a
# little in the past
MAX_VALID=$((52 * 7 * 86400 + 600))

grade_begin ssh-05
grade_require_state ssh-05 "$STATE_FILE"

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" 2>/dev/null | head -n 1
}
owner=$(state_value owner)
home=$(state_value home)
CERT=$home/deploy_ed25519-cert.pub

# eff <user> <keyword>: the effective value of a keyword for a
# connection of <user> from localhost (Match blocks applied)
eff() {
	sshd -T -C "user=$1,host=localhost,addr=127.0.0.1" 2>/dev/null |
		awk -v k="$2" '$1 == k { $1 = ""; sub(/^ /, ""); print; exit }'
}

# fp <file>: the SHA256 fingerprint of a public key file
fp() {
	ssh-keygen -l -f "$1" 2>/dev/null | awk '{ print $2; exit }'
}

# cert_info: the certificate as ssh-keygen -L prints it, times in UTC
cert_info() {
	[ -f "$CERT" ] && [ ! -L "$CERT" ] || return 1
	TZ=UTC ssh-keygen -L -f "$CERT" 2>/dev/null
}

ca_private_ok() {
	[ -f "$CA" ] && [ ! -L "$CA" ] &&
		[ "$(stat -c %U:%a "$CA")" = root:600 ]
}

# ca_pair_ok: the private key opens without a passphrase and its public
# half is the one in lab_user_ca.pub
ca_pair_ok() {
	local a b
	[ -f "$CA.pub" ] || return 1
	a=$(ssh-keygen -y -P '' -f "$CA" 2>/dev/null </dev/null | awk '{ print $1, $2 }')
	b=$(awk '{ print $1, $2; exit }' "$CA.pub")
	[ -n "$a" ] && [ "$a" = "$b" ]
}

sshd_trusts_ca() {
	[ "$(eff "$ACCOUNT" trustedusercakeys)" = "$CA.pub" ]
}

# cert_signed: a user certificate whose signing CA is lab_user_ca
cert_signed() {
	local info ca_fp
	info=$(cert_info) || return 1
	ca_fp=$(fp "$CA.pub")
	[ -n "$ca_fp" ] || return 1
	printf '%s\n' "$info" | grep -Eq '^[[:space:]]*Type: .* user certificate$' &&
		printf '%s\n' "$info" | grep -E '^[[:space:]]*Signing CA:' |
		grep -qF " $ca_fp"
}

# cert_for_key: the certificate holds the lab public key of deploy
cert_for_key() {
	local info key_fp
	info=$(cert_info) || return 1
	key_fp=$(fp "$REC_DIR/deploy_ed25519.pub")
	[ -n "$key_fp" ] &&
		[ "$(printf '%s\n' "$info" |
			awk '$1 == "Public" && $2 == "key:" { print $NF; exit }')" = "$key_fp" ]
}

cert_key_id() {
	cert_info | grep -qx '[[:space:]]*Key ID: "deploy-cert"'
}

# cert_principals: the principal list is exactly deploy
cert_principals() {
	local list
	list=$(cert_info | awk '
		/^[[:space:]]*Principals:/ { p = 1; next }
		/^[[:space:]]*Critical Options:/ { p = 0 }
		p { gsub(/[[:space:]]/, ""); if ($0 != "") print }')
	[ "$list" = "$ACCOUNT" ]
}

# cert_validity: valid now, for at most 52 weeks
cert_validity() {
	local line from to f t now
	line=$(cert_info | grep -E '^[[:space:]]*Valid: from ') || return 1
	from=$(printf '%s\n' "$line" | awk '{ print $3 }')
	to=$(printf '%s\n' "$line" | awk '{ print $5 }')
	f=$(TZ=UTC date -d "$from" +%s 2>/dev/null) || return 1
	t=$(TZ=UTC date -d "$to" +%s 2>/dev/null) || return 1
	now=$(date +%s)
	[ "$f" -le "$now" ] && [ "$now" -lt "$t" ] &&
		[ $((t - f)) -le "$MAX_VALID" ]
}

# login <with-cert|key-only>: a key login as deploy that runs id -un;
# succeeds when the output is deploy
login() {
	local tmp out rc=1
	[ -r "$KEY" ] || return 1
	tmp=$(mktemp -d) || return 1
	cp "$KEY" "$tmp/id"
	chmod 0600 "$tmp/id"
	local opts=(-F /dev/null -i "$tmp/id" -o IdentitiesOnly=yes -o IdentityAgent=none
		-o BatchMode=yes -o ConnectTimeout=10
		-o PreferredAuthentications=publickey
		-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
		-o GlobalKnownHostsFile=/dev/null)
	if [ "$1" = with-cert ]; then
		if [ -f "$CERT" ]; then
			cp "$CERT" "$tmp/id-cert.pub"
			opts+=(-o "CertificateFile=$tmp/id-cert.pub")
		fi
	fi
	out=$(timeout 30 ssh "${opts[@]}" "$ACCOUNT@127.0.0.1" id -un \
		</dev/null 2>/dev/null) && [ "$out" = "$ACCOUNT" ] && rc=0
	rm -rf "$tmp"
	return "$rc"
}

login_with_cert() {
	[ -f "$CERT" ] && login with-cert
}

login_key_refused() {
	# The lab key must exist, or the test proves nothing
	[ -r "$KEY" ] && ! login key-only
}

# owner_unchanged: the effective settings of the task user are as they
# were at the first start, apart from TrustedUserCAKeys
owner_unchanged() {
	[ -n "$owner" ] && [ -s "$REC_DIR/owner.sshd" ] &&
		cmp -s <(sshd -T -C "user=$owner,host=localhost,addr=127.0.0.1" 2>/dev/null |
			grep -v '^trustedusercakeys ') \
			<(grep -v '^trustedusercakeys ' "$REC_DIR/owner.sshd")
}

sshd_running() {
	systemctl is-active --quiet sshd && systemctl is-enabled --quiet sshd
}

selinux_enforcing() {
	[ "$(getenforce 2>/dev/null)" = Enforcing ] &&
		grep -Eq '^SELINUX=enforcing[[:space:]]*$' /etc/selinux/config
}

criterion "$CA exists, owned by root, mode 0600" ca_private_ok
criterion "$CA.pub matches the private key" ca_pair_ok
criterion "sshd trusts $CA.pub for deploy" sshd_trusts_ca
criterion "The certificate is a user certificate signed by the CA" cert_signed
criterion "The certificate is for the lab public key of deploy" cert_for_key
criterion "The key ID of the certificate is deploy-cert" cert_key_id
criterion "The only principal of the certificate is deploy" cert_principals
criterion "The certificate is valid now and for at most 52 weeks" cert_validity
criterion "Login as deploy with the key and the certificate works" login_with_cert
criterion "Login as deploy with the key alone is refused" login_key_refused
criterion "The sshd settings for $owner are unchanged" owner_unchanged
criterion "The sshd configuration passes the syntax test" sshd -t
criterion "sshd is enabled and running" sshd_running
criterion "SELinux is enforcing now and in /etc/selinux/config" selinux_enforcing
grade_end
