#!/bin/bash

# Reset lab state
systemctl stop named > /dev/null 2>&1
dnf remove -y bind bind-utils > /dev/null 2>&1
rm -rf /var/named/labdomain.com.zone > /dev/null 2>&1

# Print task description
cat <<'EOF'

====================================================
LAB: DNS - Zone Configuration (dns-02)
====================================================

OBJECTIVE:
Configure a BIND forward zone for labdomain.com,
create DNS records (A, CNAME, MX), and verify DNS
resolution with dig or nslookup.

REQUIREMENTS:
- Install BIND DNS server (bind and bind-utils)
- Create a forward zone file for labdomain.com
- Add A record for web.labdomain.com pointing to 192.168.1.10
- Add A record for mail.labdomain.com pointing to 192.168.1.20
- Add CNAME record www pointing to web.labdomain.com
- Add MX record pointing to mail.labdomain.com with priority 10
- Add SOA record with serial number 2026012501
- Update named.conf to include the new zone
- Start the named service
- Verify DNS records can be queried

NOTES:
- You may use any valid Linux commands and text editors
- The grading script checks only the final state
- Zone file must be in /var/named/labdomain.com.zone

When ready, run:
  sudo labctl grade dns-02

====================================================

EOF

