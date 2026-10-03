# webserver-07: Internal CA and a trusted HTTPS certificate

## Hints

1. Work in the order a real request goes: key and signing request,
   signature by the CA, Apache, name resolution, trust store, then
   SELinux and the firewall. Test each layer with curl and openssl
   before the next.
2. The command openssl req creates a key and a certificate signing
   request in one run. The command openssl x509 with the option -req
   signs a request with the options -CA and -CAkey. See
   man openssl-x509.
3. A subject alternative name is an extension. A request does not
   carry it into the certificate by default, so give it to the signing
   step in an extension file with -extfile, which works with OpenSSL
   1.1.1 and 3. The syntax is in man x509v3_config.
4. Three things block a first attempt. The trust store uses a new
   anchor only after update-ca-trust has rebuilt the extracted
   bundles. httpd.conf grants access to no directory outside /var/www,
   so the virtual host needs a Directory block for /srv/intranet. And
   /srv has no file context rule for web content, so semanage fcontext
   and restorecon are needed.

## Solution

1. [sudo] Install Apache, its TLS module and the SELinux management
   tools:

   ```bash
   rpm -q httpd || sudo dnf -y install httpd
   rpm -q mod_ssl || sudo dnf -y install mod_ssl
   rpm -q policycoreutils-python-utils ||
       sudo dnf -y install policycoreutils-python-utils
   ```

2. [sudo] Create the server key and a certificate signing request. The
   request goes to the CA directory:

   ```bash
   sudo openssl req -new -newkey rsa:2048 -nodes \
       -keyout /etc/pki/tls/private/intranet.lab.example.key \
       -out /srv/lab-ca/intranet.lab.example.csr \
       -subj "/O=Lab Example/CN=intranet.lab.example"
   sudo chmod 0600 /etc/pki/tls/private/intranet.lab.example.key
   ```

3. [sudo] Sign the request with the company CA for 730 days. The
   extension file adds the subject alternative names and marks the
   certificate as a server certificate:

   ```bash
   sudo tee /srv/lab-ca/intranet.ext <<'EXT'
   basicConstraints = CA:FALSE
   keyUsage = critical, digitalSignature, keyEncipherment
   extendedKeyUsage = serverAuth
   subjectAltName = DNS:intranet.lab.example, DNS:servera
   EXT
   sudo openssl x509 -req -in /srv/lab-ca/intranet.lab.example.csr \
       -CA /srv/lab-ca/ca.crt -CAkey /srv/lab-ca/ca.key \
       -CAcreateserial -days 730 -sha256 \
       -extfile /srv/lab-ca/intranet.ext \
       -out /etc/pki/tls/certs/intranet.lab.example.crt
   openssl verify -CAfile /srv/lab-ca/ca.crt \
       /etc/pki/tls/certs/intranet.lab.example.crt
   ```

4. [sudo] Give the site the web content type, through a file context
   rule:

   ```bash
   sudo semanage fcontext -a -t httpd_sys_content_t \
       '/srv/intranet(/.*)?'
   sudo restorecon -Rv /srv/intranet
   ```

5. [sudo] Write the virtual host, check it, then start httpd and
   enable it at boot:

   ```bash
   sudo tee /etc/httpd/conf.d/intranet.conf <<'CONF'
   <VirtualHost *:443>
     ServerName intranet.lab.example
     DocumentRoot /srv/intranet
     SSLEngine on
     SSLCertificateFile /etc/pki/tls/certs/intranet.lab.example.crt
     SSLCertificateKeyFile /etc/pki/tls/private/intranet.lab.example.key
     <Directory /srv/intranet>
       Options None
       AllowOverride None
       Require all granted
     </Directory>
   </VirtualHost>
   CONF
   sudo systemctl enable --now httpd
   sudo apachectl configtest
   ```

6. [sudo] Map the name to the address of the interface with the
   default route:

   ```bash
   dev=$(ip -4 route show default | awk '{ print $5; exit }')
   addr=$(ip -4 -o addr show dev "$dev" |
       awk '{ split($4, a, "/"); print a[1]; exit }')
   echo "$addr intranet.lab.example" | sudo tee -a /etc/hosts
   ```

7. [sudo] Trust the company CA system wide:

   ```bash
   sudo cp /srv/lab-ca/ca.crt \
       /etc/pki/ca-trust/source/anchors/lab-example-ca.crt
   sudo update-ca-trust extract
   ```

8. [sudo] Allow https in the default zone, at runtime and permanently:

   ```bash
   sudo firewall-cmd --add-service=https
   sudo firewall-cmd --permanent --add-service=https
   ```

9. [user] Request the page without disabling certificate checks:

   ```bash
   curl https://intranet.lab.example/
   ```

## Verification

```bash
openssl s_client -connect intranet.lab.example:443 \
    -servername intranet.lab.example </dev/null | head -n 20
labctl grade webserver-07
```

## Explanation

The CA signs a request, not a key: the request carries the public key
and the subject, and the CA adds its own name as issuer and signs the
result with its private key. Clients that trust the CA certificate
then trust every certificate it signed, so one anchor covers all
intranet sites.

Browsers and curl match the host name against the subject alternative
names only and ignore the common name. openssl x509 -req copies no
extensions from the request, so the names come from the extension
file. OpenSSL 3 also has -copy_extensions, but OpenSSL 1.1.1 on Rocky
Linux 8 does not; -extfile works on both. The CA uses an RSA 2048 key
and SHA-256, which the DEFAULT crypto policy of Rocky Linux 9 accepts;
a SHA-1 signature would be rejected there.

update-ca-trust merges the anchors with the bundled CAs into the files
under /etc/pki/ca-trust/extracted, which curl, openssl and most other
programs read. A file in the anchors directory alone changes nothing
until that step.

httpd.conf denies access to the whole file system and grants it again
only for /var/www, so a document root under /srv needs its own
Directory block with Require all granted. Without it the site answers
403 and Apache shows its test page.

The key and certificate created in /etc/pki/tls get the type cert_t.
A file created elsewhere and moved there keeps its old label, so run
restorecon on it. The files under /srv get var_t, which httpd may not
read, so the site answers 403 until the files carry
httpd_sys_content_t. A rule from semanage fcontext keeps that label
through restorecon and a full relabel.
