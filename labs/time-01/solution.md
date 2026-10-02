# time-01: Chrony time server and client

## Hints

1. Both nodes run chronyd and read /etc/chrony.conf. Node 1 needs two
   new directives there, a running chronyd and a firewall rule. Node 2
   needs a different list of sources and a new time zone.
2. Read man chrony.conf. The directive allow opens the NTP server to
   clients, and the directive local lets an unsynchronised server
   still answer them. The default file has both as comments.
3. On node 2, the line that starts with pool is the source of the
   default configuration. Replace it with a server line for node 1.
   The firewalld service for NTP is called ntp.
4. The command chronyc with sources shows what chronyd uses, with a
   star at the selected source. The command timedatectl changes the
   time zone.

## Solution

All steps run on the workstation as the lab user. They reach the nodes
with run_on_node from the lab library, which uses the SSH settings of
the lab configuration. The same commands work in an SSH session on the
node.

1. [user] Load the lab configuration and the node addresses. Node 1
   is the server, node 2 the client:

   ```bash
   source /opt/linux-labs/lib/load-config.sh
   N1=$(get_node_ip 1); N2=$(get_node_ip 2)
   ```

2. [user] On node 1, allow node 2 and add the local reference clock
   at the end of /etc/chrony.conf:

   ```bash
   printf 'allow %s\nlocal stratum 10\n' "$N2" |
     run_on_node "$N1" "sudo -n tee -a /etc/chrony.conf"
   ```

3. [user] Start chronyd on node 1 and enable it at boot. The restart
   makes an already running chronyd read the new configuration:

   ```bash
   run_on_node "$N1" "sudo -n systemctl enable chronyd"
   run_on_node "$N1" "sudo -n systemctl restart chronyd"
   ```

4. [user] Open the firewall of node 1 for NTP:

   ```bash
   run_on_node "$N1" \
     "sudo -n firewall-cmd --permanent --add-service=ntp"
   run_on_node "$N1" "sudo -n firewall-cmd --reload"
   ```

5. [user] On node 2, turn the existing pool, server and peer lines into
   comments and add node 1 as the only server:

   ```bash
   run_on_node "$N2" "sudo -n sed -i -E \
     's/^(pool|server|peer)[[:space:]]/#&/' /etc/chrony.conf"
   echo "server $N1 iburst" |
     run_on_node "$N2" "sudo -n tee -a /etc/chrony.conf"
   ```

6. [user] Enable chronyd on node 2 and restart it with the new source:

   ```bash
   run_on_node "$N2" "sudo -n systemctl enable chronyd"
   run_on_node "$N2" "sudo -n systemctl restart chronyd"
   ```

7. [user] Set the time zone of node 2:

   ```bash
   run_on_node "$N2" "sudo -n timedatectl set-timezone Europe/Zagreb"
   ```

## Verification

After a few seconds node 2 lists node 1 with the marker ^* and node 1
lists node 2 as a client:

```bash
run_on_node "$N2" "chronyc -n sources"
run_on_node "$N1" "sudo -n chronyc -n clients"
run_on_node "$N2" "timedatectl"
```

Then grade:

```bash
labctl grade time-01
```

## Explanation

chronyd is an NTP client by default and serves nobody. The directive
allow turns on the server part for the listed address or network. The
directive local makes chronyd claim the given stratum when it has no
synchronised source of its own. Without it, a server that cannot reach
the internet reports itself as unsynchronised, and its clients refuse
to use it. Stratum 10 is high on purpose, so that any real time source
wins over it.

The default configuration of Rocky Linux 8 and 9 takes its time from a
pool line. A pool line adds several servers from DNS, so it must go
before node 1 can be the only source. On Rocky Linux 9 the line
sourcedir /run/chrony-dhcp can also add servers that DHCP announces.
It is not a source in itself and can stay. The grader checks the
sources chronyd really uses, so such a server would show up there.

The option iburst sends a burst of requests at the start, so the
client selects node 1 within seconds instead of minutes. chronyc
sources marks the selected source with a star.

NTP uses UDP port 123, which the firewalld service ntp opens. The time
zone only changes how the time is shown; chronyd keeps the clock in
UTC either way.
