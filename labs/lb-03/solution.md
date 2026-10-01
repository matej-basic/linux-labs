# lb-03: Highly available load balancer with keepalived

## Hints

1. Build it in layers: httpd on port 8080 on all three nodes, the
   same HAProxy configuration on nodes 1 and 2, then keepalived on
   nodes 1 and 2 on top.
2. VRRP is neither TCP nor UDP. firewalld has to allow the protocol
   itself, see the --add-protocol option in man firewall-cmd. HAProxy
   also needs an SELinux boolean to reach port 8080.
3. In man keepalived.conf, read the vrrp_instance block: state,
   interface, virtual_router_id, priority, authentication and
   virtual_ipaddress. The interface is the one that carries the node
   address, see ip addr.
4. Both nodes need the same router ID and password (at most 8
   characters). The VIP is written with the prefix length of the node
   network, and node 1 needs the higher priority.

## Solution

Work on the nodes over SSH. The commands use these values; set them on
each node first. NODE1_IP, NODE2_IP and NODE3_IP are the node addresses
from the task header, and VIP is the address of node 1 with the last
octet 100 (it is also the first line of
/opt/linux-labs/state/lb-03 on the workstation):

```bash
NODE1_IP=<address of node 1>
NODE2_IP=<address of node 2>
NODE3_IP=<address of node 3>
VIP=<address of node 1 with last octet 100>
```

1. [sudo] On all three nodes, install httpd, move it to port 8080,
   give it a page that names the node and open the port. Set N to the
   node number (1, 2 or 3) on each node:

   ```bash
   N=1
   sudo dnf -y install httpd
   sudo sed -i 's/^Listen 80$/Listen 8080/' /etc/httpd/conf/httpd.conf
   echo "Backend Server - Node $N" | sudo tee /var/www/html/index.html
   sudo systemctl enable --now httpd
   sudo firewall-cmd --permanent --add-port=8080/tcp
   sudo firewall-cmd --reload
   ```

2. [sudo] On nodes 1 and 2, install HAProxy and keepalived and let
   HAProxy connect to the backends on port 8080 under SELinux:

   ```bash
   sudo dnf -y install haproxy keepalived
   sudo setsebool -P haproxy_connect_any 1
   ```

3. [sudo] On nodes 1 and 2, write the same HAProxy configuration, open
   the http service and the VRRP protocol, and start HAProxy:

   ```bash
   sudo tee /etc/haproxy/haproxy.cfg >/dev/null <<EOF
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
   sudo firewall-cmd --permanent --add-service=http
   sudo firewall-cmd --permanent --add-protocol=vrrp
   sudo firewall-cmd --reload
   sudo systemctl enable --now haproxy
   ```

4. [sudo] On nodes 1 and 2, find the interface and prefix length of
   the node address, then write the keepalived configuration. On node
   1 use STATE=MASTER and PRIO=100, on node 2 use STATE=BACKUP and
   PRIO=90. NODE_IP is the address of the node you are on:

   ```bash
   NODE_IP=$NODE1_IP
   STATE=MASTER
   PRIO=100
   read -r IFACE CIDR < <(ip -o -4 addr show | awk -v ip="$NODE_IP" \
     'index($4, ip "/") == 1 { print $2, $4; exit }')
   sudo tee /etc/keepalived/keepalived.conf >/dev/null <<EOF
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
   ```

5. [sudo] On nodes 1 and 2, start keepalived:

   ```bash
   sudo systemctl enable --now keepalived
   ```

## Verification

Check which node holds the VIP and that requests to it reach all three
backends:

```bash
ip -o -4 addr show | grep "$VIP"
for i in 1 2 3 4 5 6; do curl -s http://$VIP/; done
```

```bash
labctl grade lb-03
```

## Explanation

VRRP elects the node with the highest priority as master, and the
master carries the VIP. Both nodes must use the same virtual router ID
and the same password, or they do not see each other's advertisements
and both claim the VIP. The grader checks that exactly one node holds
it. The password is limited to 8 characters.

The tracking script uses a negative weight. When pgrep finds no
haproxy process the node loses 20 priority points, so node 1 drops to
80, below node 2 at 90, and the VIP moves. With a positive weight a
failing script would add nothing and the VIP would stay on the node
with the dead load balancer. Stopping keepalived on the master moves
the VIP too, and with the default preemption it returns when node 1
starts again.

Apache moves to port 8080 because HAProxy needs port 80 on nodes 1 and
2. HAProxy connects to that port, which SELinux allows through the
haproxy_connect_any boolean. VRRP is neither TCP nor UDP, so firewalld
needs the protocol itself (vrrp). Without it each node misses the
other's advertisements and takes the VIP for itself.
