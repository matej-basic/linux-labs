# webserver-02: Apache name-based virtual host

## Hints

1. Four things have to line up: the page content, name resolution, a
   virtual host definition and a running service that has loaded it.
2. For the name, see man hosts and the file /etc/hosts. For the
   virtual host, put a file under /etc/httpd/conf.d and read the
   Apache documentation on name-based virtual hosts.
3. The block needs the directives ServerName and DocumentRoot, and a
   Directory block that grants access, because the path is outside the
   default web root configuration.
4. Check the syntax with the -t option of httpd, and compare with
   the -S option, which lists the virtual hosts Apache loaded. A
   configuration change needs a restart or reload.

## Solution

1. [sudo] Install Apache, enable it and start it:

   ```bash
   sudo dnf -y install httpd
   sudo systemctl enable --now httpd
   ```

2. [sudo] Create the document root and the page:

   ```bash
   sudo mkdir -p /var/www/lab2/html
   echo "Welcome to Lab 2" | sudo tee /var/www/lab2/html/index.html
   ```

3. [sudo] Make lab2.local resolve to the local machine:

   ```bash
   echo "127.0.0.1 lab2.local" | sudo tee -a /etc/hosts
   ```

4. [sudo] Create the virtual host:

   ```bash
   sudo tee /etc/httpd/conf.d/lab2.conf > /dev/null <<'CONF'
   <VirtualHost *:80>
       ServerName lab2.local
       DocumentRoot /var/www/lab2/html
       <Directory /var/www/lab2/html>
           Require all granted
       </Directory>
   </VirtualHost>
   CONF
   ```

5. [sudo] Check the syntax and restart Apache:

   ```bash
   sudo httpd -t
   sudo systemctl restart httpd
   ```

## Verification

```bash
curl -i http://lab2.local/
sudo httpd -S
labctl grade webserver-02
```

## Explanation

Apache picks a virtual host by the Host header of the request. The
name lab2.local is not in DNS, so the hosts file maps it to 127.0.0.1,
and the ServerName in the virtual host makes Apache answer that name
with the lab2 directory instead of the default /var/www/html.

The new directory is created under /var/www, so it inherits the SELinux
type httpd_sys_content_t and Apache can read it with SELinux enforcing.
Files copied in from another location would keep their old label and
cause a 403 error. Outside /var/www and /srv, Require all granted is
also needed, because Apache denies access to other directories by
default.

A configuration change takes effect only after Apache is restarted or
reloaded, which is why the grader requests the page from the running
service.
