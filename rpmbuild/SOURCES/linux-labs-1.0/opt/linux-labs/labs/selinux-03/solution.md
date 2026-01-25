# Solution: selinux-03 (SELinux port labeling for Apache on 8081)

Goal: allow Apache (`httpd_t`) to bind and serve HTTP on TCP port 8081 by labeling the port, not by disabling SELinux.

```bash
# 1) Inspect SELinux port mappings for httpd
semanage port -l | grep http_port_t || sudo dnf install -y policycoreutils-python-utils

# 2) Add port 8081 to http_port_t
sudo semanage port -a -t http_port_t -p tcp 8081

# 3) Label the content for httpd
sudo chcon -R -t httpd_sys_content_t /webapp/porttest

# 4) Start Apache
sudo systemctl start httpd
sudo systemctl status httpd --no-pager

# 5) Verify the page
curl -s http://localhost:8081/

# 6) Grade
sudo labctl grade selinux-03
```
