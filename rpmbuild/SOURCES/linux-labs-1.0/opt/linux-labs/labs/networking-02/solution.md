# Networking 02 Solution

Configure VLAN and hostname:

```bash
# Find interface with default route
IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
echo "Using interface: $IFACE"

# Create VLAN interface
sudo nmcli connection add type vlan con-name vlan10 ifname vlan10 dev "$IFACE" id 10
sudo nmcli connection modify vlan10 ipv4.method manual
sudo nmcli connection modify vlan10 ipv4.addresses 192.168.10.1/24
sudo nmcli connection up vlan10

# Set hostname
sudo hostnamectl set-hostname labhost

# Add FQDN to /etc/hosts
echo "127.0.0.1 labhost.example.com labhost" | sudo tee -a /etc/hosts

# Verify
ip addr show vlan10
hostname
hostnamectl
cat /etc/hosts
```

Grade:
```bash
sudo labctl grade networking-02
```
