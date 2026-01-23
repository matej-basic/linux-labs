# Firewall 03 Solution

Masquerade internal, forward 8443->443, add custom service and http to public:

```bash
sudo systemctl start firewalld

# Enable masquerade on internal
sudo firewall-cmd --zone=internal --add-masquerade --permanent

# Port forward 8443 -> 443 on public
sudo firewall-cmd --zone=public --add-forward-port=port=8443:proto=tcp:toport=443 --permanent

# Custom service definition
sudo tee /etc/firewalld/services/custom-app.xml >/dev/null <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>custom-app</short>
  <description>Sample Custom Application Service</description>
  <port protocol="tcp" port="9090"/>
  <port protocol="udp" port="9090"/>
</service>
EOF

# Load service and add to public
sudo firewall-cmd --reload
sudo firewall-cmd --permanent --zone=public --add-service=custom-app

# Add http to public
sudo firewall-cmd --permanent --zone=public --add-service=http

# Reload to apply
sudo firewall-cmd --reload

# Checks
sudo firewall-cmd --permanent --zone=internal --query-masquerade
sudo firewall-cmd --permanent --zone=public --list-forward-ports
sudo firewall-cmd --permanent --zone=public --list-services

# Grade
sudo labctl grade firewall-03
```
