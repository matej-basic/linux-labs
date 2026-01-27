# Load Balancing 01 Solution - HAProxy Basic Setup

## Overview
This solution sets up HAProxy on Node 1 to load balance HTTP requests across 3 Apache web servers running on all three nodes.

## Step 1: Install HAProxy on Node 1

```bash
# On Node 1
sudo dnf install -y haproxy
```

## Step 2: Install Apache on All Nodes

```bash
# On all 3 nodes
sudo dnf install -y httpd

# Configure Apache to listen on port 8080
sudo sed -i 's/^Listen 80$/Listen 8080/' /etc/httpd/conf/httpd.conf

# Start and enable Apache
sudo systemctl start httpd
sudo systemctl enable httpd
```

## Step 3: Create Unique Content on Each Backend

```bash
# On Node 1
echo "Backend Server 1 - Node 1" | sudo tee /var/www/html/index.html

# On Node 2
echo "Backend Server 2 - Node 2" | sudo tee /var/www/html/index.html

# On Node 3
echo "Backend Server 3 - Node 3" | sudo tee /var/www/html/index.html
```

## Step 4: Configure HAProxy on Node 1

Get node IPs first:
```bash
source /opt/linux-labs/lib/load-config.sh
load_lab_config
NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)
```

Create HAProxy configuration:
```bash
sudo tee /etc/haproxy/haproxy.cfg > /dev/null <<EOF
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
    server node1 $NODE1_IP:8080 check
    server node2 $NODE2_IP:8080 check
    server node3 $NODE3_IP:8080 check
EOF
```

## Step 5: Configure Firewall on Node 1

```bash
# Allow HAProxy port 80
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

## Step 6: Configure Firewall on All Nodes for Backend Access

```bash
# On all 3 nodes - allow port 8080
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

## Step 7: Start HAProxy

```bash
# On Node 1
sudo systemctl start haproxy
sudo systemctl enable haproxy
```

## Step 8: Test Load Balancing

```bash
# Make multiple requests to see load balancing
for i in {1..12}; do curl http://localhost; done
```

You should see responses from all three backend servers in a round-robin pattern.

## Verify

```bash
sudo labctl grade lb-01
```

## Troubleshooting

Check HAProxy status:
```bash
sudo systemctl status haproxy
```

View HAProxy logs:
```bash
sudo journalctl -u haproxy -f
```

Check backend health:
```bash
curl http://localhost:8080  # On each node directly
```

Verify HAProxy stats (if stats page configured):
```bash
curl http://localhost/haproxy?stats
```
