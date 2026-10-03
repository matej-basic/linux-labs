#!/bin/bash
# Reference solution for redis-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package redis
# solve: path /var/lib/redis
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q redis >/dev/null || dnf -y install redis >/dev/null

# Step 2 [sudo]
conf=/etc/redis.conf
[ -f /etc/redis/redis.conf ] && conf=/etc/redis/redis.conf
addr=$(sed -n 's/^address=//p' /opt/linux-labs/state/redis-01)
tee -a "$conf" >/dev/null <<END
bind 127.0.0.1 $addr
requirepass labredis42
appendonly yes
maxmemory 128mb
maxmemory-policy allkeys-lru
END

# Step 3 [sudo]
systemctl enable --now redis

# Step 4 [sudo]
firewall-cmd --permanent --add-port=6379/tcp >/dev/null
firewall-cmd --reload >/dev/null

# Step 5 [user]
run_as_student 'REDISCLI_AUTH=labredis42 redis-cli SET lab:status ready'
