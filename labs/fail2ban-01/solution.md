# fail2ban-01: Protect SSH with fail2ban

## Hints

1. fail2ban is not in the Rocky Linux repositories. The extras
   repository, which is enabled by default, has a package that
   adds the EPEL repository.
2. Leave jail.conf as the package ships it; its own header says so.
   Settings in jail.local or in jail.d override it, section by
   section. The jail sshd already has a section in jail.conf, so your
   section needs only the lines you change. Read man jail.conf.
3. The time settings accept units such as 10m and 1h. The command
   ip route shows which interface carries the default route and
   which network that interface is on.
4. The command fail2ban-client asks the running server for the
   values it really uses, for example the subcommands status sshd
   and get sshd ignoreip.

## Solution

1. [sudo] Install EPEL and fail2ban. The package fail2ban also
   installs fail2ban-firewalld, which makes firewalld rich rules the
   default ban action:

   ```bash
   rpm -q epel-release || sudo dnf -y install epel-release
   rpm -q fail2ban || sudo dnf -y install fail2ban
   ```

2. [user] Find the network of the interface with the default route.
   The kernel route of that interface is the network:

   ```bash
   dev=$(ip -4 route show default | awk '{ print $5; exit }')
   net=$(ip -4 route show dev "$dev" scope link proto kernel |
     awk '{ print $1; exit }')
   echo "$dev $net"
   ```

3. [sudo] Write the jail settings to /etc/fail2ban/jail.local, in the
   same shell as step 2 so that $net holds the network:

   ```bash
   sudo tee /etc/fail2ban/jail.local >/dev/null <<EOF
   [sshd]
   enabled = true
   maxretry = 4
   findtime = 15m
   bantime = 1h
   ignoreip = 127.0.0.1/8 ::1 $net
   EOF
   ```

4. [sudo] Enable and start fail2ban. A restart also loads a changed
   configuration when the service was running already:

   ```bash
   sudo systemctl enable fail2ban
   sudo systemctl restart fail2ban
   ```

5. [sudo] Check the jail and the values it uses:

   ```bash
   sudo fail2ban-client status sshd
   sudo fail2ban-client get sshd maxretry
   sudo fail2ban-client get sshd findtime
   sudo fail2ban-client get sshd bantime
   sudo fail2ban-client get sshd ignoreip
   sudo fail2ban-client get sshd actions
   ```

6. [sudo] Test a ban with a documentation address, look at the
   firewalld rule and unban it again:

   ```bash
   sudo fail2ban-client set sshd banip 192.0.2.77
   sudo firewall-cmd --list-rich-rules
   sudo fail2ban-client set sshd unbanip 192.0.2.77
   sudo firewall-cmd --list-rich-rules
   ```

## Verification

```bash
sudo fail2ban-client status sshd
labctl grade fail2ban-01
```

## Explanation

fail2ban reads jail.conf first, then jail.d/*.conf, jail.local and
jail.d/*.local, in this order. A later file overrides single settings
of a section, so jail.local needs only the lines that differ.
jail.conf belongs to the package and stays as shipped: rpm then keeps
it in step with package updates, and your changes live in one small
file. A jail.conf changed by mistake comes back when you delete it and
reinstall the package fail2ban-server.

The jail sshd reads failed logins from the systemd journal. When an
address fails maxretry times within findtime, fail2ban runs the ban
action for bantime. The package fail2ban-firewalld sets the ban action
to firewallcmd-rich-rules in jail.d/00-firewalld.conf, so a ban is a
runtime rich rule that rejects SSH from that address. Stopping
fail2ban removes its rules again.

The default findtime of jail.conf is 10m, so the jail needs its own
findtime line for the 15 minutes the task asks for.

ignoreip protects addresses that must never be banned. Here it holds
the loopback addresses and the local network, which includes the
workstation. A ban of the workstation would lock labctl out of the
server. The grader reloads fail2ban before it reads the values, so
settings changed only at runtime with fail2ban-client set do not
count.

Rocky Linux 8 has fail2ban 1.0 and Rocky Linux 9 has 1.1 from EPEL.
The configuration and the fail2ban-client commands are the same on
both.
