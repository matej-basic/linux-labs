# lb-02: Nginx reverse proxy with health checks

## Hints

1. nginx needs an upstream block with both backends and a location
   that uses proxy_pass. The stock server block in
   /etc/nginx/nginx.conf can take over port 80, so look at it.
2. The ngx_http_upstream_module documentation covers the max_fails
   and fail_timeout parameters of the server line and the keepalive
   directive. ngx_http_proxy_module covers proxy_set_header and
   proxy_http_version.
3. Keepalive to the backends works only with HTTP/1.1 and an empty
   Connection header. The client address and the original host are
   available as the variables $host and $remote_addr, and
   $proxy_add_x_forwarded_for.
4. Under SELinux, nginx runs as httpd_t. Look for a network connect
   boolean with getsebool -a. Node 1 needs the http service in the
   firewall, the backends need port 8080.

## Solution

The commands run on the nodes, over SSH from the workstation. The
addresses below are the defaults (Node 1 is 172.25.250.10, Node 2 is
172.25.250.11, Node 3 is 172.25.250.12); use the ones `labctl task`
shows if yours differ.

### Nodes 2 and 3 (backends)

1. [sudo] On Node 2 and Node 3, install httpd, move it to port 8080
   and open the port in the firewall:

   ```bash
   rpm -q httpd || sudo dnf -y install httpd
   sudo sed -i 's/^Listen 80$/Listen 8080/' /etc/httpd/conf/httpd.conf
   sudo firewall-cmd --permanent --add-port=8080/tcp
   sudo firewall-cmd --reload
   ```

2. [sudo] On Node 2, create the front page and the health page:

   ```bash
   echo "Backend Server - Node 2" | sudo tee /var/www/html/index.html
   echo "OK" | sudo tee /var/www/html/health
   ```

3. [sudo] On Node 3, create the same two pages with its own name:

   ```bash
   echo "Backend Server - Node 3" | sudo tee /var/www/html/index.html
   echo "OK" | sudo tee /var/www/html/health
   ```

4. [sudo] On Node 2 and Node 3, start httpd and enable it at boot:

   ```bash
   sudo systemctl enable --now httpd
   ```

### Node 1 (proxy)

5. [sudo] Install nginx and disable the stock server block in
   nginx.conf, which would otherwise take over port 80:

   ```bash
   rpm -q nginx || sudo dnf -y install nginx
   sudo sed -i '/^    server {/,/^    }/ s/^/#/' /etc/nginx/nginx.conf
   ```

6. [sudo] Write the proxy configuration. The first two lines set the
   backend addresses:

   ```bash
   NODE2_IP=172.25.250.11
   NODE3_IP=172.25.250.12
   sudo tee /etc/nginx/conf.d/lb.conf >/dev/null <<CONF
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
   sudo nginx -t
   ```

7. [sudo] Allow nginx to connect to the backends under SELinux and
   open port 80:

   ```bash
   sudo setsebool -P httpd_can_network_connect 1
   sudo firewall-cmd --permanent --add-service=http
   sudo firewall-cmd --reload
   ```

8. [sudo] Start nginx and enable it at boot:

   ```bash
   sudo systemctl enable --now nginx
   ```

### Test

9. [user] On Node 1, send requests through the proxy. The answers
   alternate between the two backends:

   ```bash
   for i in 1 2 3 4; do curl -s http://127.0.0.1/; done
   ```

10. [sudo] Stop httpd on Node 2, repeat the requests from step 9 (all
    answers come from Node 3), then start httpd again:

    ```bash
    sudo systemctl stop httpd
    sudo systemctl start httpd
    ```

## Verification

```bash
labctl grade lb-02
```

## Explanation

httpd listens on 8080 because nginx owns port 80 on Node 1 and the
backends are separate hosts that the firewall must let through. nginx
marks a backend as failed after max_fails errors within fail_timeout
and skips it for that long, so a stopped httpd costs at most one
retried request: the connection is refused and nginx tries the next
server of the upstream group (proxy_next_upstream defaults to error
and timeout).

The stock nginx.conf on Rocky 8 and 9 contains its own server block
for port 80. With it in place the new server block either loses the
port (Rocky 8, where the stock block is the default server) or the
configuration test reports a duplicate default server, so the stock
block is commented out. Without setsebool the proxy gets "Permission
denied" when connecting to the backends, because httpd_t may not open
outgoing connections by default. keepalive in the upstream only works
with proxy_http_version 1.1 and an empty Connection header.
