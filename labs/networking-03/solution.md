# networking-03: Network bonding with failover

## Solution

1. [user] Find the interface that carries the default route and the
   free Ethernet interfaces. The free ones are the two to use (here
   ens224 and ens256; use your names if they differ):

   ```bash
   ip route show default
   nmcli device status
   ```

2. [sudo] Create the bond in active-backup mode with link monitoring
   every 100 ms and the static address:

   ```bash
   sudo nmcli connection add type bond con-name bond0 ifname bond0 \
     bond.options "mode=active-backup,miimon=100" \
     ipv4.method manual ipv4.addresses 192.168.100.1/24
   ```

3. [sudo] Add the two free interfaces as ports of bond0:

   ```bash
   sudo nmcli connection add type ethernet slave-type bond \
     con-name bond0-port1 ifname ens224 master bond0
   sudo nmcli connection add type ethernet slave-type bond \
     con-name bond0-port2 ifname ens256 master bond0
   ```

4. [sudo] Activate the bond and then the ports:

   ```bash
   sudo nmcli connection up bond0
   sudo nmcli connection up bond0-port1
   sudo nmcli connection up bond0-port2
   ```

5. [user] Look at the result:

   ```bash
   ip -br addr show bond0
   cat /proc/net/bonding/bond0
   ```

## Verification

```bash
nmcli -f NAME,TYPE,DEVICE connection show
cat /proc/net/bonding/bond0
labctl grade networking-03
```

## Explanation

Bonding is used on both Rocky Linux 8 and 9. Teaming (teamd) is
deprecated on RHEL 9, so a lab that works on both releases uses the
kernel bonding driver, which NetworkManager configures directly.

In active-backup mode one port carries traffic and the other waits.
When the link of the active port fails, the miimon check (every 100 ms)
notices it and the bond switches to the other port. The address
belongs to bond0, not to the ports, so it does not change on failover.

The ports are separate saved profiles with master bond0, which makes
the configuration persistent. Activating bond0 does not necessarily
activate its ports, so each port profile is brought up as well.

Never use the interface with the default route as a port: the SSH
session runs over it. The grader checks that the default route still
uses its original interface.
