# Firewall 02 Solution

Permanent rich rule and trusted interface:

```bash
sudo systemctl start firewalld

# Add rich rule for 443/tcp from 192.168.1.0/24 (public zone)
sudo firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port protocol="tcp" port="443" accept' --permanent

# Pick an existing interface for trusted zone (replace IFACE as needed)
IFACE=$(ip -o link show | awk -F': ' '/eth|ens/{print $2; exit}')
sudo firewall-cmd --zone=trusted --add-interface="$IFACE" --permanent

# Reload to apply
sudo firewall-cmd --reload

# Checks
sudo firewall-cmd --zone=public --list-rich-rules
sudo firewall-cmd --get-active-zones

# Grade
sudo labctl grade firewall-02
```
