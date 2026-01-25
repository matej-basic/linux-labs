#!/bin/bash

# Reset lab state
systemctl stop named > /dev/null 2>&1
dnf remove -y bind bind-utils > /dev/null 2>&1
rm -rf /var/named/labsecure.com.zone /var/named/labsecure.com.zone.signed /var/named/K* > /dev/null 2>&1

# Print task description
cat <<'EOF'

====================================================
LAB: DNS - DNSSEC & Replication (dns-03)
====================================================

OBJECTIVE:
Configure DNSSEC for a zone with KSK and ZSK keys,
enable zone transfers to a secondary server, and
verify DNSSEC validation and zone replication.

REQUIREMENTS:
- Install BIND DNS server (bind and bind-utils)
- Create a zone file for labsecure.com with A records
- Generate DNSSEC KSK (Key Signing Key)
- Generate DNSSEC ZSK (Zone Signing Key)
- Sign the zone with dnssec-signzone
- Configure DNSSEC validation in named.conf
- Enable zone transfers with proper ACLs
- Create secondary zone configuration for replication
- Start the named service
- Verify DNSSEC signatures with dig +dnssec
- Verify zone transfer to secondary with dig axfr

NOTES:
- You may use any valid Linux commands and text editors
- Primary zone file: /var/named/labsecure.com.zone
- Signed zone file: /var/named/labsecure.com.zone.signed
- DNSSEC keys will be created in /var/named/
- The grading script checks DNS signatures and transfers

When ready, run:
  sudo labctl grade dns-03

====================================================

EOF

