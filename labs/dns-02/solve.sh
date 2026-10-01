#!/bin/bash
# Reference solution for dns-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /var/named/labdomain.com.zone
# solve: path /etc/named.conf
# solve: package bind
# solve: package bind-utils
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
dnf -y install bind bind-utils

# Step 2 [sudo]
tee /var/named/labdomain.com.zone > /dev/null <<'ZONE'
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

# Step 3 [sudo]
chown root:named /var/named/labdomain.com.zone
chmod 640 /var/named/labdomain.com.zone
named-checkzone labdomain.com /var/named/labdomain.com.zone

# Step 4 [sudo]
tee -a /etc/named.conf > /dev/null <<'CONF'

zone "labdomain.com" IN {
    type master;
    file "/var/named/labdomain.com.zone";
    allow-update { none; };
};
CONF
named-checkconf

# Step 5 [sudo]
systemctl enable --now named
