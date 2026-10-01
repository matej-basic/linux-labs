#!/bin/bash
# Reference solution for lb-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# The nodes are reset by labctl reset; no path on this host needs checking.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 7 [user]. load-config.sh does not work under "set -u", and
# every run_on_node call gets its own stdin so ssh cannot eat the script.
run_as_student <<'STEPS'
set +u
source /opt/linux-labs/lib/load-config.sh
set -u
rn() { run_on_node "$@" </dev/null; }
N1=$(get_node_ip 1); N2=$(get_node_ip 2); N3=$(get_node_ip 3)

# Step 2
rn "$N1" "sudo -n dnf -y install haproxy httpd"
rn "$N2" "sudo -n dnf -y install httpd"
rn "$N3" "sudo -n dnf -y install httpd"

# Step 3
i=0
for ip in "$N1" "$N2" "$N3"; do
  i=$((i + 1))
  rn "$ip" "sudo -n sed -i 's/^Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf"
  rn "$ip" "echo 'Backend on node $i' | sudo -n tee /var/www/html/index.html"
  rn "$ip" "sudo -n systemctl enable --now httpd"
done

# Step 4
rn "$N1" "sudo -n firewall-cmd --permanent --add-service=http"
for ip in "$N2" "$N3"; do
  rn "$ip" "sudo -n firewall-cmd --permanent --add-port=8080/tcp"
done
for ip in "$N1" "$N2" "$N3"; do
  rn "$ip" "sudo -n firewall-cmd --reload"
done

# Step 5
rn "$N1" "sudo -n setsebool -P haproxy_connect_any on"

# Step 6
CFG=$(mktemp)
cat > "$CFG" <<CONF
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    timeout connect         10s
    timeout client          1m
    timeout server          1m

frontend web_frontend
    bind *:80
    default_backend web_servers

backend web_servers
    balance roundrobin
    option httpchk GET /
    server node1 $N1:8080 check
    server node2 $N2:8080 check
    server node3 $N3:8080 check
CONF
run_on_node "$N1" "sudo -n tee /etc/haproxy/haproxy.cfg >/dev/null" < "$CFG"
rm -f "$CFG"
rn "$N1" "sudo -n haproxy -c -f /etc/haproxy/haproxy.cfg"

# Step 7
rn "$N1" "sudo -n systemctl enable --now haproxy"

# Verification: wait until HAProxy has marked the backends up
for t in $(seq 30); do
  curl -fs --max-time 5 "http://$N1/" >/dev/null && break
  sleep 1
done
STEPS
