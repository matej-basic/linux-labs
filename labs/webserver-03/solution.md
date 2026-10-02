# webserver-03: HTTPS with a self-signed certificate

## Hints

1. Work in layers: packages, name resolution, content, certificate,
   virtual hosts. The certificate and the virtual hosts are where
   most mistakes happen.
2. For the certificate, see man openssl-req. It can create a key and a
   self-signed certificate in one run, and the common name must match
   the host name.
3. The mod_ssl package adds /etc/httpd/conf.d/ssl.conf. In your own
   file you need two virtual hosts: one for port 80 and one for port
   443.
4. The first host needs the Redirect directive with the permanent
   keyword. The second needs SSLEngine, SSLCertificateFile and
   SSLCertificateKeyFile next to ServerName and DocumentRoot.

## Solution

1. [sudo] Install Apache and the TLS module, whichever is missing
   (an installed package is not upgraded):

   ```bash
   rpm -q httpd || sudo dnf -y install httpd
   rpm -q mod_ssl || sudo dnf -y install mod_ssl
   ```

2. [sudo] Make lab3.local resolve to the local machine:

   ```bash
   echo "127.0.0.1 lab3.local" | sudo tee -a /etc/hosts
   ```

3. [sudo] Create the document root and the page:

   ```bash
   sudo mkdir -p /var/www/lab3/html
   echo "Lab 3 HTTPS" | sudo tee /var/www/lab3/html/index.html
   ```

4. [sudo] Create the self-signed certificate and key:

   ```bash
   sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout /etc/pki/tls/private/lab3.key \
     -out /etc/pki/tls/certs/lab3.crt \
     -subj "/C=US/ST=State/L=City/O=Lab/CN=lab3.local"
   ```

5. [sudo] Write the virtual hosts:

   ```bash
   sudo tee /etc/httpd/conf.d/lab3.conf > /dev/null <<'EOT'
   <VirtualHost *:80>
       ServerName lab3.local
       Redirect permanent / https://lab3.local/
   </VirtualHost>

   <VirtualHost *:443>
       ServerName lab3.local
       DocumentRoot /var/www/lab3/html
       SSLEngine on
       SSLCertificateFile /etc/pki/tls/certs/lab3.crt
       SSLCertificateKeyFile /etc/pki/tls/private/lab3.key
       <Directory /var/www/lab3/html>
           Require all granted
       </Directory>
   </VirtualHost>
   EOT
   ```

6. [sudo] Start httpd, enable it at boot and check the syntax:

   ```bash
   sudo systemctl enable --now httpd
   sudo httpd -t
   ```

## Verification

```bash
curl -I http://lab3.local/
curl -k https://lab3.local/
labctl grade webserver-03
```

## Explanation

Start httpd before running httpd -t: ssl.conf points at
/etc/pki/tls/certs/localhost.crt, which the httpd-init service creates
on the first start, so the syntax check fails on a fresh install until
then.

mod_ssl adds /etc/httpd/conf.d/ssl.conf, which makes httpd listen on
port 443 with a default virtual host. The lab3.local virtual host is
chosen through the server name the client sends (SNI), so its own
certificate is presented. The port 80 virtual host answers every
request with a 301 redirect, which is what Redirect permanent sends.

The files stay in the default SELinux contexts: /var/www gives the
document root httpd_sys_content_t, and /etc/pki/tls gives the
certificate and key cert_t, both readable by httpd. The curl tests use
-k because the certificate is self-signed and not trusted.
