# Web Server 02 Solution

Configure Apache virtual hosts and serve content from /var/www/lab2/html.

## Commands to reach the expected state:

```bash
# Create the web directory
sudo mkdir -p /var/www/lab2/html

# Create index.html
sudo tee /var/www/lab2/html/index.html > /dev/null <<EOF
Welcome to Lab 2
EOF

# Add lab2.local to /etc/hosts
echo "127.0.0.1 lab2.local" | sudo tee -a /etc/hosts

# Create virtual host configuration
sudo tee /etc/httpd/conf.d/lab2.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName lab2.local
    ServerAdmin admin@lab2.local
    DocumentRoot /var/www/lab2/html
    
    <Directory /var/www/lab2/html>
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Test Apache configuration
sudo httpd -t

# Restart Apache to apply changes
sudo systemctl restart httpd
```

## Verify:

```bash
# Check directory and files
ls -l /var/www/lab2/html/

# Check /etc/hosts
grep lab2.local /etc/hosts

# Check virtual host config
sudo cat /etc/httpd/conf.d/lab2.conf

# Test connectivity
curl http://lab2.local

# Run the grading script
sudo labctl grade webserver-02
```

