# Load Balancing 02 Solution - Nginx Reverse Proxy with Health Checks

## Overview
This solution configures Nginx as a reverse proxy on Node 1 to distribute traffic to Apache backends on Nodes 2 and 3, with comprehensive health checking and proper proxy headers.

## Step 1: Install Nginx on Node 1

```bash
# On Node 1
sudo dnf install -y nginx
```

## Step 2: Install Apache on Nodes 2 and 3

```bash
# On Nodes 2 and 3
sudo dnf install -y httpd

# Configure Apache to listen on port 8080
sudo sed -i 's/^Listen 80$/Listen 8080/' /etc/httpd/conf/httpd.conf

# Start and enable Apache
sudo systemctl start httpd
sudo systemctl enable httpd
```

## Step 3: Create Content and Health Endpoints on Backends

```bash
# On Node 2
echo "Backend Server - Node 2" | sudo tee /var/www/html/index.html
echo "OK" | sudo tee /var/www/html/health

# On Node 3
echo "Backend Server - Node 3" | sudo tee /var/www/html/index.html
echo "OK" | sudo tee /var/www/html/health
```

## Step 4: Configure Firewall on Nodes 2 and 3

```bash
# On Nodes 2 and 3
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

## Step 5: Configure Nginx on Node 1

Get node IPs:
```bash
source /opt/linux-labs/lib/load-config.sh
load_lab_config
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)
```

Create Nginx configuration:
```bash
sudo tee /etc/nginx/conf.d/lb.conf > /dev/null <<EOF
upstream backend_servers {
    # Least connections load balancing
    least_conn;
    
    # Backend servers with health check parameters
    server 10.0.0.155:8080 max_fails=3 fail_timeout=30s;
    server 10.0.0.156:8080 max_fails=3 fail_timeout=30s;
    
    # Enable keepalive connections
    keepalive 32;
}

server {
    listen 80;
    server_name _;
    
    # Access and error logs
    access_log /var/log/nginx/lb_access.log;
    error_log /var/log/nginx/lb_error.log;
    
    location / {
        # Proxy to backend servers
        proxy_pass http://backend_servers;
        
        # Proxy headers for backend visibility
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Connection settings
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        
        # Timeouts
        proxy_connect_timeout 5s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }
    
    location /health {
        # Health check endpoint
        proxy_pass http://backend_servers/health;
        proxy_set_header Host \$host;
        access_log off;
    }
}
EOF
```

## Step 6: Test Nginx Configuration

```bash
# On Node 1
sudo nginx -t
```

## Step 7: Configure SELinux (if enabled)

```bash
# On Node 1 - Allow Nginx to make network connections
sudo setsebool -P httpd_can_network_connect 1
```

## Step 8: Configure Firewall on Node 1

```bash
# On Node 1
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

## Step 9: Start Nginx

```bash
# On Node 1
sudo systemctl start nginx
sudo systemctl enable nginx
```

## Step 10: Test the Reverse Proxy

```bash
# Test basic connectivity
curl http://127.0.0.1

# Test health endpoint
curlhttp://127.0.0.1/health

# Make multiple requests to see load balancing
for i in {1..10}; do curl http://127.0.0.1; done

# Check which backend is being used
curl -I http://127.0.0.1
```

## Step 11: Test Health Check and Failover

```bash
# Stop Apache on Node 2
ssh node2 "sudo systemctl stop httpd"

# Requests should still work (going to Node 3 only)
curl http://127.0.0.1

# Check Nginx error log to see failed health checks
sudo tail -f /var/log/nginx/lb_error.log

# Restart Apache on Node 2
ssh node2 "sudo systemctl start httpd"

# Traffic should resume to both backends
```

## Verify

```bash
sudo labctl grade lb-02
```

## Troubleshooting

Check Nginx status:
```bash
sudo systemctl status nginx
```

View Nginx error logs:
```bash
sudo tail -f /var/log/nginx/lb_error.log
```

Check upstream status:
```bash
sudo tail -f /var/log/nginx/lb_access.log
```

Test backend directly:
```bash
curl http://<backend-ip>:8080
curl http://<backend-ip>:8080/health
```

Verify Nginx configuration:
```bash
sudo nginx -T
```

## Advanced: Monitor Backend Health

You can check which backends are active by looking at the Nginx error log. Failed backends will generate entries like:
```
upstream timed out (110: Connection timed out) while connecting to upstream
```

Successful failover means Nginx automatically routes traffic to healthy backends only.
