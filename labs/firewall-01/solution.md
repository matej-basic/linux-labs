# firewall-01: Firewalld services and ports

## Hints

1. Both rules go to the running firewall of the public zone, and the
   command firewall-cmd can name the zone explicitly.
2. Look in man firewall-cmd under the options for services and for
   ports. The firewall-cmd command also has list options to check the
   result.
3. The options are --add-service and --add-port. A port is written as
   number, slash, protocol. Without --permanent the change is runtime
   only, which is enough here.

## Solution

1. [sudo] Make sure firewalld is running:

   ```bash
   sudo systemctl start firewalld
   ```

2. [sudo] Allow the http service in the public zone:

   ```bash
   sudo firewall-cmd --zone=public --add-service=http
   ```

3. [sudo] Open port 8080/tcp in the public zone:

   ```bash
   sudo firewall-cmd --zone=public --add-port=8080/tcp
   ```

4. [sudo] List the zone to check the runtime rules:

   ```bash
   sudo firewall-cmd --zone=public --list-all
   ```

## Verification

```bash
labctl grade firewall-01
```

## Explanation

Without --permanent, firewall-cmd changes only the running firewall,
and the changes apply at once. The grader asks the running firewall,
so permanent-only rules without a reload would not count. A reload or
reboot drops runtime-only rules, which is why real servers use
--permanent as well. The ssh service is part of the public zone and
stays untouched.
