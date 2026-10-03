#!/bin/bash
# webserver-04 setup: start without nginx, with a small backend
# application on 127.0.0.1:8081 that nginx is to publish over HTTPS.
# Prints nothing on success.
#
# The backend is /srv/webapp/app.py, run by the lab-owned unit
# webapp.service as nobody: / returns a page with a marker, /headers
# returns the request headers it received, one per line. It runs with
# the system Python (/usr/libexec/platform-python on Rocky 8, where a
# minimal install has no python3), so setup installs no interpreter.
#
# setup installs policycoreutils-python-utils if it is missing, so that
# semanage is there for the student and for cleanup.sh; pkg_restore
# removes it again.
#
# The first run records the package set (pkg_snapshot), the firewall
# zone of the default-route interface and which of the services http
# and https and the ports 80/tcp and 443/tcp were open in it, the
# SELinux boolean httpd_can_network_connect (now and persistent), the
# local boolean and port customizations, and an nginx that was
# installed before the lab: its files go to
# /opt/linux-labs/state/webserver-04.d with its service state, and
# cleanup.sh puts them back after pkg_restore has installed it again.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=webserver-04
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
BACKUP_DIR="$STATE_DIR/$LAB.d"
APP_DIR=/srv/webapp
UNIT=/etc/systemd/system/webapp.service
CRT=/etc/pki/tls/certs/app.lab.local.crt
KEY=/etc/pki/tls/private/app.lab.local.key
BOOL=httpd_can_network_connect
SEL=/var/lib/selinux/targeted/active
# Files and directories of the nginx packages (Rocky 8 and 9 layouts)
paths="etc/nginx var/log/nginx var/lib/nginx var/cache/nginx"
pkgs="nginx nginx-core nginx-filesystem nginx-all-modules"

if ! command -v getenforce >/dev/null 2>&1 || [ "$(getenforce)" = Disabled ]; then
	echo "Error: SELinux is disabled; this lab needs SELinux enabled." >&2
	exit 1
fi
if ! command -v firewall-cmd >/dev/null 2>&1 \
	|| ! systemctl is-active --quiet firewalld 2>/dev/null; then
	echo "Error: firewalld is not running on this machine." >&2
	exit 1
fi

python=
for p in /usr/bin/python3 /usr/libexec/platform-python; do
	if [ -x "$p" ]; then
		python=$p
		break
	fi
done
if [ -z "$python" ]; then
	echo "Error: no Python 3 interpreter found for the backend." >&2
	exit 1
fi

