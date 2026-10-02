# webserver-01: Install and run Apache HTTP Server

## Hints

1. The package and the service are two separate things. The package
   comes from the repositories, the service is controlled through
   systemd.
2. Look at the dnf install command for the package, and at the enable
   and start subcommands in man systemctl.
3. One systemctl option on the enable subcommand also starts the unit
   in the same step. The default configuration already listens on
   port 80.

## Solution

1. [sudo] Install the Apache HTTP Server package:

   ```bash
   rpm -q httpd || sudo dnf -y install httpd
   ```

2. [sudo] Start the service and enable it at boot:

   ```bash
   sudo systemctl enable --now httpd
   ```

3. [user] Check that Apache answers on port 80:

   ```bash
   curl -sI http://localhost
   ```

## Verification

```bash
rpm -q httpd
systemctl is-active httpd
sudo ss -tlnp 'sport = :80'
labctl grade webserver-01
```

## Explanation

The command rpm -q checks first, so dnf only installs httpd when it is
missing and never upgrades an installed package. The httpd package
ships a unit file that listens on port 80 by default, so no
configuration change is needed. The command enable --now both starts
the service and creates the boot-time link, which covers two criteria
in one step.

On a fresh install without content, Apache serves its test page, and
depending on the release the status code can be 403 rather than 200.
That is still a valid answer from Apache, so the grader accepts any
HTTP status. The firewall stays closed to other hosts, which does not
affect requests to localhost.
