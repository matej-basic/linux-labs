# networking-04: IPv6 address and a static route on a free NIC

## Hints

1. Everything goes into one connection profile: the addresses, the
   methods and the routes for both protocols. NetworkManager then
   applies them to the interface and saves them for the next boot.
2. See man nm-settings-nmcli, sections ipv4 and ipv6, for the
   settings method, addresses, gateway and routes. man nmcli-examples
   shows how a profile is created and changed.
3. The method manual turns off DHCP for IPv4 and both stateless
   autoconfiguration and DHCPv6 for IPv6. A route is written as the
   network, a space and the next hop, for example in ipv4.routes.
4. Check the result with the command ip and its options -4 and -6:
   the address and route subcommands show what the kernel uses. An
   IPv6 address marked tentative has not finished duplicate address
   detection yet.

## Solution

1. [user] Find the free interface. The lab writes its name to the
   first line of the state file (here ens224; use your name if it
   differs):

   ```bash
   head -n 1 /opt/linux-labs/state/networking-04
   ip route show default
   nmcli device status
   ```

2. [sudo] Create the profile with both addresses, both methods
   manual and no gateway:

   ```bash
   sudo nmcli connection add type ethernet con-name lab-v6 \
     ifname ens224 autoconnect yes \
     ipv4.method manual ipv4.addresses 192.168.150.10/24 \
     ipv6.method manual ipv6.addresses fd00:150::10/64
   ```

3. [sudo] Add the two static routes to the profile:

   ```bash
   sudo nmcli connection modify lab-v6 \
     ipv4.routes "10.150.0.0/24 192.168.150.254" \
     ipv6.routes "fd00:250::/64 fd00:150::fe"
   ```

4. [sudo] Activate the profile so that the routes are applied:

   ```bash
   sudo nmcli connection up lab-v6
   ```

5. [user] Look at the result:

   ```bash
   ip -br addr show ens224
   ip -4 route show dev ens224
   ip -6 route show dev ens224
   ip route show default
   ```

## Verification

```bash
nmcli -f ipv4.routes,ipv6.routes connection show lab-v6
labctl grade networking-04
```

## Explanation

A NetworkManager profile holds the whole configuration of an
interface, so the addresses and routes survive a reboot. The same
nmcli commands work on Rocky Linux 8 and 9, although Rocky Linux 8
stores the profile as an ifcfg file in
/etc/sysconfig/network-scripts and Rocky Linux 9 as a keyfile in
/etc/NetworkManager/system-connections.

The IPv6 method manual uses only the configured address: no address
from router advertisements and no DHCPv6. The kernel still adds the
link-local fe80:: address, which every IPv6 interface has.

A route is accepted when its gateway is reachable on a connected
network. 192.168.150.254 is inside 192.168.150.0/24 and fd00:150::fe
is inside fd00:150::/64, so both routes are installed even though no
host answers there. Changes made with nmcli connection modify reach
the kernel only when the profile is activated again.

Without a gateway in lab-v6 the profile adds no default route, and
the default route stays on the interface that carries the SSH
session.
