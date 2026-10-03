# webserver-08: Apache basic auth and IP access control

## Hints

1. Apache decides access per directory. A Directory block for each of
   the two subdirectories, in a file of its own under
   /etc/httpd/conf.d, keeps the rest of the site as it is.
2. The tool htpasswd from the package httpd-tools writes the password
   file. Its option -c creates a new file and replaces an existing
   one, so use it for the first user only. Its option -B selects
   bcrypt.
3. Basic authentication needs AuthType, AuthName, AuthUserFile and
   Require valid-user. The directive Require ip limits a directory to
   client addresses.
4. Require local also accepts a request whose client address is the
   server's own address, so a request to the default route address
   from the machine itself passes. List 127.0.0.1 and ::1 instead.
   The group apache needs read access to the password file.

## Solution

1. [sudo] Install Apache. The package httpd-tools with htpasswd comes
   with it:

   ```bash
   rpm -q httpd || sudo dnf -y install httpd
   ```

2. [sudo] Create the password file with bcrypt hashes. The option -c
   creates the file for the first user only. Without -b, htpasswd asks
   for the password twice; -b takes it from the command line, which
   leaves it in the shell history:

   ```bash
   sudo htpasswd -c -B -b /etc/httpd/lab.htpasswd alice redwood42
   sudo htpasswd -B -b /etc/httpd/lab.htpasswd bob seashell17
   sudo chown root:apache /etc/httpd/lab.htpasswd
   sudo chmod 0640 /etc/httpd/lab.htpasswd
   ```

3. [sudo] Write the access rules for the two directories:

   ```bash
   sudo tee /etc/httpd/conf.d/lab-access.conf <<'CONF'
   <Directory "/var/www/html/private">
       AuthType Basic
       AuthName "Private area"
       AuthUserFile /etc/httpd/lab.htpasswd
       Require valid-user
   </Directory>

   <Directory "/var/www/html/admin">
       Require ip 127.0.0.1 ::1
   </Directory>
   CONF
   ```

4. [sudo] Check the configuration, then start httpd and enable it at
   boot:

   ```bash
   sudo apachectl configtest
   sudo systemctl enable --now httpd
   ```

5. [sudo] Allow http in the default zone, at runtime and permanently:

   ```bash
   sudo firewall-cmd --add-service=http
   sudo firewall-cmd --permanent --add-service=http
   ```

6. [user] Test every rule. The address of the default route interface
   is found first:

   ```bash
   dev=$(ip -4 route show default | awk '{ print $5; exit }')
   addr=$(ip -4 -o addr show dev "$dev" |
       awk '{ split($4, a, "/"); print a[1]; exit }')
   curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/private/
   curl -s -u alice:redwood42 http://127.0.0.1/private/
   curl -s -u bob:seashell17 http://127.0.0.1/private/
   curl -s http://127.0.0.1/admin/
   curl -s -o /dev/null -w '%{http_code}\n' "http://$addr/admin/"
   ```

## Verification

```bash
labctl grade webserver-08
```

## Explanation

Basic authentication sends the user name and password with every
request, encoded but not encrypted, so on a real network it belongs
behind HTTPS. The server compares the password with the hash in the
file named by AuthUserFile. htpasswd writes MD5 hashes in the Apache
format ($apr1$) by default and bcrypt ($2y$) with -B. On Linux Apache
does not accept passwords in plain text in this file: it treats the
field as a crypt() hash, and the login fails.

httpd reads the password file as the user apache on every request,
not at start, so the file needs read access for apache. Group apache
with mode 0640 gives it that and keeps everyone else out. A file
created in /etc/httpd gets the SELinux type httpd_config_t, which
httpd may read; a file moved there from a home directory keeps its
old type and needs restorecon.

Require ip compares the client address of the connection. A request
from the machine to its own network address leaves through the
loopback interface but keeps that address as the source, so it is not
127.0.0.1. Require local accepts it anyway, because that rule also
matches when the client and the server address are the same. Hence
the explicit address list.

The rest of /var/www/html keeps the rule from httpd.conf, Require all
granted, so the public page needs no change. Rocky Linux 8 and 9 ship
Apache 2.4 with the same modules for these directives.
