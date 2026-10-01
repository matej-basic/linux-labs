# dns-03: DNSSEC signed zone with zone transfer

## Solution

1. [sudo] Install BIND and the client tools. On Rocky 9 the signing
   tools come from bind-dnssec-utils, which bind pulls in as a
   dependency. Install it explicitly if dnssec-keygen is missing:

   ```bash
   sudo dnf -y install bind bind-utils
   command -v dnssec-keygen || sudo dnf -y install bind-dnssec-utils
   ```

2. [sudo] Create the unsigned zone file:

   ```bash
   sudo tee /var/named/labsecure.com.zone >/dev/null <<'ZONE'
   $TTL 86400
   @    IN SOA ns1.labsecure.com. admin.labsecure.com. (
             2026012501 ; serial
             3600       ; refresh
             1800       ; retry
             604800     ; expire
             86400 )    ; minimum
        IN NS  ns1.labsecure.com.
   ns1  IN A   192.168.1.5
   web  IN A   192.168.1.10
   api  IN A   192.168.1.15
   ZONE
   ```

3. [sudo] Generate the KSK and the ZSK with a SHA-2 algorithm.
   SHA-1 based algorithms such as NSEC3RSASHA1 are rejected on
   Rocky 9:

   ```bash
   cd /var/named
   sudo dnssec-keygen -a RSASHA256 -b 2048 -f KSK labsecure.com
   sudo dnssec-keygen -a RSASHA256 -b 1024 labsecure.com
   ```

4. [sudo] Sign the zone. The option -S finds the keys in the current
   directory and adds the DNSKEY records itself:

   ```bash
   cd /var/named
   sudo dnssec-signzone -S -o labsecure.com labsecure.com.zone
   ```

5. [sudo] Add the zone to named.conf. It is loaded from the signed
   file and transfers are allowed from the loopback addresses only:

   ```bash
   sudo tee -a /etc/named.conf >/dev/null <<'CONF'

   zone "labsecure.com" IN {
       type master;
       file "/var/named/labsecure.com.zone.signed";
       allow-transfer { 127.0.0.1; ::1; };
   };
   CONF
   sudo named-checkconf /etc/named.conf
   ```

6. [sudo] Start named and enable it at boot:

   ```bash
   sudo systemctl enable --now named
   ```

## Verification

```bash
dig @127.0.0.1 web.labsecure.com A +dnssec
dig @127.0.0.1 labsecure.com DNSKEY +short
dig @127.0.0.1 labsecure.com AXFR | grep RRSIG
labctl grade dns-03
```

## Explanation

dnssec-keygen creates a key pair per run. The key signing key (flag
257, option -f KSK) signs the DNSKEY set, the zone signing key (flag
256) signs all other records. dnssec-signzone writes the signed zone
to labsecure.com.zone.signed, and named has to load that file, not the
unsigned one, or no RRSIG records are served.

RSASHA256 (algorithm 8) works on Rocky 8 and 9. The older NSEC3RSASHA1
fails on Rocky 9, where the default crypto policy rejects SHA-1
signatures. The option dnssec-enable that older guides add to
named.conf is obsolete in the BIND versions of both releases and is not
needed. The packaged configuration already has dnssec-validation auto.

The grader runs as the student, who cannot read /var/named or
/etc/named.conf, so it queries named instead. Transfers from 127.0.0.1
must work and transfers from the other addresses of the host must be
refused. An allow-transfer of localhost or any fails that check.
