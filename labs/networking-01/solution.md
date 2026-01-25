# Networking 01 Solution

Configure static IP with NetworkManager:

```bash
# Find interface with default route
IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
echo "Using interface: $IFACE"

# Create static connection
sudo nmcli connection add type ethernet con-name labnet-static ifname "$IFACE"
sudo nmcli connection modify labnet-static ipv4.method manual
sudo nmcli connection modify labnet-static ipv4.addresses 192.168.1.100/24
sudo nmcli connection modify labnet-static ipv4.gateway 192.168.1.1
sudo nmcli connection modify labnet-static ipv4.dns 8.8.8.8
sudo nmcli connection up labnet-static

# Verify
ip addr show
ip route show
nmcli connection show labnet-static
```

Grade:
```bash
sudo labctl grade networking-01
```
