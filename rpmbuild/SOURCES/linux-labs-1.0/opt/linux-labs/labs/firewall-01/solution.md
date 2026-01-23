# Firewall 01 Solution

Temporary rules in public zone:

```bash
# Ensure firewalld running
sudo systemctl start firewalld

# Add service and port (non-permanent)
sudo firewall-cmd --zone=public --add-service=http
sudo firewall-cmd --zone=public --add-port=8080/tcp

# View
sudo firewall-cmd --zone=public --list-all

# Grade
sudo labctl grade firewall-01
```

(Optional cleanup after grading):
```bash
sudo firewall-cmd --zone=public --remove-service=http
sudo firewall-cmd --zone=public --remove-port=8080/tcp
```
