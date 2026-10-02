#!/bin/bash
# Reference solution for podman-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package podman
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q podman >/dev/null || dnf -y install podman >/dev/null

# Steps 2 to 5 [user]. runuser has no systemd session, so the
# environment of an SSH login is set by hand.
run_as_student <<'STEPS'
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

cd ~/webimg
cat >Containerfile <<'END'
FROM registry.access.redhat.com/ubi9/httpd-24
LABEL version="1.0"
ENV APP_ENV=production
COPY index.html /var/www/html/index.html
END

podman build -t localhost/webapp:1.0 . </dev/null >/dev/null

podman volume create webdata </dev/null >/dev/null
podman run -d --name web -p 8081:8080 \
  -v webdata:/var/www/data --restart always \
  localhost/webapp:1.0 </dev/null >/dev/null

for _ in 1 2 3 4 5 6 7 8 9 10; do
  curl -sf http://localhost:8081 >/dev/null && break
  sleep 1
done
curl -sf http://localhost:8081
STEPS
