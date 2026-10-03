#!/bin/bash
# Reference solution for podman-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package podman
# solve: path /home/opsadmin/dbdata
# solve: path /home/opsadmin/podlab
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q podman >/dev/null || dnf -y install podman >/dev/null

# Steps 2 to 6 [user]. runuser has no systemd session, so the
# environment of an SSH login is set by hand.
run_as_student <<'STEPS'
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

# Step 2
podman pod create --name apppod -p 8082:8080 </dev/null >/dev/null

# Step 3
mkdir -p ~/dbdata
podman unshare chown 27:27 ~/dbdata </dev/null
podman run -d --pod apppod --name db \
  -e MYSQL_DATABASE=inventory -e MYSQL_USER=app \
  -e MYSQL_PASSWORD=Inv3ntory \
  -v ~/dbdata:/var/lib/mysql/data:Z \
  quay.io/sclorg/mariadb-1011-c9s </dev/null >/dev/null

# Step 4: the server needs a few seconds for its first start
for _ in $(seq 1 60); do
  podman exec db mysql -h 127.0.0.1 -u app -pInv3ntory inventory \
    -e 'SELECT 1' </dev/null >/dev/null 2>&1 && break
  sleep 2
done
podman exec db mysql -h 127.0.0.1 -u app -pInv3ntory inventory -e "
  CREATE TABLE items (id INT PRIMARY KEY, name VARCHAR(64));
  INSERT INTO items VALUES (1, 'blue widget');" </dev/null

# Step 5
podman run -d --pod apppod --name web \
  -v ~/podlab:/opt/app-root/src:Z \
  registry.access.redhat.com/ubi9/php-81 /usr/libexec/s2i/run \
  </dev/null >/dev/null

# Step 6
for _ in $(seq 1 30); do
  curl -sf http://127.0.0.1:8082/ | grep -x '1 blue widget' >/dev/null && break
  sleep 1
done
curl -sf http://127.0.0.1:8082/
STEPS
