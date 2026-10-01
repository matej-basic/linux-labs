# lb-01: HAProxy load balancing for three web servers

## Solution

1. [user] On the workstation, load the node addresses from the lab
   configuration:

   ```bash
   source /opt/linux-labs/lib/load-config.sh
   N1=$(get_node_ip 1); N2=$(get_node_ip 2); N3=$(get_node_ip 3)
   ```

2. [user] Install the packages: httpd on all three nodes, HAProxy on
   node 1:

   ```bash
   run_on_node "$N1" "sudo dnf -y install haproxy httpd"
   run_on_node "$N2" "sudo dnf -y install httpd"
   run_on_node "$N3" "sudo dnf -y install httpd"
   ```

3. [user] On each node, move Apache to port 8080, give it a page that
   names the node, then start and enable it:

   ```bash
   CONF=/etc/httpd/conf/httpd.conf
   PAGE=/var/www/html/index.html
   i=0
   for ip in "$N1" "$N2" "$N3"; do
     i=$((i + 1))
     run_on_node "$ip" "sudo sed -i 's/^Listen 80/Listen 8080/' $CONF"
     run_on_node "$ip" "echo 'Backend on node $i' | sudo tee $PAGE"
     run_on_node "$ip" "sudo systemctl enable --now httpd"
   done
   ```

4. [user] Open the firewall: port 80 on node 1, port 8080 on nodes 2
   and 3:

   ```bash
   FW="sudo firewall-cmd"
   run_on_node "$N1" "$FW --permanent --add-service=http"
   for ip in "$N2" "$N3"; do
     run_on_node "$ip" "$FW --permanent --add-port=8080/tcp"
   done
   for ip in "$N1" "$N2" "$N3"; do
     run_on_node "$ip" "$FW --reload"
   done
   ```

5. [user] Allow HAProxy to connect to the backends on port 8080 under
   SELinux:

   ```bash
   run_on_node "$N1" "sudo setsebool -P haproxy_connect_any on"
   ```

6. [user] Write the HAProxy configuration to a local file and copy it
   to node 1:

   ```bash
   cat > /tmp/haproxy.cfg <<EOF
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
   EOF
   run_on_node "$N1" "sudo tee /etc/haproxy/haproxy.cfg >/dev/null" \
     < /tmp/haproxy.cfg
   run_on_node "$N1" "sudo haproxy -c -f /etc/haproxy/haproxy.cfg"
   rm -f /tmp/haproxy.cfg
   ```

7. [user] Start and enable HAProxy:

   ```bash
   run_on_node "$N1" "sudo systemctl enable --now haproxy"
   ```

## Verification

```bash
sleep 10
for i in $(seq 12); do curl -s "http://$N1/"; done
labctl grade lb-01
```

## Explanation

Node 1 runs both HAProxy and Apache, so Apache moves to port 8080 and
HAProxy takes port 80. Each page names its node, which makes it
visible which backend answered. `balance roundrobin` hands the
requests to the three servers in turn, so twelve requests give four
answers per backend. `check` makes HAProxy probe each server, and
`option httpchk` turns the probe into an HTTP request instead of a
plain TCP connect.

HAProxy needs a few seconds after the start before it marks the
backends up, and answers 503 until then. The firewall rules are
permanent so they survive a reboot. On node 1 only port 80 is opened,
because HAProxy reaches its own Apache over the loopback interface.
The `haproxy_connect_any` SELinux boolean lets HAProxy connect to
backends on ports outside the standard web ports. Turning SELinux off
instead fails the grading.
