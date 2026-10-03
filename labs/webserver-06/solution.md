# webserver-06: Apache with PHP-FPM and a dedicated pool

## Hints

1. PHP-FPM reads one file per pool from /etc/php-fpm.d. The default
   pool www.conf is a full example with comments: a new pool needs its
   own section name, user, socket and process manager settings.
2. A pool socket belongs to root with mode 0660 unless the pool says
   otherwise. Apache connects as the user apache, so the pool has to
   give apache access to its socket, as www.conf does with
   listen.acl_users. Values set with php_admin_value cannot be
   changed by the script.
3. The file php.conf from the php-fpm package sends every .php file to
   the www socket with SetHandler inside FilesMatch. The same block in
   your own virtual host, with the intranet socket, takes precedence
   for that virtual host.
4. If the page returns 404 or 403, read the error logs of Apache and
   PHP-FPM and search the audit log. /srv has no file context rule
   for web content, so semanage fcontext and restorecon are needed.

## Solution

1. [sudo] Install Apache, PHP-FPM and the SELinux management tools.
   On Rocky Linux 8, dnf enables the default stream of the php module
   by itself:

   ```bash
   rpm -q httpd || sudo dnf -y install httpd
   rpm -q php-fpm || sudo dnf -y install php-fpm
   rpm -q policycoreutils-python-utils ||
       sudo dnf -y install policycoreutils-python-utils
   ```

2. [sudo] Create the pool intranet:

   ```bash
   sudo tee /etc/php-fpm.d/intranet.conf <<'CONF'
   [intranet]
   user = phpapp
   group = phpapp
   listen = /run/php-fpm/intranet.sock
   listen.acl_users = apache
   pm = ondemand
   pm.max_children = 5
   pm.process_idle_timeout = 10s
   php_admin_value[memory_limit] = 64M
   php_admin_value[error_log] = /var/log/php-fpm/intranet-error.log
   php_admin_flag[log_errors] = on
   CONF
   sudo php-fpm -t
   ```

3. [sudo] Configure Apache. The virtual host is the only one on port
   80, so it answers for every name and for the address:

   ```bash
   sudo tee /etc/httpd/conf.d/phpapp.conf <<'CONF'
   <VirtualHost *:80>
     ServerName servera
     DocumentRoot /srv/phpapp/public
     <Directory /srv/phpapp/public>
       Options None
       AllowOverride None
       Require all granted
     </Directory>
     <FilesMatch \.php$>
       SetHandler proxy:unix:/run/php-fpm/intranet.sock|fcgi://localhost
     </FilesMatch>
   </VirtualHost>
   CONF
   sudo httpd -t
   ```

4. [sudo] Give the application the web content type, through a file
   context rule:

   ```bash
   sudo semanage fcontext -a -t httpd_sys_content_t \
       '/srv/phpapp/public(/.*)?'
   sudo restorecon -Rv /srv/phpapp/public
   ```

5. [sudo] Start both services and enable them at boot:

   ```bash
   sudo systemctl enable --now php-fpm httpd
   ```

6. [sudo] Open the service http in the default zone, at runtime and
   permanently:

   ```bash
   sudo firewall-cmd --add-service=http
   sudo firewall-cmd --permanent --add-service=http
   ```

7. [user] Request the page and compare the UID:

   ```bash
   curl -s http://localhost/
   id -u phpapp
   ```

## Verification

```bash
ls -lZ /run/php-fpm/
getfacl /run/php-fpm/intranet.sock
labctl grade webserver-06
```

## Explanation

PHP-FPM runs one master process as root and one group of worker
processes per pool. Each pool has its own user, socket and limits, so
two applications on one server cannot read each other's files and a
runaway script hits only its own memory_limit. A value set with
php_admin_value cannot be changed by ini_set in the script; php_value
can.

The master process creates the socket. Without listen.owner,
listen.group or listen.acl_users it belongs to root, the user of the
master, with mode 0660, so Apache gets "Permission denied" and answers
503. listen.acl_users = apache
adds an ACL entry for apache only. A mode of 0666 would also work, but
then every local user could run code as phpapp, which the grader
rejects.

php.conf sets the handler for every .php file to the www socket. The
FilesMatch block inside the virtual host is merged after it, so for
this virtual host the intranet socket wins, and the page shows the UID
of phpapp and 64M instead of 48 and 128M. If the handler is missing
completely, Apache sends the PHP source as text.

Apache and PHP-FPM both run in the SELinux domain httpd_t. The files
under /srv get the type var_t, which httpd_t may not read, so Apache
cannot use index.php and shows its test page with status 403 until
the files carry httpd_sys_content_t. A rule from semanage fcontext
keeps that label through restorecon and a full relabel; chcon alone
would be undone.
