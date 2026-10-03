# webserver-05: Troubleshoot a web site that does not load

## Hints

1. Start with the service itself. The command systemctl status shows
   why httpd is not running, and the journal of the unit has the
   full error message. A configuration test that passes does not
   mean that the service can start.
2. Apache may only bind to ports that carry an SELinux port type for
   the web server. The command semanage port in list mode shows them.
   Either the port gets that type or the extra listener goes.
3. Once httpd runs, a 403 points at access to the files. Compare the
   mode and the SELinux type of the page and its directory with
   /var/www/html, read the error log of the virtual host and search
   the audit log for AVC records with ausearch.
4. A label set with chcon is lost at the next relabel. A file context
   rule added with semanage fcontext and applied with restorecon
   lasts. Last, check the firewall from the workstation: the service
   http must be in the default zone at runtime and permanently.

## Solution

1. [user] Reproduce the failure. Nothing answers on port 80:

   ```bash
   curl -sS http://localhost/
   ```

2. [sudo] Look at the service and its journal. httpd failed to start
   because it may not bind to TCP port 8089:

   ```bash
   systemctl status httpd
   sudo journalctl -u httpd -n 20 --no-pager
   sudo httpd -t
   ```

   The journal shows "Permission denied: AH00072: make_sock: could
   not bind to address [::]:8089", although the configuration
   test passes. Find the listener and check the SELinux port types
   for the web server:

   ```bash
   grep -r Listen /etc/httpd/conf /etc/httpd/conf.d
   sudo semanage port -l | grep -w http_port_t
   ```

   /etc/httpd/conf.d/status.conf adds Listen 8089 for the status page
   of a monitoring agent, and 8089 is not an http_port_t port.

3. [sudo] Give port 8089 the type http_port_t, so the status page
   keeps working. Then start httpd and enable it at boot:

   ```bash
   sudo semanage port -a -t http_port_t -p tcp 8089
   sudo systemctl enable --now httpd
   systemctl is-active httpd
   ```

4. [user] Test again. Apache now answers, but with status 403 and
   the default test page instead of the intranet page:

   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' http://localhost/
   ```

5. [sudo] Read the error log of the virtual host and look at the
   files of the site:

   ```bash
   sudo tail -n 5 /var/log/httpd/intranet_error.log
   ls -ldZ /srv/intranet /srv/intranet/index.html /var/www/html
   ```

   The page has mode 0600, and the directory and the page have the
   type admin_home_t, the type of /root, where the site was built.

6. [sudo] Let others read the page:

   ```bash
   sudo chmod 0644 /srv/intranet/index.html
   ```

7. [sudo] Confirm the SELinux denial, then add a file context rule
   for the site and apply it:

   ```bash
   sudo ausearch -m AVC -ts recent
   sudo semanage fcontext -a -t httpd_sys_content_t \
       '/srv/intranet(/.*)?'
   sudo restorecon -Rv /srv/intranet
   matchpathcon /srv/intranet /srv/intranet/index.html
   curl -s http://localhost/ | grep 'Welcome to the lab intranet'
   ```

8. [sudo] Open the service http in the default zone, at runtime and
   permanently:

   ```bash
   sudo firewall-cmd --add-service=http
   sudo firewall-cmd --permanent --add-service=http
   sudo firewall-cmd --list-services
   ```

9. [user] On the workstation, request the page from servera (use
   the address of servera if the name does not resolve):

   ```bash
   curl -s http://servera/ | grep 'Welcome to the lab intranet'
   ```

## Verification

```bash
systemctl is-enabled httpd
ls -lZ /srv/intranet
labctl grade webserver-05
```

## Explanation

The faults sit in layers, and each one hides the next. httpd -t only
parses the configuration, so it passes, while the start fails when
Apache binds its sockets. SELinux allows httpd_t to bind only to ports
of the type http_port_t, so Listen 8089 fails with Permission denied.
Labelling the port keeps the status listener; removing status.conf
would also fix the start, and the grader accepts both.

With the service running, two independent checks block the page. The
file mode 0600 keeps the user apache out, and the type admin_home_t
keeps the domain httpd_t out. mv keeps the label a file had at its old
place, which is how /root content ends up in /srv with the wrong type.
restorecon alone would not help: without a rule, /srv/intranet gets
the type var_t, which Apache may not read either. The rule from
semanage fcontext makes httpd_sys_content_t the default for the tree,
so restorecon and a full relabel both produce it, while a chcon would
be undone. A permissive domain or an audit2allow module would hide the
denials instead of fixing the label, and the grader rejects both.

Last, the firewall: requests from the server itself never pass the
zone rules, so curl on localhost works while the workstation gets no
answer. A rule without --permanent is lost at the next reload or
reboot, and one with only --permanent does not apply until then.
