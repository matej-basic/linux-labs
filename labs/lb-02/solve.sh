#!/bin/bash
# Reference solution for lb-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# The packages are installed on the nodes; test-lab.sh checks the package
# set of every node after reset.
#
# solve: package httpd
# solve: package nginx
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"
source /opt/linux-labs/lib/load-config.sh

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)
N3=$(get_node_ip 3)

# Steps 1 to 4 [sudo]: backends
for n in 2 3; do
	ip=$(get_node_ip "$n")
	run_on_node "$ip" "sudo -n env NODE=$n bash -s" <<'REMOTE'
set -e
rpm -q httpd >/dev/null || dnf -y install httpd >/dev/null
sed -i 's/^Listen 80$/Listen 8080/' /etc/httpd/conf/httpd.conf
firewall-cmd --permanent --add-port=8080/tcp >/dev/null
firewall-cmd --reload >/dev/null
echo "Backend Server - Node $NODE" > /var/www/html/index.html
echo "OK" > /var/www/html/health
systemctl enable --now httpd
REMOTE
done

# Steps 5 to 8 [sudo]: proxy
run_on_node "$N1" "sudo -n env NODE2_IP=$N2 NODE3_IP=$N3 bash -s" <<'REMOTE'
set -e
rpm -q nginx >/dev/null || dnf -y install nginx >/dev/null
sed -i '/^    server {/,/^    }/ s/^/#/' /etc/nginx/nginx.conf
cat > /etc/nginx/conf.d/lb.conf <<CONF
upstream backend_servers {
    least_conn;
    server $NODE2_IP:8080 max_fails=3 fail_timeout=30s;
    server $NODE3_IP:8080 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

server {
    listen 80 default_server;
    server_name _;
    access_log /var/log/nginx/lb_access.log;
    error_log /var/log/nginx/lb_error.log;

    location / {
        proxy_pass http://backend_servers;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_connect_timeout 5s;
    }
}
CONF
nginx -t
setsebool -P httpd_can_network_connect 1
firewall-cmd --permanent --add-service=http >/dev/null
firewall-cmd --reload >/dev/null
systemctl enable --now nginx
REMOTE

# Steps 9 and 10: test and failover
run_on_node "$N1" 'for i in 1 2 3 4; do curl -sf http://127.0.0.1/; done'
