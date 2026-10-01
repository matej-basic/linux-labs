#!/bin/bash
# Reference solution for lb-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# The work happens on nodes 1 to 3 over SSH (run_on_node); the workstation
# only holds the state file, which labctl reset removes.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# load-config.sh reads variables that may be unset
set +u
source /opt/linux-labs/lib/load-config.sh
set -u

NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)
VIP=$(head -n 1 /opt/linux-labs/state/lb-03)

SUDO=""
[ "${SSH_USER:-root}" = root ] || SUDO="sudo "

# node_script <ip> <assignments>: run the script on standard input on the
# node, after the variable assignments given as the second argument
node_script() {
	local ip="$1" pre="$2" payload
	payload=$({
		echo "set -euo pipefail"
		echo "$pre"
		cat
	} | base64 | tr -d '\n')
	run_on_node "$ip" "${SUDO}bash -c \"\$(echo $payload | base64 -d)\"" </dev/null
}

# Step 1 [sudo]: httpd on all three nodes
n=0
for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
	n=$((n + 1))
	node_script "$ip" "N=$n" <<'STEP'
dnf -y install httpd
sed -i 's/^Listen 80$/Listen 8080/' /etc/httpd/conf/httpd.conf
echo "Backend Server - Node $N" > /var/www/html/index.html
systemctl enable --now httpd
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload
STEP
done

# Steps 2 and 3 [sudo]: HAProxy on nodes 1 and 2
for ip in "$NODE1_IP" "$NODE2_IP"; do
	node_script "$ip" "NODE1_IP=$NODE1_IP NODE2_IP=$NODE2_IP NODE3_IP=$NODE3_IP" <<'STEP'
dnf -y install haproxy keepalived
setsebool -P haproxy_connect_any 1
cat > /etc/haproxy/haproxy.cfg <<EOF
global
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

defaults
    mode                    http
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
    server node1 $NODE1_IP:8080 check
    server node2 $NODE2_IP:8080 check
    server node3 $NODE3_IP:8080 check
EOF
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-protocol=vrrp
firewall-cmd --reload
systemctl enable --now haproxy
STEP
done

# Steps 4 and 5 [sudo]: keepalived, node 1 MASTER/100, node 2 BACKUP/90
i=0
for ip in "$NODE1_IP" "$NODE2_IP"; do
	i=$((i + 1))
	if [ "$i" -eq 1 ]; then
		vars="STATE=MASTER PRIO=100"
	else
		vars="STATE=BACKUP PRIO=90"
	fi
	node_script "$ip" "NODE_IP=$ip VIP=$VIP $vars" <<'STEP'
read -r IFACE CIDR < <(ip -o -4 addr show | awk -v ip="$NODE_IP" \
  'index($4, ip "/") == 1 { print $2, $4; exit }')
cat > /etc/keepalived/keepalived.conf <<EOF
vrrp_script check_haproxy {
    script "/usr/bin/pgrep -x haproxy"
    interval 2
    weight -20
}

vrrp_instance VI_1 {
    state $STATE
    interface $IFACE
    virtual_router_id 51
    priority $PRIO
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass Secret12
    }
    virtual_ipaddress {
        $VIP/${CIDR#*/}
    }
    track_script {
        check_haproxy
    }
}
EOF
systemctl enable --now keepalived
STEP
done
