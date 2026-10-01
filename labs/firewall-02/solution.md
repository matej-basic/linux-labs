# firewall-02: Rich rules and zone assignment

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
   it to the trusted zone in the permanent configuration:

   ```bash
   IFACE=$(head -n 1 /opt/linux-labs/state/firewall-02)
   sudo firewall-cmd --permanent --zone=trusted \
     --change-interface="$IFACE"
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
change-interface moves an interface out of the zone it is in, where
add-interface refuses with a zone conflict if NetworkManager already
bound it to another zone.
