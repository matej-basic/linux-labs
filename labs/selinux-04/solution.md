# selinux-04: SELinux booleans for Apache user directories

## Hints

1. Reproduce the failure and read both the Apache error log and the
   audit log. A permission problem in the file system hides the
   SELinux denial until it is fixed, so fix and test in turns.
2. Apache runs as the user apache, which is neither the owner nor in
   the group of webdev. To reach a file it needs the search
   permission on every directory in the path and the read permission
   on the file itself.
3. The command ausearch can select AVC records of the last minutes,
   and audit2why explains a denial and names the boolean that would
   allow it. semanage boolean in list mode describes every boolean.
4. The command setsebool changes a boolean only in the running policy
   unless it gets the option for a persistent change. Check the
   result with semanage boolean in list mode, which shows the current
   and the persistent value.

## Solution

1. [user] Reproduce the failure:

   ```bash
   curl -s http://localhost/~webdev/
   ```

   Apache answers 403 Forbidden.

2. [sudo] Read the Apache error log. It says that search permissions
   are missing on a component of the path:

   ```bash
   sudo tail -n 5 /var/log/httpd/error_log
   sudo ls -ld /home/webdev /home/webdev/public_html
   ```

3. [sudo] Give others only the search permission on the home
   directory, and let them read and search public_html:

   ```bash
   sudo chmod o=x /home/webdev
   sudo chmod o=rx /home/webdev/public_html
   ```

4. [user] Test again. The request still fails, now because of
   SELinux:

   ```bash
   curl -s http://localhost/~webdev/
   ```

5. [sudo] Find the denial in the audit log and let audit2why explain
   it. It names the boolean httpd_enable_homedirs, and also
   httpd_unified, which allows much more and is not the answer here:

   ```bash
   sudo ausearch -m AVC -ts recent
   sudo ausearch -m AVC -ts recent | audit2why
   ```

6. [sudo] Turn the boolean on, now and persistently, and check both
   values:

   ```bash
   sudo setsebool -P httpd_enable_homedirs on
   getsebool httpd_enable_homedirs
   sudo semanage boolean -l | grep httpd_enable_homedirs
   ```

7. [sudo] Enable httpd at boot. It is already running:

   ```bash
   sudo systemctl enable --now httpd
   ```

8. [user] Request the page:

   ```bash
   curl -s http://localhost/~webdev/
   ```

## Verification

```bash
ls -ld /home/webdev /home/webdev/public_html
getenforce
labctl grade selinux-04
```

## Explanation

Two independent checks block Apache. The kernel checks the normal file
permissions first: the home directory has mode 0700, so the user apache
cannot even enter it, and the request fails before SELinux is asked.
That is why the audit log shows nothing at first, and the Apache error
log names the missing search permission. The search bit alone is enough
on the home directory; read would let every user list it.

Once the permissions are right, SELinux denies httpd_t access to the
files in public_html, which have the type httpd_user_content_t. The
policy already has a rule for this case, switched off by default: the
boolean httpd_enable_homedirs. audit2why points to it, next to
httpd_unified, which would give Apache write access to all its content
types as well. Without -P, setsebool changes only the running policy and
the change is lost at the next reboot; semanage boolean -l shows the
current and the persistent value side by side.

audit2allow could build a module that allows the same access, and a
permissive domain or permissive mode would hide the denials. Both widen
the policy more than needed, and the grader rejects them.
