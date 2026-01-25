# Web Server 03 Solution

Configure HTTPS/SSL certificate for Apache and redirect HTTP to HTTPS.

## Commands to reach the expected state:

```bash
# Install mod_ssl if not already installed
sudo yum install -y mod_ssl

# Create the web directory
sudo mkdir -p /var/www/lab3/html

# Create index.html
sudo tee /var/www/lab3/html/index.html > /dev/null <<EOF
Lab 3 HTTPS
EOF

# Add lab3.local to /etc/hosts
echo "127.0.0.1 lab3.local" | sudo tee -a /etc/hosts

# Generate self-signed SSL certificate and private key
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/pki/tls/private/lab3.key \
    -out /etc/pki/tls/certs/lab3.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=lab3.local"

# Create virtual host configuration with HTTPS redirect
sudo tee /etc/httpd/conf.d/lab3.conf > /dev/null <<EOF
# HTTP Virtual Host - Redirect to HTTPS
<VirtualHost *:80>
    ServerName lab3.local
    Redirect permanent / https://lab3.local/
</VirtualHost>

# HTTPS Virtual Host
<VirtualHost *:443>
    ServerName lab3.local
    ServerAdmin admin@lab3.local
    DocumentRoot /var/www/lab3/html
    
    SSLEngine on
    SSLCertificateFile /etc/pki/tls/certs/lab3.crt
    SSLCertificateKeyFile /etc/pki/tls/private/lab3.key
    
    <Directory /var/www/lab3/html>
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
ls -l /var/www/lab3/html/

# Check /etc/hosts
grep lab3.local /etc/hosts

# Check certificate
sudo openssl x509 -in /etc/pki/tls/certs/lab3.crt -text -noout

# Check virtual host config
sudo cat /etc/httpd/conf.d/lab3.conf

# Test HTTPS connectivity (ignore certificate warnings)
curl -k https://lab3.local

# Run the grading script
sudo labctl grade webserver-03
```

