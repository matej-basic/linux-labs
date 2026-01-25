# DNS 02 Solution

Configure a BIND forward zone and create DNS records.

## Commands to reach the expected state:

```bash
# Install BIND DNS server
sudo dnf install -y bind bind-utils

# Create the zone file
sudo tee /var/named/labdomain.com.zone > /dev/null <<'ZONE'
$TTL 86400
@       IN      SOA     ns1.labdomain.com. admin.labdomain.com. (
                        2026012501      ; serial
                        3600            ; refresh
                        1800            ; retry
                        604800          ; expire
                        86400 )         ; minimum
        IN      NS      ns1.labdomain.com.
ns1     IN      A       192.168.1.5
web     IN      A       192.168.1.10
mail    IN      A       192.168.1.20
www     IN      CNAME   web.labdomain.com.
@       IN      MX      10 mail.labdomain.com.
ZONE

# Update named.conf to add the zone
sudo tee -a /etc/named.conf > /dev/null <<'CONFIG'

zone "labdomain.com" IN {
    type master;
    file "/var/named/labdomain.com.zone";
    allow-update { none; };
};
CONFIG

# Set proper permissions
sudo chown root:named /var/named/labdomain.com.zone
sudo chmod 640 /var/named/labdomain.com.zone

# Start and enable named service
sudo systemctl start named
sudo systemctl enable named
```

## Verify:

```bash
# Check zone file syntax
sudo named-checkzone labdomain.com /var/named/labdomain.com.zone

# Query DNS records
dig @localhost web.labdomain.com
dig @localhost mail.labdomain.com
dig @localhost www.labdomain.com
dig @localhost labdomain.com MX
nslookup web.labdomain.com localhost
```
