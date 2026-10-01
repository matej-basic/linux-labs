# selinux-03: SELinux labels for Apache on a non-standard port

## Solution

1. [sudo] Look at the current assignment of port 8081 and at the
   label of the content:

   ```bash
   sudo semanage port -l | grep -w 8081
   ls -dZ /webapp/porttest
   ```

2. [sudo] Label TCP port 8081 as http_port_t. If the default policy
   already assigns 8081 to another type (for example
   transproxy_port_t), the first command fails with "already
   defined"; modify the entry instead:

   ```bash
   sudo semanage port -a -t http_port_t -p tcp 8081 \
     || sudo semanage port -m -t http_port_t -p tcp 8081
   ```

3. [sudo] Add a persistent file context rule and apply it:

   ```bash
   sudo semanage fcontext -a -t httpd_sys_content_t \
     "/webapp/porttest(/.*)?"
   sudo restorecon -Rv /webapp/porttest
   ```

4. [sudo] Start Apache and check it:

   ```bash
   sudo systemctl start httpd
   systemctl status httpd --no-pager
   ```

5. [user] Request the page:

   ```bash
   curl http://localhost:8081/
   ```

## Verification

```bash
ls -dZ /webapp/porttest /webapp/porttest/index.html
ss -ltn 'sport = :8081'
labctl grade selinux-03
```

## Explanation

httpd_t may only bind to ports labeled http_port_t, so Apache fails to
start on 8081 until the port carries that type. When another type owns
the port in the default policy, the mapping has to be modified and not
added.

The content under /webapp has the type default_t, which httpd_t cannot
read, so the page would return 403. chcon changes only the current
label and is lost on a relabel; semanage fcontext writes the rule into
the policy and restorecon applies it, which is what the grader checks.
Setting SELinux to permissive or disabling it would also make Apache
work, and is the wrong answer here.
