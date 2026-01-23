# Solution: firewall-03

```bash
# Enable masquerading on internal zone
sudo firewall-cmd --permanent --zone=internal --add-masquerade

# Port forward 8443->443 in public zone
sudo firewall-cmd --permanent --zone=public --add-forward-port=port=8443:proto=tcp:toport=443

# Create custom service (custom-app) with TCP/UDP 9090
sudo bash -c 'cat > /etc/firewalld/services/custom-app.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>custom-app</short>
  <description>Sample Custom Application Service</description>
  <port protocol="tcp" port="9090"/>
  <port protocol="udp" port="9090"/>
</service>
EOF'

# Add services to public zone
sudo firewall-cmd --permanent --zone=public --add-service=custom-app
sudo firewall-cmd --permanent --zone=public --add-service=http

# Reload
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --zone=internal --query-masquerade
sudo firewall-cmd --zone=public --list-forward-ports | grep 8443
sudo firewall-cmd --zone=public --list-services | grep custom-app
sudo firewall-cmd --zone=public --list-services | grep http

# Grade
sudo labctl grade firewall-03
```
