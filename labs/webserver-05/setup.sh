#!/bin/bash
# webserver-05 setup: an Apache intranet site that does not load. The
# virtual host /etc/httpd/conf.d/intranet.conf serves /srv/intranet on
# port 80, and several faults are present at the same time:
#   - /etc/httpd/conf.d/status.conf adds Listen 8089, a port without an
#     SELinux port type: httpd -t passes, but httpd fails to start
#   - index.html has mode 0600 and belongs to root
#   - /srv/intranet was built in /root and moved, so it keeps the type
#     admin_home_t, and there is no file context rule for it
#   - the service http (and port 80/tcp) is not open in the default
#     firewalld zone, at runtime and permanently
#   - httpd is disabled (setup tries to start it once, so the failure
#     is in the journal)
# Prints nothing on success.
#
# The first run records the package set (pkg_snapshot), the firewall
# state of http and 80/tcp in the default zone, the httpd service state,
# the SELinux mode in /etc/selinux/config, the policy modules, the
# SELinux booleans and the local SELinux customizations (semanage
# export). Every run writes the checksums of the page and of the
# virtual host file to the state file for the grader.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=webserver-05
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
SITE=/srv/intranet
BUILD=/root/intranet
VHOST=/etc/httpd/conf.d/intranet.conf
STATUS=/etc/httpd/conf.d/status.conf

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

if ! { rpm -q httpd >/dev/null 2>&1 &&
	rpm -q policycoreutils-python-utils >/dev/null 2>&1; }; then
	# dnf reports a repo key import on stderr; show its output only
	# when the install fails
	if ! out=$(dnf -y -q install httpd policycoreutils-python-utils \
		</dev/null 2>&1); then
		printf '%s\n' "$out" >&2
		echo "Error: could not install httpd and" \
			"policycoreutils-python-utils." >&2
		exit 1
	fi
fi

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# First run only: what the machine looked like before the lab
if [ ! -r "$STATE_FILE" ]; then
	rm -rf "$REC_DIR"
	mkdir -p "$STATE_DIR"
	mkdir -m 0755 "$REC_DIR"
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
	was_enabled=no
	was_active=no
	systemctl is-enabled --quiet httpd 2>/dev/null && was_enabled=yes
	systemctl is-active --quiet httpd 2>/dev/null && was_active=yes
	selinux_cfg=$(sed -n 's/^SELINUX=//p' /etc/selinux/config | head -n 1)
	modules=$(semodule -l | awk '{ print $1 }' | sort | tr '\n' ' ')
	semanage export > "$REC_DIR/semanage.export"
	getsebool -a > "$REC_DIR/booleans"
	chmod 0644 "$REC_DIR/semanage.export" "$REC_DIR/booleans"
	tmp="$STATE_FILE.tmp"
	{
		echo "zone=$zone"
		echo "fw_open=$fw_open"
		echo "httpd_was_enabled=$was_enabled"
		echo "httpd_was_active=$was_active"
		echo "selinux_cfg=$selinux_cfg"
		echo "modules=$modules"
	} > "$tmp"
	chmod 0644 "$tmp"
	mv "$tmp" "$STATE_FILE"
fi

# Put the local SELinux customizations (file context and port rules,
# booleans) back to the recorded state, and remove policy modules that
# were added at priority 400 since the first start (audit2allow modules,
# permissive domains)
selinux_restore() {
	local rec="$REC_DIR/semanage.export" now line m before
	[ -r "$rec" ] || return 0
	now=$(semanage export 2>/dev/null) || return 0
	# Rules added since the first start go, rules removed come back
	printf '%s\n' "$now" | grep -E '^(fcontext|port) -a ' |
		grep -vxF -f "$rec" | sed 's/^\([a-z]*\) -a /\1 -d /' |
		while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	grep -E '^(fcontext|port) -a ' "$rec" |
		grep -vxF -f <(printf '%s\n' "$now") |
		while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	# Booleans: the persistent values, then the runtime values
	if [ "$(printf '%s\n' "$now" | grep '^boolean -m ' | sort)" != \
		"$(grep '^boolean -m ' "$rec" | sort)" ]; then
		semanage boolean -D >/dev/null 2>&1 || true
		grep '^boolean -m ' "$rec" | while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	fi
	getsebool -a 2>/dev/null | grep -vxF -f "$REC_DIR/booleans" |
		awk '{ print $1 }' | while read -r m; do
			line=$(awk -v b="$m" '$1 == b { print $3 }' "$REC_DIR/booleans")
			[ -n "$line" ] && setsebool "$m" "$line" >/dev/null 2>&1
			true
		done
	before=$(state_value modules)
	for m in $(semodule -lfull 2>/dev/null | awk '$1 == 400 { print $2 }'); do
		case " $before " in
		*" $m "*) ;;
		*) semodule -X 400 -r "$m" >/dev/null 2>&1 || true ;;
		esac
	done
}

