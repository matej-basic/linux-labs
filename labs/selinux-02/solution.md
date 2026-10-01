# selinux-02: SELinux contexts for a web application

## Hints

1. Files created under /webapp get a generic default type that httpd
   is not allowed to read. Request the page and look at the type
   with the -Z option of ls, then at the AVC denial in the audit log.
2. A label set with chcon is lost on a relabel. A rule that survives
   one is stored with semanage fcontext (man semanage-fcontext) and
   applied with restorecon.
3. The rule needs the type httpd_sys_rw_content_t and a path
   expression that matches /webapp/www and everything below it, so it
   ends in a regular expression for optional subpaths. Do not match
   the other /webapp directories.
4. Apply the rule with restorecon and its -R option, then check the
   result with ls -dZ. The virtual host needs ServerName,
   DocumentRoot and a Directory block that grants access.

## Solution

1. [sudo] Install Apache and enable it:

   ```bash
   sudo dnf -y install httpd
   sudo systemctl enable httpd
   ```

2. [sudo] Create the virtual host:

   ```bash
   sudo tee /etc/httpd/conf.d/myapp.conf >/dev/null <<'EOF'
   <VirtualHost *:80>
       ServerName localhost
       DocumentRoot /webapp/www
       <Directory /webapp/www>
           Require all granted
       </Directory>
   </VirtualHost>
   EOF
   ```

3. [sudo] Start httpd and look at the problem. The request is denied
   because /webapp/www has the type default_t:

   ```bash
   sudo systemctl restart httpd
   curl -sI http://localhost/ | head -n 1
   ls -dZ /webapp/www
   sudo ausearch -m avc -ts recent
   ```

4. [sudo] Add a persistent file context rule for /webapp/www and apply
   it:

   ```bash
   sudo semanage fcontext -a -t httpd_sys_rw_content_t \
     '/webapp/www(/.*)?'
   sudo restorecon -Rv /webapp/www
   ```

## Verification

```bash
ls -dZ /webapp/www /webapp/www/index.html /webapp/config
curl http://localhost/
labctl grade selinux-02
```

## Explanation

Files created under /webapp get the type default_t, which httpd_t may
not read, so Apache answers 403 and logs an AVC denial. The fix is to
label the content with a type httpd may use. chcon changes the label
only until the next relabel; semanage fcontext stores a rule in the
policy so restorecon, and a full relabel, give the same result. The
rule matches /webapp/www and everything below it, and leaves
/webapp/config and /webapp/data with their default type, so Apache
cannot read the database configuration.

httpd_sys_content_t would be enough for a read-only site. The lab asks
for httpd_sys_rw_content_t, which also lets httpd write to the tree.
Switching SELinux to permissive mode would make the page work as well,
but it removes the protection for the whole system, and the grader
checks for enforcing mode.
