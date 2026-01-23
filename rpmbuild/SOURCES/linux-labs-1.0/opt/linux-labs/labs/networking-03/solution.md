# Networking 03 Solution

Configure network teaming or bonding:

## Option 1: Teaming

```bash
# Find available interfaces
IFACE1=$(ip link show | grep -E '^[0-9]+: (eth|ens)' | head -n1 | cut -d: -f2 | tr -d ' ')
IFACE2=$(ip link show | grep -E '^[0-9]+: (eth|ens)' | tail -n1 | cut -d: -f2 | tr -d ' ')
echo "Using interfaces: $IFACE1 and $IFACE2"

# Create team interface
sudo nmcli connection add type team con-name team0 ifname team0
sudo nmcli connection modify team0 ipv4.method manual
sudo nmcli connection modify team0 ipv4.addresses 192.168.100.1/24

# Add slave interfaces
sudo nmcli connection add type team-slave con-name team0-"$IFACE1" ifname "$IFACE1" master team0
sudo nmcli connection add type team-slave con-name team0-"$IFACE2" ifname "$IFACE2" master team0

# Bring up connections
sudo nmcli connection up team0
sudo nmcli connection up team0-eth0
sudo nmcli connection up team0-eth1

# Verify
ip addr show team0
nmcli connection show team0
```

## Option 2: Bonding

```bash
# Find available interfaces
IFACE1=$(ip link show | grep -E '^[0-9]+: (eth|ens)' | head -n1 | cut -d: -f2 | tr -d ' ')
IFACE2=$(ip link show | grep -E '^[0-9]+: (eth|ens)' | tail -n1 | cut -d: -f2 | tr -d ' ')
echo "Using interfaces: $IFACE1 and $IFACE2"

# Create bond interface
sudo nmcli connection add type bond con-name bond0 ifname bond0 bond.options 'mode=active-backup'
sudo nmcli connection modify bond0 ipv4.method manual
sudo nmcli connection modify bond0 ipv4.addresses 192.168.100.1/24

# Add slave interfaces
sudo nmcli connection add type bond-slave con-name bond0-"$IFACE1" ifname "$IFACE1" master bond0
sudo nmcli connection add type bond-slave con-name bond0-"$IFACE2" ifname "$IFACE2" master bond0

# Bring up connection
sudo nmcli connection up bond0

# Verify
ip addr show bond0
cat /proc/net/bonding/bond0
```

## Test Failover

```bash
# Bring down one interface
IFACE1=$(ip link show | grep -E '^[0-9]+: (eth|ens)' | head -n1 | cut -d: -f2 | tr -d ' ')
sudo ip link set "$IFACE1" down

# Check connectivity still works
ping -c 3 192.168.100.1

# Restore interface
sudo ip link set "$IFACE1" up
```

Grade:
```bash
sudo labctl grade networking-03
```
