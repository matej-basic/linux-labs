# networking-05: A network connection that does not come up

## Hints

1. Try to activate labnet and read the error message carefully. The
   command nmcli device status lists the real interface names, and
   the profile must name one of them.
2. An activation that hangs for about 45 seconds and then fails
   waits for an answer that never comes. Compare the IPv4 method of
   labnet with what the isolated network offers. man
   nm-settings-nmcli, section ipv4, lists the methods.
3. A profile that works when activated by hand may still not come up
   at boot. Look at the setting connection.autoconnect of labnet.
4. List all profiles with the command nmcli connection show and look
   for others on the same interface. Of several profiles that connect
   automatically, the one with the highest
   connection.autoconnect-priority wins.

## Solution

1. [user] Find the free interface and look at the profiles. Here the
   interface is ens224; use your name if it differs:

   ```bash
   head -n 1 /opt/linux-labs/state/networking-05
   ip route show default
   nmcli device status
   nmcli connection show
   ```

   labnet-old is active on ens224 with 192.168.5.10/24, and labnet is
   not active.

2. [sudo] Try to activate labnet and read the error:

   ```bash
   sudo nmcli connection up labnet
   ```

   It fails with "No suitable device found for this connection" and
   "mismatching interface name".

3. [user] Look at the settings of labnet:

   ```bash
   nmcli -f connection.interface-name,connection.autoconnect,\
   ipv4.method,ipv4.addresses,ipv4.gateway connection show labnet
   ```

   The interface name is ens2240, a device that does not exist. The
   IPv4 method is auto, so NetworkManager waits for DHCP even though
   an address is configured, and autoconnect is off.

4. [sudo] Fix the three settings of labnet:

   ```bash
   sudo nmcli connection modify labnet \
     connection.interface-name ens224 ipv4.method manual \
     connection.autoconnect yes
   ```

5. [sudo] Remove labnet-old. It connects automatically with a higher
   autoconnect priority, so it would take the interface at every
   boot:

   ```bash
   sudo nmcli connection delete labnet-old
   ```

6. [sudo] Activate labnet:

   ```bash
   sudo nmcli connection up labnet
   ```

7. [user] Check the result:

   ```bash
   ip -br addr show ens224
   ip route show default
   nmcli -f NAME,AUTOCONNECT,AUTOCONNECT-PRIORITY,DEVICE \
     connection show
   ```

## Verification

```bash
nmcli -f GENERAL.STATE,GENERAL.DEVICES connection show labnet
labctl grade networking-05
```

## Explanation

labnet had three faults, and each one hid the next. A profile bound
to an interface name that does not exist can never be activated, and
nmcli says so at once. With the name fixed, the method auto starts
DHCP. There is no DHCP server on the isolated network, so the
activation fails after the DHCP timeout of 45 seconds with "IP
configuration could not be reserved". A static address in
ipv4.addresses does not help, because with the method auto it is only
added on top of a DHCP lease. The method manual uses the configured
address alone. Rocky Linux 8 and 9 show the same messages.

With autoconnect off, labnet works until the next reboot only. And
when several profiles fit one device, NetworkManager activates the
one with the highest autoconnect priority, so labnet-old would win
at boot. Deleting labnet-old or turning off its autoconnect both
leave labnet as the only candidate.

Without a gateway, labnet adds no default route, and the default
route stays on the interface that carries the SSH session.
