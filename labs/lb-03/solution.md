# Load Balancing 03 Solution - Advanced HA with Keepalived VIP

## Overview
This solution implements high availability load balancing using HAProxy on Nodes 1 and 2 with keepalived managing a Virtual IP (VIP) for automatic failover, distributing traffic to Apache backends on all 3 nodes.

## Architecture
- **VIP**: 172.25.250.100 (floats between Node 1 and Node 2)
- **Node 1**: HAProxy MASTER (priority 100) + Apache backend
- **Node 2**: HAProxy BACKUP (priority 90) + Apache backend
- **Node 3**: Apache backend only

## Step 1: Install Packages on All Nodes

```bash
# On Nodes 1 and 2
sudo dnf install -y haproxy keepalived httpd

# On Node 3
sudo dnf install -y httpd
```

## Step 2: Configure Apache on All Nodes

```bash
# On all 3 nodes - Configure Apache to listen on port 8080
sudo sed -i 's/^Listen 80$/Listen 8080/' /etc/httpd/conf/httpd.conf

# Create unique content on each node
# On Node 1
echo "Backend Server - Node 1" | sudo tee /var/www/html/index.html

# On Node 2
echo "Backend Server - Node 2" | sudo tee /var/www/html/index.html

# On Node 3
echo "Backend Server - Node 3" | sudo tee /var/www/html/index.html

# Start and enable Apache on all nodes
sudo systemctl start httpd
sudo systemctl enable httpd

# Configure firewall on all nodes
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

## Step 3: Configure HAProxy on Nodes 1 and 2

Get node IPs first:
```bash
source /opt/linux-labs/lib/load-config.sh
load_lab_config
NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)
```

Create identical HAProxy configuration on both Nodes 1 and 2:
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

## Step 4: Start HAProxy on Nodes 1 and 2

```bash
# On Nodes 1 and 2
sudo systemctl start haproxy
sudo systemctl enable haproxy

# Configure firewall
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-protocol=vrrp
sudo firewall-cmd --reload
```

## Step 5: Configure Keepalived on Node 1 (MASTER)

```bash
# On Node 1
sudo tee /etc/keepalived/keepalived.conf > /dev/null <<'EOF'
global_defs {
    router_id LB_MASTER
    enable_script_security
}

vrrp_script check_haproxy {
    script "/usr/bin/systemctl is-active haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass SecretPass123
    }
    
    virtual_ipaddress {
        172.25.250.100/24
    }
    
    track_script {
        check_haproxy
    }
}
EOF
```

## Step 6: Configure Keepalived on Node 2 (BACKUP)

```bash
# On Node 2
sudo tee /etc/keepalived/keepalived.conf > /dev/null <<'EOF'
global_defs {
    router_id LB_BACKUP
    enable_script_security
}

vrrp_script check_haproxy {
    script "/usr/bin/systemctl is-active haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 90
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass SecretPass123
    }
    
    virtual_ipaddress {
        172.25.250.100/24
    }
    
    track_script {
        check_haproxy
    }
}
EOF
```

**Important Notes:**
- Both nodes must have the same `virtual_router_id` (51)
- Both nodes must have the same `auth_pass`
- Node 1 has higher priority (100) than Node 2 (90)
- Adjust `interface` to match your network interface (use `ip addr` to check)

## Step 7: Configure SELinux for Keepalived

```bash
# On Nodes 1 and 2
sudo setsebool -P keepalived_connect_any 1
```

## Step 8: Start Keepalived on Nodes 1 and 2

```bash
# On Nodes 1 and 2
sudo systemctl start keepalived
sudo systemctl enable keepalived
```

## Step 9: Verify VIP Assignment

```bash
# Check which node has the VIP
# On Node 1
ip addr show | grep 172.25.250.100

# On Node 2
ip addr show | grep 172.25.250.100

# The MASTER (Node 1) should have the VIP
```

## Step 10: Test Load Balancing via VIP

```bash
# From Node 1, test the VIP
for i in {1..12}; do curl http://172.25.250.100; done

# You should see responses from all 3 backend servers
```

## Step 11: Test Failover

```bash
# On Node 1, stop keepalived to simulate failure
sudo systemctl stop keepalived

# Check VIP moved to Node 2
ssh node2 "ip addr show | grep 172.25.250.100"

# Test VIP still responds (now handled by Node 2)
curl http://172.25.250.100

# Restart keepalived on Node 1
sudo systemctl start keepalived

# VIP should move back to Node 1 (MASTER)
ip addr show | grep 172.25.250.100
```

## Step 12: Test HAProxy Failure Detection

```bash
# Stop HAProxy on Node 1 (current MASTER)
sudo systemctl stop haproxy

# Wait a few seconds, VIP should move to Node 2
sleep 5
ip addr show | grep 172.25.250.100

# VIP should be gone from Node 1
# Check Node 2
ssh node2 "ip addr show | grep 172.25.250.100"

# Restart HAProxy
sudo systemctl start haproxy
```

## Verify

```bash
sudo labctl grade lb-03
```

## Troubleshooting

Check keepalived status:
```bash
sudo systemctl status keepalived
```

View keepalived logs:
```bash
sudo journalctl -u keepalived -f
```

Check VRRP messages:
```bash
sudo tcpdump -i eth0 vrrp
```

Verify VIP:
```bash
ip addr show
```

Check HAProxy status:
```bash
sudo systemctl status haproxy
```

Test VIP connectivity:
```bash
ping 172.25.250.100
curl http://172.25.250.100
```

## How It Works

1. **VRRP Protocol**: Keepalived uses VRRP (Virtual Router Redundancy Protocol) to manage the VIP
2. **Priority**: Node with highest priority becomes MASTER and owns the VIP
3. **Health Checks**: The `vrrp_script` monitors HAProxy - if it fails, priority drops
4. **Automatic Failover**: If MASTER fails, BACKUP automatically takes over the VIP
5. **Authentication**: Prevents rogue VRRP instances from interfering

## Key Configuration Parameters

- `virtual_router_id`: Must be unique per VRRP group and identical on both nodes
- `priority`: Higher priority = preferred MASTER (100 > 90)
- `advert_int`: How often to send VRRP advertisements (1 second)
- `auth_pass`: Shared secret for VRRP authentication
- `check_haproxy`: Script to verify HAProxy is healthy

This setup provides automatic failover with minimal downtime when the primary load balancer fails.
