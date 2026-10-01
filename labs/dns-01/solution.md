# dns-01: Install and start the BIND DNS server

## Solution

1. [sudo] Install the packages:

   ```bash
   sudo dnf -y install bind bind-utils
   ```

2. [sudo] Start named and enable it at boot:

   ```bash
   sudo systemctl enable --now named
   ```

3. [sudo] Confirm that named listens on port 53 for UDP and TCP:

   ```bash
   sudo ss -ulnp | grep ':53 '
   sudo ss -tlnp | grep ':53 '
   ```

## Verification

```bash
dig @127.0.0.1 localhost
labctl grade dns-01
```

## Explanation

The default named.conf from the bind package makes named listen on
127.0.0.1 and ::1, port 53, for both UDP and TCP, so installing and
starting the service is enough. enable --now does the start and the
boot setting in one step. The grader asks systemd for the service
state and looks at the listening sockets without naming the process,
so named has to be running for the socket checks to mean anything.
