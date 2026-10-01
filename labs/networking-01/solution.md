# networking-01: Static IP address and DNS with NetworkManager

## Solution

1. [user] Find the interface that carries the default route and the
   free ethernet interfaces:

   ```bash
   ip route show default
   nmcli device status
   ```

   The free interface is the first ethernet device that is not the
   one in the default route. Below it is called ens224; use the
   name you found.

2. [sudo] Create the profile on the free interface, with a static
   address and DNS, no gateway, and no default route:

   ```bash
   sudo nmcli connection add type ethernet con-name labnet-static \
     ifname ens224 ipv4.method manual ipv4.addresses 192.168.1.100/24 \
     ipv4.dns 8.8.8.8 ipv4.never-default yes
   ```

3. [sudo] Activate the profile:

   ```bash
   sudo nmcli connection up labnet-static
   ```

4. [user] Check the result:

   ```bash
   ip -4 addr show dev ens224
   ip route show default
   nmcli connection show labnet-static
   ```

## Verification

```bash
labctl grade networking-01
```

## Explanation

The lab uses a free NIC so the SSH session on the default-route
interface is never interrupted. A gateway on the profile would add a
second default route and could send traffic into an isolated network,
so the profile has no gateway and sets ipv4.never-default. The
ipv4.method manual setting turns off DHCP on the profile, and the
address needs its prefix length (/24). The grader checks both the
saved profile and the live state: the profile is active and the
address is on the interface.