dev=$(ip -4 route show default 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
zone=
[ -n "$dev" ] && zone=$(firewall-cmd --get-zone-of-interface="$dev" 2>/dev/null || true)
[ -n "$zone" ] || zone=$(firewall-cmd --get-default-zone)

pkg_snapshot "$LAB"

# semanage, for the student and for cleanup.sh
if ! rpm -q policycoreutils-python-utils >/dev/null 2>&1; then
	if ! out=$(dnf -y -q install policycoreutils-python-utils </dev/null 2>&1); then
		printf '%s\n' "$out" >&2
		echo "Error: could not install policycoreutils-python-utils." >&2
		exit 1
	fi
fi

# The persistent value of the boolean in the policy store
bool_saved() {
	semanage boolean -l 2>/dev/null |
		awk -v b="$BOOL" '$1 == b { gsub(/[(),]/, " "); print $3 }'
}

# First run only: what the machine looked like before the lab
if [ ! -r "$STATE_FILE" ]; then
	rm -rf "$BACKUP_DIR"
	mkdir -p "$STATE_DIR"
	fw_open=
	for s in http https; do
		firewall-cmd --permanent --zone="$zone" --query-service="$s" >/dev/null 2>&1 \
			&& fw_open="$fw_open p:service:$s"
		firewall-cmd --zone="$zone" --query-service="$s" >/dev/null 2>&1 \
			&& fw_open="$fw_open r:service:$s"
	done
	for s in 80/tcp 443/tcp; do
		firewall-cmd --permanent --zone="$zone" --query-port="$s" >/dev/null 2>&1 \
			&& fw_open="$fw_open p:port:$s"
		firewall-cmd --zone="$zone" --query-port="$s" >/dev/null 2>&1 \
			&& fw_open="$fw_open r:port:$s"
	done
	# The boolean now and in the policy store, whether the boolean
	# had a local customization and whether any boolean had one
	bool_now=$(getsebool "$BOOL" 2>/dev/null | awk '{ print $3 }')
	bool_saved=$(bool_saved)
	bool_local=no
	grep -q "^$BOOL=" "$SEL/booleans.local" 2>/dev/null && bool_local=yes
	bools_local=no
	grep -q '^[^#]' "$SEL/booleans.local" 2>/dev/null && bools_local=yes
	port_local=no
	grep -Eq '^portcon[[:space:]]+tcp[[:space:]]+8081[[:space:]]' "$SEL/ports.local" 2>/dev/null \
		&& port_local=yes
	nginx_pre=no
	if rpm -q nginx >/dev/null 2>&1; then
		nginx_pre=yes
		mkdir -m 0700 "$BACKUP_DIR"
		systemctl is-enabled --quiet nginx 2>/dev/null && touch "$BACKUP_DIR/enabled"
		systemctl is-active --quiet nginx 2>/dev/null && touch "$BACKUP_DIR/active"
		systemctl stop nginx >/dev/null 2>&1 || true
		keep=""
		for p in $paths; do
			[ -e "/$p" ] && keep="$keep $p"
		done
		if [ -n "$keep" ]; then
			# shellcheck disable=SC2086 # word splitting is intended
			tar --selinux --xattrs --acls -C / -cpf "$BACKUP_DIR/files.tar" $keep
		fi
	fi
	tmp="$STATE_FILE.tmp"
	{
		echo "zone=$zone"
		echo "fw_open=$fw_open"
		echo "bool_now=$bool_now"
		echo "bool_saved=$bool_saved"
		echo "bool_local=$bool_local"
		echo "bools_local=$bools_local"
		echo "port_local=$port_local"
		echo "nginx_pre=$nginx_pre"
	} > "$tmp"
	chmod 644 "$tmp"
	mv "$tmp" "$STATE_FILE"
fi

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# No nginx, as the task starts
systemctl disable --now nginx >/dev/null 2>&1 || true
remove=
for p in $pkgs; do
	rpm -q "$p" >/dev/null 2>&1 && remove="$remove $p"
done
if [ -n "$remove" ]; then
	# shellcheck disable=SC2086 # word splitting is intended
	dnf -y remove $remove </dev/null >/dev/null 2>&1 || {
		echo "Error: could not remove the nginx packages." >&2
		exit 1
	}
fi

# Configuration, logs and certificate of the removed nginx or of an
# earlier attempt (an nginx from before the lab is saved in $BACKUP_DIR)
for p in $paths; do
	if [ -e "/$p" ] && ! rpm -qf "/$p" >/dev/null 2>&1; then
		rm -rf "/${p:?}"
	fi
done
rm -f /run/nginx.pid "$CRT" "$KEY"
sed -i '/app\.lab\.local/d' /etc/hosts

# The SELinux permission starts as it was before the lab: a port label
# for 8081 and a local boolean customization of an earlier attempt go
if [ "$(state_value port_local)" = no ]; then
	t=$(semanage port -l -C 2>/dev/null |
		awk '$2 == "tcp" && /[[:space:],]8081(,|[[:space:]]|$)/ { print $1; exit }')
	if [ -n "$t" ]; then
		semanage port -d -t "$t" -p tcp 8081 >/dev/null 2>&1 || true
	fi
fi
if [ "$(state_value bool_local)" = no ] && [ "$(state_value bools_local)" = no ] &&
	[ "$(grep '^[^#]' "$SEL/booleans.local" 2>/dev/null | cut -d= -f1)" = "$BOOL" ]; then
	semanage boolean -D >/dev/null 2>&1 || true
fi
want=$(state_value bool_saved)
if [ -n "$want" ] && [ "$(bool_saved)" != "$want" ]; then
	setsebool -P "$BOOL" "$want"
fi
setsebool "$BOOL" off

# Firewall openings of an earlier attempt, unless they were there before
zone=$(state_value zone)
fw_open=" $(state_value fw_open) "
for s in service:http service:https port:80/tcp port:443/tcp; do
	kind=${s%%:*}
	val=${s#*:}
	case "$fw_open" in
	*" p:$s "*) ;;
	*) firewall-cmd --permanent --zone="$zone" "--remove-$kind=$val" >/dev/null 2>&1 || true ;;
	esac
	case "$fw_open" in
	*" r:$s "*) ;;
	*) firewall-cmd --zone="$zone" "--remove-$kind=$val" >/dev/null 2>&1 || true ;;
	esac
done

for port in 80 443 8081; do
	if [ -n "$(ss -H -tln "sport = :$port" 2>/dev/null)" ]; then
		systemctl stop webapp >/dev/null 2>&1 || true
		if [ -n "$(ss -H -tln "sport = :$port" 2>/dev/null)" ]; then
			echo "Error: another service already listens on TCP port $port." >&2
			exit 1
		fi
	fi
done

# The backend application
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cat > "$APP_DIR/app.py" <<'APP'
# webserver-04 backend: listens on 127.0.0.1:8081 only.
# GET /         a page with the text "webapp backend is up"
# GET /headers  the request headers as received, one per line
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn


class Handler(BaseHTTPRequestHandler):
    def reply(self, send_body):
        if self.path.split("?")[0] == "/headers":
            body = "".join("%s: %s\n" % (k, v) for k, v in self.headers.items())
            ctype = "text/plain; charset=utf-8"
        else:
            body = ("<html><head><title>webapp</title></head><body>\n"
                    "<p>webapp backend is up</p>\n</body></html>\n")
            ctype = "text/html; charset=utf-8"
        data = body.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if send_body:
            self.wfile.write(data)

    def do_GET(self):
        self.reply(True)

    def do_HEAD(self):
        self.reply(False)

    def log_message(self, *args):
        pass


class Server(ThreadingMixIn, HTTPServer):
    daemon_threads = True


Server(("127.0.0.1", 8081), Handler).serve_forever()
APP
chmod 0755 "$APP_DIR"
chmod 0644 "$APP_DIR/app.py"
restorecon -R "$APP_DIR" >/dev/null 2>&1 || true

cat > "$UNIT" <<UNIT
[Unit]
Description=webserver-04 backend application on 127.0.0.1:8081
After=network.target

[Service]
User=nobody
ExecStart=$python $APP_DIR/app.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
chmod 0644 "$UNIT"
restorecon "$UNIT" >/dev/null 2>&1 || true
systemctl daemon-reload
systemctl enable webapp >/dev/null 2>&1
systemctl restart webapp

for _ in 1 2 3 4 5 6 7 8 9 10; do
	if curl -s --max-time 2 http://127.0.0.1:8081/ 2>/dev/null | grep -q 'webapp backend is up'; then
		exit 0
	fi
	sleep 1
done
echo "Error: the backend application does not answer on 127.0.0.1:8081." >&2
exit 1
