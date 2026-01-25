# Web Server 01 Solution

Install and start Apache HTTP Server.

## Commands to reach the expected state:

```bash
# Install Apache HTTP Server
sudo yum install -y httpd

# Start the Apache service
sudo systemctl start httpd

# Enable Apache to start on boot
sudo systemctl enable httpd
```

## Verify:

```bash
# Check if httpd is installed
rpm -q httpd

# Check if httpd is running
sudo systemctl status httpd

# Check if port 80 is listening
sudo ss -tlnp | grep :80

# Test connectivity
curl http://localhost

# Run the grading script
sudo labctl grade webserver-01
```

