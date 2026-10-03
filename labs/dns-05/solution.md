# dns-05: Name resolution fails on a client

## Hints

1. Follow a lookup the way the system resolver does it: the hosts line
   of /etc/nsswitch.conf sets the order of the sources, /etc/hosts
   comes first, then the DNS servers in /etc/resolv.conf. Compare these
   servers with the ones NetworkManager has for the connection.
2. NetworkManager writes /etc/resolv.conf only when its configuration
   allows it. The command NetworkManager has an option that prints the
   configuration it reads from all files, and its journal messages
   with dns-mgr name the mode it uses.
3. Some files keep their content even when root tries to replace them.
   The command lsattr shows such file attributes.
4. After a change of its configuration, NetworkManager must reload it.
   The command nmcli has a general command for that, which leaves the
   active connections alone.

## Solution

1. [user] Look at the resolver configuration and compare it with the
   DNS servers that NetworkManager has for the connection:

   ```bash
   cat /etc/resolv.conf
   grep '^hosts:' /etc/nsswitch.conf
   getent ahosts rockylinux.org
   getent ahosts www.rockylinux.org
   nmcli -g IP4.DNS device show
   ```

2. [sudo] Find the setting that keeps NetworkManager away from
   /etc/resolv.conf:

   ```bash
   sudo NetworkManager --print-config | sed -n '/^\[main\]/,/^\[/p'
   sudo grep -rn 'dns\|rc-manager' /etc/NetworkManager/conf.d/ \
     /etc/NetworkManager/NetworkManager.conf
   sudo journalctl -u NetworkManager | grep dns-mgr | tail -n 3
   ```

3. [sudo] Remove the file that sets dns=none:

   ```bash
   sudo rm /etc/NetworkManager/conf.d/90-lab.conf
   ```

4. [sudo] Remove the immutable attribute from /etc/resolv.conf:

   ```bash
   lsattr /etc/resolv.conf
   sudo chattr -i /etc/resolv.conf
   ```

5. [sudo] Reload the configuration of NetworkManager. It rewrites
   /etc/resolv.conf with the DNS servers of the connection:

   ```bash
   sudo nmcli general reload
   cat /etc/resolv.conf
   ```

6. [sudo] Delete the stale line for www.rockylinux.org from /etc/hosts:

   ```bash
   grep -n 'www.rockylinux.org' /etc/hosts
   sudo sed -i '/[[:space:]]www\.rockylinux\.org/d' /etc/hosts
   ```

7. [user] Check both names again:

   ```bash
   getent ahosts rockylinux.org
   getent ahosts www.rockylinux.org
   ```

## Verification

```bash
lsattr /etc/resolv.conf
head -n 1 /etc/resolv.conf
labctl grade dns-05
```

## Explanation

Three faults stacked up. /etc/hosts had a stale line that sent
www.rockylinux.org to 192.0.2.80, and since the hosts line of
/etc/nsswitch.conf lists files before dns, that line wins over any DNS
answer. A file in /etc/NetworkManager/conf.d set dns=none, so
NetworkManager stopped writing /etc/resolv.conf, and a hand-written
file pointed the resolver at 192.0.2.53, an address from the
documentation range TEST-NET-1 where no server answers. That file also
had the immutable attribute: even root cannot change, replace or
delete it until chattr -i removes the attribute. With the attribute
set, NetworkManager detects the file and logs rc-manager=immutable
instead of writing it.

nmcli general reload rereads the configuration files and rewrites
/etc/resolv.conf, without touching the active connections. Restarting
NetworkManager would work too, but reactivating or modifying the
connection of the default-route interface would cut the SSH session,
and adding DNS servers to its profile would hide the real problem.
Tools such as dig and host from bind-utils query DNS directly and
ignore /etc/hosts, so only getent shows what programs really get. The
same commands work on Rocky Linux 8 (NetworkManager 1.40) and 9
(NetworkManager 1.54).
