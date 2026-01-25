# Logging 03 Solution

Enable persistent journal, create failing service, and use analysis commands:

```bash
# Persistent journal
sudo mkdir -p /var/log/journal
sudo chmod 755 /var/log/journal
sudo systemctl restart systemd-journald
journalctl --disk-usage
ls -l /var/log/journal

# Query boots
journalctl --list-boots
journalctl -b -1 -n 20
journalctl -b -p info -n 20
systemd-analyze time
systemd-analyze blame

# Test failing service
sudo tee /etc/systemd/system/labtest-fail.service >/dev/null <<'EOF'
[Unit]
Description=Lab Test Failing Service
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo LABTEST: Service starting; exit 1'
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start labtest-fail.service || true
systemctl status labtest-fail.service || true
journalctl -u labtest-fail.service -p err -n 20

# Kernel messages
journalctl -b -g kernel -n 20
journalctl -b -1 -g kernel -n 20 2>/dev/null || true
dmesg | tail -n 20
```

Grade:
```bash
sudo labctl grade logging-03
```
