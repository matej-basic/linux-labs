# DNS 01 Solution

Install and start BIND DNS server.

## Commands to reach the expected state:

```bash
# Install BIND DNS server
sudo dnf install -y bind bind-utils

# Start the named service
sudo systemctl start named

# Enable named to start on boot
sudo systemctl enable named
```

## Verify:

```bash
# Check if bind is installed
rpm -q bind

# Check if named is running
sudo systemctl status named

# Check if port 53 is listening (UDP and TCP)
sudo ss -tlnp | grep :53
sudo ss -ulnp | grep :53

# Test DNS resolution
dig localhost
nslookup localhost
```
