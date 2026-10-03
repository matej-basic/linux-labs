# fail2ban-02: Custom fail2ban filter and jail for an application log

## Hints

1. A filter is a file with a section [Definition] and a failregex.
   fail2ban fills in the tag <HOST> with a pattern for an address.
   Look at an existing filter in /etc/fail2ban/filter.d, for example
   sshd.conf, and read man jail.conf, section FILTER FILES.
2. The command fail2ban-regex tests a filter against a log file
   without a running server. It accepts a filter name such as labapp
   and reports how many lines matched. Use it until the count is 37.
3. fail2ban removes the timestamp from a line before it applies the
   failregex. What remains starts with a space. Anchor the expression
   at the start of the line, so that LOGIN FAILED inside a note does
   not match.
4. A jail section in jail.d needs enabled, filter, logpath and port.
   The time settings accept units such as 10m. The command
   fail2ban-client get labapp shows the values the server uses.

## Solution

1. [sudo] Install EPEL and fail2ban:

   ```bash
   rpm -q epel-release || sudo dnf -y install epel-release
   rpm -q fail2ban || sudo dnf -y install fail2ban
   ```

2. [sudo] Look at the log. The words LOGIN FAILED appear in more lines
   than the 37 failed logins, because some notes quote them:

   ```bash
   sudo head -20 /var/log/labapp/auth.log
   sudo grep -c 'LOGIN FAILED' /var/log/labapp/auth.log
   ```

3. [sudo] Write the filter. The timestamp is cut out before matching,
   so the line starts with a space:

   ```bash
   sudo tee /etc/fail2ban/filter.d/labapp.local >/dev/null <<'EOF'
   [Definition]
   failregex = ^\s*labapp\[\d+\]: LOGIN FAILED user=\S+ src=<HOST>\s
   ignoreregex =
   EOF
   ```

4. [sudo] Test the filter against the log. The line Lines: must
   report 37 matched:

   ```bash
   sudo fail2ban-regex /var/log/labapp/auth.log labapp
   ```

5. [user] Find the network of the interface with the default route:

   ```bash
   dev=$(ip -4 route show default | awk '{ print $5; exit }')
   net=$(ip -4 route show dev "$dev" scope link proto kernel |
     awk '{ print $1; exit }')
   echo "$dev $net"
   ```

6. [sudo] Write the jail, in the same shell as step 5 so that $net
   holds the network:

   ```bash
   sudo tee /etc/fail2ban/jail.d/labapp.local >/dev/null <<EOF
   [labapp]
   enabled = true
   filter = labapp
   logpath = /var/log/labapp/auth.log
   backend = auto
   port = 8443
   protocol = tcp
   maxretry = 3
   findtime = 10m
   bantime = 30m
   ignoreip = 127.0.0.1/8 ::1 $net
   EOF
   ```

7. [sudo] Enable and start fail2ban, then check the jail:

   ```bash
   sudo systemctl enable fail2ban
   sudo systemctl restart fail2ban
   sudo fail2ban-client status labapp
   sudo fail2ban-client get labapp logpath
   sudo fail2ban-client get labapp ignoreip
   ```

## Verification

```bash
sudo fail2ban-client status labapp
labctl grade fail2ban-02
```

## Explanation

A filter has a failregex with the tag <HOST>, which fail2ban replaces
with an expression for an IPv4 address, an IPv6 address or a host
name. fail2ban finds the timestamp of each line first and cuts it out;
the failregex is applied to the rest, which here starts with the space
after the timestamp. The anchor ^ and the fixed text labapp[pid]:
LOGIN FAILED make sure that only real failed logins match. Without the
anchor the ADMIN UNLOCK lines, whose note quotes a failed login, match
too, and a looser expression such as FAILED followed by src= also
counts the failed password resets. fail2ban-regex shows the count
before the jail runs.

A file in filter.d or jail.d that ends in .local is read after the
.conf file of the same name, or on its own when there is none. The
jail labapp has no section in jail.conf, so its .local file holds all
of its settings. backend auto watches a plain file; the backend
systemd would read the journal instead and ignore logpath.

port and protocol go to the ban action. With the package
fail2ban-firewalld the ban action is firewallcmd-rich-rules, so a ban
is a runtime rich rule that rejects 8443/tcp from that address.

The log already holds 37 failed logins from two days ago. When the
jail starts, it skips lines older than findtime, so those addresses
are not banned. Lines appended while the jail runs count at once:
after 3 of them within 10 minutes the address is banned for 30
minutes. If a running jail sees its log shrink, it reads the file from
the start again and treats the old lines as new; the grader therefore
stops the jail while it removes its test lines.

Rocky Linux 8 has fail2ban 1.0 and Rocky Linux 9 has 1.1 from EPEL.
The filter, the jail and the commands are the same on both.
