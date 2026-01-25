# Logging 01 Solution

Run these journalctl examples (sudo if needed):

```bash
journalctl -u systemd-logind -n 5
journalctl -p err -n 5
journalctl -S '1 hour ago' -n 5
journalctl -u systemd-logind -p err -n 5
journalctl -b -n 20
journalctl -p err,warning -n 5
```

Follow live if desired:
```bash
journalctl -f
```

Grade:
```bash
sudo labctl grade logging-01
```
