#!/bin/bash
# files-02 setup: remove any previous tree and make sure the apache user
# exists (it normally comes with httpd). Prints nothing on success.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/files-02"

# Remember whether an earlier run of this setup created the apache user
created=no
if [ -r "$STATE_FILE" ] && grep -qx 'apache_created=yes' "$STATE_FILE"; then
	created=yes
fi

rm -rf /tmp/webfiles

# Same IDs as the httpd package uses (48), without them if they are taken
if ! getent group apache >/dev/null; then
	groupadd -r -g 48 apache 2>/dev/null || groupadd -r apache
fi
if ! getent passwd apache >/dev/null; then
	useradd -r -u 48 -g apache -d /usr/share/httpd -s /sbin/nologin \
		-c Apache apache 2>/dev/null ||
		useradd -r -g apache -d /usr/share/httpd -s /sbin/nologin \
			-c Apache apache
	created=yes
fi

mkdir -p "$STATE_DIR"
echo "apache_created=$created" > "$STATE_FILE"
chmod 644 "$STATE_FILE"
