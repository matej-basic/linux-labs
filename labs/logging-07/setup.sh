#!/bin/bash
# logging-07 setup: the application tree /srv/app, no AIDE database and
# no saved report, and the helper /usr/local/sbin/lab-tamper that the
# student runs once after the AIDE database is in place. On the first
# start the lab takes a package snapshot and, when aide is already
# installed, keeps a copy of /etc/aide.conf and of the AIDE databases
# for cleanup.sh. Prints nothing on success.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=logging-07
STATE_DIR=/opt/linux-labs/state/$LAB
APP=/srv/app
TAMPER=/usr/local/sbin/lab-tamper
REPORT=/root/aide-report.txt

pkg_snapshot "$LAB"

# Record the AIDE files that existed before the lab, on the first start
# only, so that a second start never overwrites them.
if [ ! -f "$STATE_DIR/aide" ]; then
	mkdir -p "$STATE_DIR/saved"
	if rpm -q aide >/dev/null 2>&1; then
		echo installed > "$STATE_DIR/aide"
		if [ -f /etc/aide.conf ]; then
			cp -p /etc/aide.conf "$STATE_DIR/saved/aide.conf"
		fi
		if [ -d /var/lib/aide ]; then
			find /var/lib/aide -mindepth 1 -maxdepth 1 -type f \
				-exec cp -p -t "$STATE_DIR/saved" {} +
		fi
	else
		echo absent > "$STATE_DIR/aide"
	fi
	chmod 700 "$STATE_DIR/saved"
fi

# A restart puts back /etc/aide.conf of an aide that was installed
# before the lab.
if [ -f "$STATE_DIR/saved/aide.conf" ] &&
	! cmp -s "$STATE_DIR/saved/aide.conf" /etc/aide.conf; then
	cp -p "$STATE_DIR/saved/aide.conf" /etc/aide.conf
	restorecon /etc/aide.conf 2>/dev/null || true
fi

# Start without an AIDE database, a report or a previous tamper run.
rm -f /var/lib/aide/aide.db.gz /var/lib/aide/aide.db.new.gz "$REPORT"
rm -f "$STATE_DIR/tampered" "$STATE_DIR/added"

# The application tree.
rm -rf "$APP"
mkdir -p "$APP/bin" "$APP/etc" "$APP/data"
cat > "$APP/bin/appctl" <<'EOF'
#!/bin/bash
# appctl: start and stop the application
case ${1:-} in
start) echo "app started" ;;
stop) echo "app stopped" ;;
*) echo "usage: appctl start|stop" >&2; exit 2 ;;
esac
EOF
cat > "$APP/etc/app.conf" <<'EOF'
# Application settings
listen_address=127.0.0.1
listen_port=8080
admin_user=appadmin
log_level=info
EOF
cat > "$APP/etc/users.conf" <<'EOF'
appadmin:admin
reporter:read
EOF
printf '%s app started\n' "$(date '+%F %T')" > "$APP/data/app.log"
printf 'sessions=0\n' > "$APP/data/cache.dat"
chown -R root:root "$APP"
chmod 755 "$APP" "$APP/bin" "$APP/etc" "$APP/data" "$APP/bin/appctl"
chmod 644 "$APP/etc/app.conf" "$APP/etc/users.conf" \
	"$APP/data/app.log" "$APP/data/cache.dat"
restorecon -R "$APP" 2>/dev/null || true

# The helper that simulates an intruder and normal application activity.
cat > "$TAMPER" <<'EOF'
#!/bin/bash
# lab-tamper (logging-07): change the application tree once, after the
# AIDE database of this lab is in place.
STATE_DIR=/opt/linux-labs/state/logging-07
DB=/var/lib/aide/aide.db.gz
APP=/srv/app

if [ "$(id -u)" -ne 0 ]; then
	echo "Error: run lab-tamper as root." >&2
	exit 1
fi
if [ ! -f "$STATE_DIR/started" ]; then
	echo "Error: lab logging-07 is not started." >&2
	exit 1
fi
if [ -f "$STATE_DIR/tampered" ]; then
	echo "lab-tamper already changed $APP. It runs only once per lab start."
	exit 0
fi
# The generation time AIDE writes into the database, else its mtime.
gen=$(zcat -f "$DB" 2>/dev/null | head -n 5 |
	sed -n 's/^# Time of generation was //p')
if [ -n "$gen" ]; then
	gen=$(date -d "$gen" +%s 2>/dev/null)
elif [ -f "$DB" ]; then
	gen=$(stat -c %Y "$DB")
fi
if [ -z "$gen" ] || [ "$gen" -lt "$(cat "$STATE_DIR/started")" ]; then
	echo "Error: there is no AIDE database from this lab in $DB." >&2
	echo "Initialise the database and put it in place first." >&2
	exit 1
fi

date +%s > "$STATE_DIR/tampered"
sed -i 's/^listen_address=.*/listen_address=0.0.0.0/' "$APP/etc/app.conf"
sed -i 's/^admin_user=.*/admin_user=root/' "$APP/etc/app.conf"
chmod 4755 "$APP/bin/appctl"
added=$APP/bin/.appctl-helper
printf '#!/bin/bash\nexec /bin/bash -p\n' > "$added"
chmod 755 "$added"
echo "$added" > "$STATE_DIR/added"
chmod 644 "$STATE_DIR/tampered" "$STATE_DIR/added"
# Normal application activity.
printf '%s session opened\n' "$(date '+%F %T')" >> "$APP/data/app.log"
printf 'sessions=1\n' > "$APP/data/cache.dat"
printf 'id=%s\n' "$RANDOM" > "$APP/data/session-1.tmp"
echo "lab-tamper changed $APP."
EOF
chown root:root "$TAMPER"
chmod 755 "$TAMPER"
restorecon "$TAMPER" 2>/dev/null || true

date +%s > "$STATE_DIR/started"
chmod 755 "$STATE_DIR"
chmod 644 "$STATE_DIR/aide" "$STATE_DIR/started"
