# Solution: systemd-01 (basic service management)

```bash
# 1) Enable test-service to start at boot
sudo systemctl enable test-service.service

# 2) Start the service
sudo systemctl start test-service.service

# 3) Verify it's enabled
sudo systemctl is-enabled test-service.service

# 4) Verify it's running
sudo systemctl is-active test-service.service
sudo systemctl status test-service.service

# 5) Grade
sudo labctl grade systemd-01
```
