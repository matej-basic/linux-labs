#!/bin/bash
# podman-02 grader
source /opt/linux-labs/lib/grading.sh

LAB=podman-02
STATE_FILE=/opt/linux-labs/state/$LAB
IMAGE=localhost/webapp:1.0

grade_begin podman-02
grade_require_state podman-02 "$STATE_FILE"

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

# The Containerfile names the base image in a FROM instruction
containerfile_from() {
	grep -Eiq '^[[:space:]]*FROM[[:space:]]+(--[^[:space:]]+[[:space:]]+)*registry\.access\.redhat\.com/ubi9/httpd-24(:latest)?([[:space:]]|$)' \
		"$home/webimg/Containerfile" 2>/dev/null
}

image_exists() {
	as_user podman image exists "$IMAGE"
}

# The image inherits the component label of ubi9/httpd-24
image_from_base() {
	local comp
	comp=$(as_user podman image inspect --format '{{index .Labels "com.redhat.component"}}' "$IMAGE") || return 1
	[ "$comp" = httpd-24-container ]
}

image_label() {
	local v
	v=$(as_user podman image inspect --format '{{index .Labels "version"}}' "$IMAGE") || return 1
	[ "$v" = 1.0 ]
}

image_env() {
	as_user podman image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$IMAGE" |
		grep -qx 'APP_ENV=production'
}

# A fresh container of the image, without network, prints the page
image_has_page() {
	local body
	body=$(as_user podman run --rm --network none --entrypoint cat "$IMAGE" /var/www/html/index.html) || return 1
	[ "$body" = "$token" ]
}

container_image() {
	local cid iid
	iid=$(as_user podman image inspect --format '{{.Id}}' "$IMAGE") || return 1
	cid=$(as_user podman inspect --type container --format '{{.Image}}' web) || return 1
	[ -n "$iid" ] && [ "$cid" = "$iid" ]
}

container_running() {
	local state
	state=$(as_user podman inspect --type container --format '{{.State.Status}}' web) || return 1
	[ "$state" = running ]
}

# Container port 8080/tcp is published on host port 8081, and only there
container_port() {
	local ports
	# shellcheck disable=SC2016 # a Go template, not a shell expansion
	ports=$(as_user podman inspect --type container \
		--format '{{range $p, $b := .HostConfig.PortBindings}}{{range $b}}{{$p}} {{.HostPort}}{{println}}{{end}}{{end}}' web) || return 1
	printf '%s\n' "$ports" | grep -qx '8080/tcp 8081'
}

container_volume() {
	as_user podman volume exists webdata || return 1
	as_user podman inspect --type container \
		--format '{{range .Mounts}}{{.Type}} {{.Name}} {{.Destination}}{{println}}{{end}}' web |
		grep -qx 'volume webdata /var/www/data'
}

container_restart() {
	local policy
	policy=$(as_user podman inspect --type container --format '{{.HostConfig.RestartPolicy.Name}}' web) || return 1
	[ "$policy" = always ]
}

serves_page() {
	local body
	body=$(curl -s -m 5 http://localhost:8081/ 2>/dev/null) || return 1
	[ "$body" = "$token" ]
}

criterion "Package podman is installed" rpm -q podman
criterion "$home/webimg/Containerfile is based on ubi9/httpd-24" containerfile_from
criterion "Image $IMAGE exists for $user" image_exists
criterion "Image $IMAGE is built on ubi9/httpd-24" image_from_base
criterion "Image $IMAGE has the label version=1.0" image_label
criterion "Image $IMAGE has the variable APP_ENV=production" image_env
criterion "Image $IMAGE contains the page in /var/www/html" image_has_page
criterion "Container web of $user runs from $IMAGE" container_image
criterion "Container web is running" container_running
criterion "Container port 8080 is published on host port 8081" container_port
criterion "Volume webdata is mounted at /var/www/data in web" container_volume
criterion "Container web has the restart policy always" container_restart
criterion "http://localhost:8081 serves the page from the image" serves_page
grade_end
