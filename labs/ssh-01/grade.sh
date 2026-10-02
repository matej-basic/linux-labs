#!/bin/bash
# ssh-01 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/ssh-01
ALIAS=deploy-local

grade_begin ssh-01
grade_require_state ssh-01 "$STATE_FILE"
owner=$(sed -n 's/^owner=//p' "$STATE_FILE")
home=$(sed -n 's/^home=//p' "$STATE_FILE")
KEY="$home/.ssh/deploy_ed25519"
PUB="$KEY.pub"
dhome=$(getent passwd deploy | cut -d: -f6)
DSSH="${dhome:-/home/deploy}/.ssh"
AK="$DSSH/authorized_keys"

# Common client options: no prompts, no known_hosts of anybody
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o LogLevel=ERROR
	-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

# as_owner <cmd...>: run a command as the task user
as_owner() {
	runuser -u "$owner" -- "$@"
}

# The private key is an ed25519 key that opens without a passphrase
private_key_ok() {
	[ -f "$KEY" ] && [ ! -L "$KEY" ] || return 1
	ssh-keygen -y -P '' -f "$KEY" 2>/dev/null | grep -q '^ssh-ed25519 '
}

# mode_owner <path> <mode> <user>
mode_owner() {
	[ -e "$1" ] && [ ! -L "$1" ] || return 1
	[ "$(stat -c '%a %U' "$1")" = "$2 $3" ]
}

# The public key belongs to the task user and matches the private key
public_key_ok() {
	local derived stored
	[ -f "$PUB" ] && [ ! -L "$PUB" ] || return 1
	[ "$(stat -c %U "$PUB")" = "$owner" ] || return 1
	derived=$(ssh-keygen -y -P '' -f "$KEY" 2>/dev/null | awk '{ print $2 }')
	stored=$(awk 'NF >= 2 { print $2; exit }' "$PUB")
	[ -n "$derived" ] && [ "$derived" = "$stored" ]
}

# authorized_keys of deploy has a line with the key blob of the new key
authorized() {
	local blob
	[ -f "$AK" ] || return 1
	blob=$(ssh-keygen -y -P '' -f "$KEY" 2>/dev/null | awk '{ print $2 }')
	[ -n "$blob" ] || return 1
	awk -v b="$blob" '
		/^[[:space:]]*#/ { next }
		{ for (i = 1; i <= NF; i++) if ($i == b) found = 1 }
		END { exit !found }' "$AK"
}

# A batch-mode login as deploy on localhost with the key works, without
# the client configuration of the task user
key_login() {
	[ "$(as_owner ssh -F /dev/null -i "$KEY" -o IdentitiesOnly=yes \
		"${SSH_OPTS[@]}" deploy@localhost id -un </dev/null 2>/dev/null)" = deploy ]
}

# ssh_g <keyword>: the values of one keyword in "ssh -G <alias>"
ssh_g() {
	as_owner ssh -G "$ALIAS" 2>/dev/null | awk -v k="$1" '$1 == k { print $2 }'
}

alias_target() {
	[ "$(ssh_g user)" = deploy ] || return 1
	case $(ssh_g hostname) in
	localhost | localhost.localdomain | 127.0.0.1 | ::1) return 0 ;;
	esac
	return 1
}

# One of the identity files of the alias is the new private key
alias_key() {
	local f
	while read -r f; do
		case $f in
		\~/*) f="$home/${f#\~/}" ;;
		"%d/"*) f="$home/${f#%d/}" ;;
		esac
		[ "$f" = "$KEY" ] && return 0
	done < <(ssh_g identityfile)
	return 1
}

# A batch-mode login with the alias as the only target works
alias_login() {
	[ "$(as_owner ssh "${SSH_OPTS[@]}" "$ALIAS" id -un </dev/null 2>/dev/null)" = deploy ]
}

criterion "Key ~/.ssh/deploy_ed25519 is ed25519 without a passphrase" private_key_ok
criterion "Private key has mode 0600 and belongs to $owner" mode_owner "$KEY" 600 "$owner"
criterion "Public key belongs to $owner and matches the private key" public_key_ok
criterion "Directory $DSSH has mode 0700 and owner deploy" mode_owner "$DSSH" 700 deploy
criterion "File authorized_keys has mode 0600 and owner deploy" mode_owner "$AK" 600 deploy
criterion "authorized_keys of deploy contains the new public key" authorized
criterion "Key login as deploy on localhost works in batch mode" key_login
criterion "Alias $ALIAS connects to localhost as deploy" alias_target
criterion "Alias $ALIAS uses the key ~/.ssh/deploy_ed25519" alias_key
criterion "Login with the alias $ALIAS works in batch mode" alias_login
grade_end
