#!/bin/bash
# webserver-08 setup: the site content in /var/www/html with a public
# page and the directories private and admin, without a running web
# server. httpd may not be installed yet; the tree is created anyway
# and cleanup.sh removes it. Prints nothing on success.
#
# The first run records the package set (pkg_snapshot), every path
# under /etc/httpd and /var/www with a copy of both trees when they
# exist, the firewall state of http and 80/tcp in the default zone, the
# service state of httpd and the SELinux runtime mode. cleanup.sh puts
# all of it back. A second run deletes what an earlier attempt added
# under /etc/httpd and /var/www (files no package owns) and creates the
# content again; edits to packaged files stay until labctl reset.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=webserver-08
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
TREES="/etc/httpd /var/www"
DOCROOT=/var/www/html

if ! command -v getenforce >/dev/null 2>&1 || [ "$(getenforce)" = Disabled ]; then
	echo "Error: SELinux is disabled; this lab needs SELinux enabled." >&2
	exit 1
fi
if ! command -v firewall-cmd >/dev/null 2>&1 \
	|| ! systemctl is-active --quiet firewalld 2>/dev/null; then
	echo "Error: firewalld is not running on this machine." >&2
	exit 1
fi

pkg_snapshot "$LAB"

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# Every path under the trees, sorted
tree_list() {
	# shellcheck disable=SC2086 # word splitting is intended
	find $TREES -xdev 2>/dev/null | LC_ALL=C sort
}

# First run only: what the machine looked like before the lab
if [ ! -r "$STATE_FILE" ]; then
	mkdir -p "$STATE_DIR"
	rm -rf "$REC_DIR"
	mkdir -m 0700 "$REC_DIR"
	tree_list > "$REC_DIR/files.list"
	keep=
	for p in etc/httpd var/www; do
		[ -e "/$p" ] && keep="$keep $p"
	done
	if [ -n "$keep" ]; then
		# shellcheck disable=SC2086 # word splitting is intended
		tar --selinux --xattrs --acls -C / -cpf "$REC_DIR/files.tar" $keep
	fi
	zone=$(firewall-cmd --get-default-zone)
	fw_open=
	firewall-cmd --permanent --zone="$zone" --query-service=http >/dev/null 2>&1 \
		&& fw_open="$fw_open p:service:http"
	firewall-cmd --zone="$zone" --query-service=http >/dev/null 2>&1 \
		&& fw_open="$fw_open r:service:http"
	firewall-cmd --permanent --zone="$zone" --query-port=80/tcp >/dev/null 2>&1 \
		&& fw_open="$fw_open p:port:80/tcp"
	firewall-cmd --zone="$zone" --query-port=80/tcp >/dev/null 2>&1 \
		&& fw_open="$fw_open r:port:80/tcp"
	svc_state=
	systemctl is-enabled --quiet httpd 2>/dev/null && svc_state="$svc_state httpd:enabled"
	systemctl is-active --quiet httpd 2>/dev/null && svc_state="$svc_state httpd:active"
	tmp="$STATE_FILE.tmp"
	{
		echo "zone=$zone"
		echo "fw_open=$fw_open"
		echo "services=$svc_state"
		echo "selinux_mode=$(getenforce)"
	} > "$tmp"
	chmod 0644 "$tmp"
	mv "$tmp" "$STATE_FILE"
fi

# Reset what a previous run or the solution left behind: paths under
# the trees that are new since the first start and that no package owns
systemctl disable --now httpd >/dev/null 2>&1 || true
systemctl reset-failed httpd >/dev/null 2>&1 || true
tree_list | LC_ALL=C comm -13 "$REC_DIR/files.list" - | LC_ALL=C sort -r |
	while IFS= read -r p; do
		rpm -qf "$p" >/dev/null 2>&1 && continue
		if [ -d "$p" ] && [ ! -L "$p" ]; then
			rmdir "$p" 2>/dev/null || true
		else
			rm -f "$p"
		fi
	done
setenforce 1

if [ -n "$(ss -H -tln 'sport = :80' 2>/dev/null)" ]; then
	echo "Error: another service already listens on TCP port 80." >&2
	exit 1
fi

# The site content
rm -rf "$DOCROOT/private" "$DOCROOT/admin"
mkdir -p "$DOCROOT/private" "$DOCROOT/admin"
chmod 0755 "$DOCROOT/private" "$DOCROOT/admin"
chmod 0755 /var/www "$DOCROOT"
write_page() {
	cat > "$1" <<HTML
<html>
<head><title>$2</title></head>
<body>
<p>$3</p>
</body>
</html>
HTML
	chmod 0644 "$1"
}
write_page "$DOCROOT/index.html" "Public page" PUBLIC-PAGE-OK
write_page "$DOCROOT/private/index.html" "Private area" PRIVATE-PAGE-OK
write_page "$DOCROOT/admin/index.html" "Admin area" ADMIN-PAGE-OK
restorecon -R /var/www

# The firewall: no http and no 80/tcp in the default zone
zone=$(state_value zone)
for s in service:http port:80/tcp; do
	kind=${s%%:*}
	val=${s#*:}
	firewall-cmd --permanent --zone="$zone" "--remove-$kind=$val" >/dev/null 2>&1 || true
	firewall-cmd --zone="$zone" "--remove-$kind=$val" >/dev/null 2>&1 || true
done
exit 0
