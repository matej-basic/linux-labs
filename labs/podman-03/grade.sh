#!/bin/bash
# podman-03 grader
source /opt/linux-labs/lib/grading.sh

LAB=podman-03
STATE_FILE=/opt/linux-labs/state/$LAB
DB_IMAGE=quay.io/sclorg/mariadb-1011-c9s
WEB_IMAGE=registry.access.redhat.com/ubi9/php-81
ROW='blue widget'

grade_begin podman-03
grade_require_state podman-03 "$STATE_FILE"

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

user=$(state_value user)
token=$(state_value token)
uid=$(id -u "$user" 2>/dev/null)
home=$(getent passwd "$user" | cut -d: -f6)
rt="/run/user/$uid"

# as_user <command...>: run a command as the task user in the user's
# runtime directory and session bus
as_user() {
	[ -n "$uid" ] && [ -d "$rt" ] || return 1
	command -v podman >/dev/null 2>&1 || return 1
	runuser -u "$user" -- env HOME="$home" XDG_RUNTIME_DIR="$rt" \
		DBUS_SESSION_BUS_ADDRESS="unix:path=$rt/bus" "$@" </dev/null 2>/dev/null
}

pod_exists() {
	as_user podman pod exists apppod
}

pod_running() {
	local state
	state=$(as_user podman pod inspect --format '{{.State}}' apppod) || return 1
	[ "$state" = Running ]
}

# Container port 8080/tcp of the pod is published on host port 8082
pod_port() {
	local ports
	# shellcheck disable=SC2016 # a Go template, not a shell expansion
	ports=$(as_user podman pod inspect \
		--format '{{range $p, $b := .InfraConfig.PortBindings}}{{range $b}}{{$p}} {{.HostPort}}{{println}}{{end}}{{end}}' apppod) || return 1
	printf '%s\n' "$ports" | grep -qx '8080/tcp 8082'
}

# in_pod <container>: the container is running and belongs to apppod
in_pod() {
	local pod state cpod
	pod=$(as_user podman pod inspect --format '{{.Id}}' apppod) || return 1
	state=$(as_user podman inspect --type container --format '{{.State.Status}}' "$1") || return 1
	cpod=$(as_user podman inspect --type container --format '{{.Pod}}' "$1") || return 1
	[ "$state" = running ] && [ -n "$pod" ] && [ "$cpod" = "$pod" ]
}

# uses_image <container> <image>: by name, or by the ID of the local image
uses_image() {
	local name cid iid
	name=$(as_user podman inspect --type container --format '{{.ImageName}}' "$1") || return 1
	case "$name" in
	"$2" | "$2:latest") return 0 ;;
	esac
	cid=$(as_user podman inspect --type container --format '{{.Image}}' "$1") || return 1
	iid=$(as_user podman image inspect --format '{{.Id}}' "$2") || return 1
	[ -n "$iid" ] && [ "$cid" = "$iid" ]
}

# has_bind <container> <host dir> <container dir>
has_bind() {
	as_user podman inspect --type container \
		--format '{{range .Mounts}}{{.Type}} {{.Source}} {{.Destination}}{{println}}{{end}}' "$1" |
		sed 's#/* \(/[^ ]*\)$# \1#; s#/*$##' |
		grep -qx "bind $2 $3"
}

db_files() {
	[ -d "$home/dbdata/mysql" ] && [ -d "$home/dbdata/inventory" ]
}

# db_sql <statement>: run SQL as app in inventory over TCP inside db
db_sql() {
	as_user podman exec db mysql -h 127.0.0.1 -P 3306 -u app -pInv3ntory \
		-D inventory -N -B -e "$1"
}

app_login() {
	local out
	out=$(db_sql 'SELECT 1') || return 1
	[ "$out" = 1 ]
}

table_row() {
	local out
	out=$(db_sql 'SELECT name FROM items WHERE id = 1') || return 1
	[ "$out" = "$ROW" ]
}

page_shows_row() {
	local body
	body=$(curl -s -m 10 http://127.0.0.1:8082/ 2>/dev/null) || return 1
	printf '%s\n' "$body" | grep -qxF "$token" || return 1
	printf '%s\n' "$body" | grep -qxF "1 $ROW"
}

# Root has no containers; without root container storage there are none
no_root_containers() {
	[ -e /var/lib/containers/storage ] || return 0
	command -v podman >/dev/null 2>&1 || return 0
	local ids
	ids=$(podman ps -a -q </dev/null 2>/dev/null) || return 1
	[ -z "$ids" ]
}

criterion "Package podman is installed" rpm -q podman
criterion "Pod apppod exists for $user" pod_exists
criterion "Pod apppod is running" pod_running
criterion "Pod apppod publishes port 8080 on host port 8082" pod_port
criterion "Container db is running in pod apppod" in_pod db
criterion "Container db runs from $DB_IMAGE" uses_image db "$DB_IMAGE"
criterion "$home/dbdata is mounted at /var/lib/mysql/data in db" \
	has_bind db "$home/dbdata" /var/lib/mysql/data
criterion "$home/dbdata holds the database files" db_files
criterion "User app can log in to the database inventory" app_login
criterion "Table items has the row 1, $ROW" table_row
criterion "Container web is running in pod apppod" in_pod web
criterion "Container web runs from ubi9/php-81" uses_image web "$WEB_IMAGE"
criterion "$home/podlab is mounted at /opt/app-root/src in web" \
	has_bind web "$home/podlab" /opt/app-root/src
criterion "http://127.0.0.1:8082/ shows the page with the row" page_shows_row
criterion "The root account has no Podman containers" no_root_containers
grade_end
