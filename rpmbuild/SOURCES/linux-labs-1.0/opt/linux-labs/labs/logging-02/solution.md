# Logging 02 Solution

## Steps
1) Create rsyslog rules for myapp using local0 and programname
```bash
sudo tee /etc/rsyslog.d/myapp.conf >/dev/null <<'EOF'
local0.* /var/log/myapp.log
& stop
:programname, isequal, "myapp" /var/log/myapp-program.log
& stop
EOF
sudo systemctl reload rsyslog
```

2) Create log files with correct permissions
```bash
sudo touch /var/log/myapp.log
sudo touch /var/log/myapp-program.log
sudo chmod 644 /var/log/myapp.log
sudo chmod 644 /var/log/myapp-program.log
```

3) Configure logrotate (cover both logs)
```bash
sudo tee /etc/logrotate.d/myapp >/dev/null <<'EOF'
/var/log/myapp.log /var/log/myapp-program.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 644 root root
    postrotate
        /bin/kill -HUP $(cat /var/run/syslogd.pid 2>/dev/null) 2>/dev/null || true
    endscript
}
EOF
sudo logrotate -d /etc/logrotate.d/myapp
```

4) (Optional) Send a test message using local0
```bash
logger -p local0.info -t myapp "Test message"
grep "Test message" /var/log/myapp.log
logger -t myapp "Program message"
grep "Program message" /var/log/myapp-program.log
```

Run grader when ready:
```bash
sudo labctl grade logging-02
```
