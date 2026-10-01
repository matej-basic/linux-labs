# dns-02: DNS forward zone with A, CNAME and MX records

## Solution

1. [sudo] Install BIND and the client tools:

   ```bash
   sudo dnf -y install bind bind-utils
   ```

2. [sudo] Create the zone file:

   ```bash
   sudo tee /var/named/labdomain.com.zone > /dev/null <<'ZONE'
   $TTL 86400
   @       IN  SOA ns1.labdomain.com. admin.labdomain.com. (
                   2026012501 ; serial
                   3600       ; refresh
                   1800       ; retry
                   604800     ; expire
                   86400 )    ; negative cache TTL
           IN  NS  ns1.labdomain.com.
           IN  MX  10 mail.labdomain.com.
   ns1     IN  A   192.168.1.5
   web     IN  A   192.168.1.10
   mail    IN  A   192.168.1.20
   www     IN  CNAME web.labdomain.com.
   ZONE
   ```

3. [sudo] Let named read the file and check it:

   ```bash
   sudo chown root:named /var/named/labdomain.com.zone
   sudo chmod 640 /var/named/labdomain.com.zone
   sudo named-checkzone labdomain.com /var/named/labdomain.com.zone
   ```

4. [sudo] Declare the zone in the main configuration and check it:

   ```bash
   sudo tee -a /etc/named.conf > /dev/null <<'CONF'

   zone "labdomain.com" IN {
       type master;
       file "/var/named/labdomain.com.zone";
       allow-update { none; };
   };
   CONF
   sudo named-checkconf
   ```

5. [sudo] Start named and enable it at boot:

   ```bash
   sudo systemctl enable --now named
   ```

## Verification

```bash
dig @127.0.0.1 web.labdomain.com +short
dig @127.0.0.1 www.labdomain.com +short
dig @127.0.0.1 labdomain.com MX +short
dig @127.0.0.1 labdomain.com SOA +short
labctl grade dns-02
```

## Explanation

named loads only zones that are declared in /etc/named.conf, so a
correct zone file alone answers nothing. The grader asks with
recursion switched off, which means only a zone that named loaded can
answer, and it checks the aa (authoritative answer) flag.

A zone is refused without an NS record, and an NS name inside the zone
needs an address record, which is why ns1 exists. Names in a zone file
that do not end with a dot get the zone name appended: writing
web.labdomain.com without the final dot in the CNAME gives
web.labdomain.com.labdomain.com. The zone file must be readable by the
named group, otherwise named logs a permission error and the zone does
not load.
