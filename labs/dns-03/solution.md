# DNS 03 Solution

Configure DNSSEC for a zone and enable zone transfers.

## Commands to reach the expected state:

```bash
# Install BIND DNS server
sudo dnf install -y bind bind-utils

# Create the unsigned zone file
sudo tee /var/named/labsecure.com.zone > /dev/null <<'ZONE'
$TTL 86400
@       IN      SOA     ns1.labsecure.com. admin.labsecure.com. (
                        2026012501      ; serial
                        3600            ; refresh
                        1800            ; retry
                        604800          ; expire
                        86400 )         ; minimum
        IN      NS      ns1.labsecure.com.
ns1     IN      A       192.168.1.5
web     IN      A       192.168.1.10
api     IN      A       192.168.1.15
ZONE

# Set proper permissions on the unsigned zone file
sudo chown root:named /var/named/labsecure.com.zone
sudo chmod 640 /var/named/labsecure.com.zone

# Generate DNSSEC keys (KSK)
cd /var/named
sudo dnssec-keygen -a NSEC3RSASHA1 -b 2048 -f KSK labsecure.com

# Generate DNSSEC keys (ZSK)
sudo dnssec-keygen -a NSEC3RSASHA1 -b 1024 labsecure.com

# List the generated keys to verify they exist
ls -la Klabsecure.com.+*.key
ls -la Klabsecure.com.+*.private

# Sign the zone (use -S to auto-discover signing keys in current directory)
sudo dnssec-signzone -S -o labsecure.com labsecure.com.zone

# Update the existing options block in named.conf to enable DNSSEC
# Check if dnssec-validation exists, if so replace it, otherwise add it
if grep -q "dnssec-validation" /etc/named.conf; then
    sudo sed -i 's/^\s*dnssec-validation.*/    dnssec-validation auto;/' /etc/named.conf
else
    sudo sed -i '/^options {/a\
    dnssec-validation auto;' /etc/named.conf
fi

# Check if dnssec-enable exists, if so replace it, otherwise add it
if grep -q "dnssec-enable" /etc/named.conf; then
    sudo sed -i 's/^\s*dnssec-enable.*/    dnssec-enable yes;/' /etc/named.conf
else
    sudo sed -i '/^options {/a\
    dnssec-enable yes;' /etc/named.conf
fi

# Add the zone configuration to named.conf
sudo tee -a /etc/named.conf > /dev/null <<'CONFIG'

zone "labsecure.com" IN {
    type master;
    file "/var/named/labsecure.com.zone.signed";
    allow-transfer { 127.0.0.1; ::1; };
    allow-query { any; };
};
CONFIG

# Start and enable named service
sudo systemctl start named
sudo systemctl enable named
```

## Verify:

```bash
# Check DNSSEC keys exist
ls -la /var/named/Klabsecure.com.+*.key
ls -la /var/named/Klabsecure.com.+*.private

# Verify zone is signed
ls -la /var/named/labsecure.com.zone.signed

# Query with DNSSEC validation
dig @localhost labsecure.com +dnssec

# Check AD flag (DNSSEC verified)
dig @localhost web.labsecure.com +dnssec | grep -i "flags:"

# Test zone transfer
dig @localhost labsecure.com axfr

# Verify zone transfer includes DNSSEC records
dig @localhost labsecure.com axfr | grep -i "RRSIG"
```
