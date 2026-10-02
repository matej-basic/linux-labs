# firewall-02: Rich rules and zone assignment

## Hints

1. Two things must exist twice: the rich rule and the interface
   assignment each need the running and the permanent configuration.
   The free interface name is on the first line of the state file,
   and NetworkManager manages it through the connection fwlab.
2. For the rule, read man firewalld.richlanguage: it describes the
   family, source, port and action elements. For the interface, look
   at the zone options in man firewall-cmd.
3. Use --add-rich-rule for the rule and --change-interface for the
   interface, both with --permanent and --zone. For an interface that
   NetworkManager manages, firewall-cmd stores the zone in the
   connection profile. The values in the rule are quoted, so put the
   whole rule in single quotes.
4. A permanent change does not touch the running firewall. Look for
   the option of the command firewall-cmd that loads the permanent
   configuration.

## Solution

1. [sudo] Make sure firewalld is enabled and running:

   ```bash
   sudo systemctl enable --now firewalld
   ```

2. [sudo] Add the rich rule to the permanent configuration of the
   public zone:

   ```bash
   RULE='rule family="ipv4" source address="192.168.1.0/24"'
   RULE="$RULE port port=\"443\" protocol=\"tcp\" accept"
   sudo firewall-cmd --permanent --zone=public --add-rich-rule="$RULE"
   ```

3. [sudo] Read the free interface name from the state file and assign
   it to the trusted zone in the permanent configuration. The interface
   is managed by NetworkManager, so firewall-cmd sets the zone of the
   active connection fwlab and NetworkManager applies it at once:

   ```bash
   IFACE=$(head -n 1 /opt/linux-labs/state/firewall-02)
   sudo firewall-cmd --permanent --zone=trusted \
     --change-interface="$IFACE"
   nmcli -g connection.zone connection show fwlab
   ```

   The same result with nmcli alone:

   ```bash
   sudo nmcli connection modify fwlab connection.zone trusted
   sudo nmcli connection up fwlab
   ```

4. [sudo] Reload so that the permanent configuration becomes the
   running one:

   ```bash
   sudo firewall-cmd --reload
   ```

## Verification

```bash
sudo firewall-cmd --zone=public --list-rich-rules
IFACE=$(head -n 1 /opt/linux-labs/state/firewall-02)
sudo firewall-cmd --get-zone-of-interface="$IFACE"
nmcli -g connection.zone connection show fwlab
labctl grade firewall-02
```

## Explanation

A rich rule is a single expression with a source, a port and an action.
The public zone keeps denying everything else, so only hosts in
192.168.1.0/24 reach port 443. Changes made with --permanent do not
touch the running firewall until a reload, which is why the reload is
the last step. Without --permanent the change is lost at the next
reload or reboot, and the grader checks both configurations.

The trusted zone accepts all traffic on the interfaces assigned to it,
so assign only the free interface, never the one that carries SSH.

When NetworkManager activates a connection, it tells firewalld the
zone of that connection, and an empty zone means the default zone. For
an interface that NetworkManager manages, the zone in the connection
profile is therefore the permanent assignment. firewall-cmd knows this:
with --permanent it writes the zone into the active connection instead
of a zone file. An interface listed only in a zone file returns to the
default zone at the next activation, which is why the grader checks
the zone of fwlab. The automatic connections stay off during the lab
because every DHCP attempt is such an activation.
