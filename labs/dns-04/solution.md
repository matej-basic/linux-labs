# dns-04: BIND secondary zone with zone transfers

## Hints

1. Node 1 needs three changes in /etc/named.conf: listen on its own
   address, answer queries from node 2, and restrict and announce the
   transfers of the zone. Node 2 gets a zone statement of the
   secondary type that names node 1 as the server to copy from.
2. The packaged named.conf listens on 127.0.0.1 only and answers only
   localhost. Read the options listen-on and allow-query in
   man named.conf, and allow-transfer and also-notify for the zone.
3. On Rocky 8 the secondary zone type is called slave and the list of
   primary servers is masters. Both words also work on Rocky 9.
4. The SELinux policy lets named write zone files to
   /var/named/slaves, not to /var/named itself. The firewall service
   dns covers 53/tcp and 53/udp.

## Solution

The commands use the default addresses 172.25.250.10 for node 1 and
172.25.250.11 for node 2. Use the addresses from the TOPOLOGY section
of the task.

1. [user] From the workstation, log in to node 1 as the node account:

   ```bash
   ssh opsadmin@172.25.250.10
   ```

2. [sudo] Edit /etc/named.conf on node 1. In the options statement,
   add the node 1 address to listen-on and the node 2 address to
   allow-query:

   ```
   listen-on port 53 { 127.0.0.1; 172.25.250.10; };
   allow-query     { localhost; 172.25.250.11; };
   ```

   In the zone statement for lab.example, allow the transfer to node
   2 only and send NOTIFY to node 2:

   ```
   zone "lab.example" IN {
           type master;
           file "lab.example.zone";
           allow-transfer { 172.25.250.11; };
           also-notify { 172.25.250.11; };
   };
   ```

3. [sudo] Check the configuration, start named, enabled at boot, and
   open the firewall for DNS, now and permanently:

   ```bash
   sudo named-checkconf
   sudo systemctl enable --now named
   sudo firewall-cmd --add-service=dns
   sudo firewall-cmd --permanent --add-service=dns
   ```

4. [user] Log out of node 1 and log in to node 2 from the
   workstation:

   ```bash
   exit
   ssh opsadmin@172.25.250.11
   ```

5. [sudo] Install BIND on node 2 where it is missing:

   ```bash
   rpm -q bind bind-utils || sudo dnf -y install bind bind-utils
   ```

6. [sudo] Edit /etc/named.conf on node 2. In the options statement,
   add the node 2 address to listen-on:

   ```
   listen-on port 53 { 127.0.0.1; 172.25.250.11; };
   ```

   At the end of the file, add the secondary zone:

   ```
   zone "lab.example" IN {
           type slave;
           masters { 172.25.250.10; };
           file "slaves/lab.example.zone";
   };
   ```

7. [sudo] Check the configuration, open the firewall and start named,
   enabled at boot:

   ```bash
   sudo named-checkconf
   sudo firewall-cmd --add-service=dns
   sudo firewall-cmd --permanent --add-service=dns
   sudo systemctl enable --now named
   ```

## Verification

On node 2, the zone file appears after the first transfer, and both
servers report the same serial:

```bash
sudo ls -l /var/named/slaves
dig @172.25.250.11 lab.example SOA +norec
dig @172.25.250.10 lab.example SOA +short
dig @172.25.250.10 lab.example AXFR
```

On node 1, a transfer to its own address is refused:

```bash
dig -b 172.25.250.10 @172.25.250.10 lab.example AXFR
```

On the workstation:

```bash
labctl grade dns-04
```

## Explanation

A secondary server copies the whole zone from its primary with a zone
transfer (AXFR over TCP) and keeps the copy in a file, so it can load
it again after a restart without asking the primary. named runs as
the user named and SELinux confines it: it may write to
/var/named/slaves but not to /var/named, where the primary zone files
live. A file name there without a directory part makes the transfer
fail with a permission error in the journal.

The secondary asks the primary for the SOA serial at every refresh
interval, one hour in this zone, and transfers the zone when the
serial is higher. NOTIFY shortens that wait: when the primary loads a
zone with a new serial, it sends a NOTIFY message to the servers in
the NS records of the zone and to the addresses in also-notify. The
NS record of lab.example names only node 1, so also-notify is needed
for node 2. The secondary accepts NOTIFY from its primaries and checks
the serial at once.

Without allow-transfer, BIND 9.11 and 9.16 allow any host that can
query the zone to transfer it. The value localhost would let node 1
transfer to its own address, which task 3 rules out. Rocky 8 ships
BIND 9.11, which knows only the keywords slave and masters, and
Rocky 9 ships BIND 9.16, which accepts them as well as secondary and
primaries, so the solution uses the older words.
