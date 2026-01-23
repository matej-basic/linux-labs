# Scheduling 01 Solution

Create a daily cron job for root user:

```bash
# Edit root crontab
sudo crontab -e

# Add this line (in the editor):
0 2 * * * echo 'Daily task executed' >> /var/log/daily-task.log

# Save and exit editor

# Verify cron entry was added
sudo crontab -l

# Check log file location
ls -l /var/log/daily-task.log 2>/dev/null || echo "Log will be created on next run"
```

Grade:
```bash
sudo labctl grade scheduling-01
```
