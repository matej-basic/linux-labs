#!/bin/bash
# Reference solution for podman-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package podman
# solve: path /srv/webapp
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q podman >/dev/null || dnf -y install podman >/dev/null

# Step 2 [sudo]
loginctl enable-linger "$SOLVE_USER"
uid=$(id -u "$SOLVE_USER")
for _ in $(seq 1 30); do
	[ -S "/run/user/$uid/bus" ] && break
	sleep 1
done

# Steps 3 to 5 [user]. runuser has no systemd session, so the
# environment of an SSH login is set by hand.
run_as_student <<STEPS
export XDG_RUNTIME_DIR=/run/user/$uid
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus
podman run -d --name webapp -p 8080:8080 \\
  -v /srv/webapp:/var/www/html:Z \\
  registry.access.redhat.com/ubi9/httpd-24 >/dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do
  curl -sf http://localhost:8080 >/dev/null && break
  sleep 1
done
curl -sf http://localhost:8080

mkdir -p ~/.config/systemd/user
cd ~/.config/systemd/user
podman generate systemd --new --name webapp --files

podman rm -f webapp >/dev/null
systemctl --user daemon-reload
systemctl --user enable --now container-webapp.service
for _ in 1 2 3 4 5 6 7 8 9 10; do
  curl -sf http://localhost:8080 >/dev/null && break
  sleep 1
done
STEPS
