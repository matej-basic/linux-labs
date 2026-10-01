#!/bin/bash
# Reference solution for dns-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /var/named
# solve: path /etc/named.conf
# solve: package bind
# solve: package bind-utils
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
dnf -y install bind bind-utils
command -v dnssec-keygen >/dev/null || dnf -y install bind-dnssec-utils

# Step 2 [sudo]
cat > /var/named/labsecure.com.zone <<'ZONE'
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

# Steps 3 and 4 [sudo]
cd /var/named
dnssec-keygen -a RSASHA256 -b 2048 -f KSK labsecure.com
dnssec-keygen -a RSASHA256 -b 1024 labsecure.com
dnssec-signzone -S -o labsecure.com labsecure.com.zone

# Step 5 [sudo]
cat >> /etc/named.conf <<'CONF'

zone "labsecure.com" IN {
    type master;
    file "/var/named/labsecure.com.zone.signed";
    allow-transfer { 127.0.0.1; ::1; };
};
CONF
named-checkconf /etc/named.conf

# Step 6 [sudo]
systemctl enable --now named
sleep 2
