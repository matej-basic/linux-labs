# networking-02: VLAN interface and hostname

## Hints

1. The free interface is the first ethernet device that does not
   carry the default route. Its name is also on the first line of the
   state file mentioned in the task.
2. A VLAN is a NetworkManager connection of its own type. See man
   nm-settings, section vlan, for the parent interface and the ID.
3. With nmcli connection add, use the connection type vlan. The dev
   option names the parent interface and id gives the VLAN ID. Set
   ipv4.method to manual, then activate the profile with the up
   subcommand of nmcli connection.
4. The static hostname is set with hostnamectl, see its
   set-hostname command. The name resolution entry goes into
   /etc/hosts: one line with an address, the full name and the alias.

## Solution

1. [user] Find the free interface. It is the first ethernet interface
   that does not carry the default route, and lab setup also records
   it in the state file:

   ```bash
   ip route show default
   nmcli device status
   head -n 1 /opt/linux-labs/state/networking-02
   ```

2. [sudo] Create the VLAN connection on that interface with the static
   address and bring it up. Replace ens224 with the name from step 1:

   ```bash
   sudo nmcli connection add type vlan con-name vlan10 ifname vlan10 \
     dev ens224 id 10 ipv4.method manual ipv4.addresses 192.168.10.1/24
   sudo nmcli connection up vlan10
   ```

3. [sudo] Set the static hostname:

   ```bash
   sudo hostnamectl set-hostname labhost
   ```

4. [sudo] Add the fully qualified name with the alias to /etc/hosts:

   ```bash
   echo "192.168.10.1 labhost.example.com labhost" |
     sudo tee -a /etc/hosts
   ```

## Verification

```bash
ip -br addr show vlan10
hostnamectl --static
getent hosts labhost.example.com
labctl grade networking-02
```

## Explanation

A NetworkManager connection of type vlan stores the parent interface,
the VLAN ID and the address in a profile under /etc/NetworkManager, so
the configuration survives a reboot. The command "connection up"
applies it now.
The VLAN goes on a free NIC because the default-route interface carries
the SSH session.

hostnamectl set-hostname writes /etc/hostname, which is the static
hostname that persists. The name labhost.example.com resolves through
the hosts entry alone; the entry needs the alias labhost on the same
line, and any address works as long as the grader finds both names.