# Reset what a previous run or the solution left behind
systemctl disable --now httpd >/dev/null 2>&1 || true
systemctl reset-failed httpd >/dev/null 2>&1 || true
rm -f "$VHOST" "$STATUS"
rm -rf "$SITE" "$BUILD"
selinux_restore
setenforce 1
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

if [ -n "$(ss -H -tln 'sport = :80' 2>/dev/null)" ]; then
	echo "Error: another service already listens on TCP port 80." >&2
	exit 1
fi
if semanage port -l 2>/dev/null | awk '$2 == "tcp"' |
	grep -Eq '[[:space:],]8089(,|[[:space:]]|$)'; then
	echo "Error: TCP port 8089 already has an SELinux port type." >&2
	exit 1
fi

# The site, built in /root and moved into place: it keeps the type
# admin_home_t of /root
mkdir -m 0755 "$BUILD"
cat > "$BUILD/index.html" <<'HTML'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Lab intranet</title>
</head>
<body>
<h1>Welcome to the lab intranet</h1>
<p>Notices for staff of the lab network.</p>
<ul>
<li>The workstations are patched every Monday at 06:00.</li>
<li>Report problems with servera to the operations team.</li>
</ul>
</body>
</html>
HTML
chown -R root:root "$BUILD"
chmod 0600 "$BUILD/index.html"
mv "$BUILD" "$SITE"

cat > "$VHOST" <<'CONF'
# Intranet site
<VirtualHost *:80>
    ServerName intranet
    DocumentRoot /srv/intranet

    <Directory /srv/intranet>
        Options None
        AllowOverride None
        Require all granted
    </Directory>

    ErrorLog /var/log/httpd/intranet_error.log
    CustomLog /var/log/httpd/intranet_access.log combined
</VirtualHost>
CONF

cat > "$STATUS" <<'CONF'
# Server status for the monitoring agent on this host
Listen 8089
<VirtualHost *:8089>
    <Location /server-status>
        SetHandler server-status
        Require ip 127.0.0.1 ::1
    </Location>
</VirtualHost>
CONF
chmod 0644 "$VHOST" "$STATUS"
restorecon "$VHOST" "$STATUS"

# The firewall: no http and no 80/tcp in the default zone
zone=$(state_value zone)
for s in service:http port:80/tcp; do
	kind=${s%%:*}
	val=${s#*:}
	firewall-cmd --permanent --zone="$zone" "--remove-$kind=$val" >/dev/null 2>&1 || true
	firewall-cmd --zone="$zone" "--remove-$kind=$val" >/dev/null 2>&1 || true
done

# The checksums the grader compares
tmp="$STATE_FILE.tmp"
{
	grep -v '^sum_' "$STATE_FILE"
	echo "sum_page=$(sha256sum "$SITE/index.html" | awk '{ print $1 }')"
	echo "sum_vhost=$(sha256sum "$VHOST" | awk '{ print $1 }')"
} > "$tmp"
chmod 0644 "$tmp"
mv "$tmp" "$STATE_FILE"

# httpd was tried once and failed; it stays disabled
if systemctl start httpd >/dev/null 2>&1; then
	systemctl stop httpd >/dev/null 2>&1 || true
	echo "Error: httpd started although it should fail." >&2
	exit 1
fi
systemctl disable httpd >/dev/null 2>&1 || true
exit 0
