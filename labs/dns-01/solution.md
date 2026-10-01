# dns-01: Install and start the BIND DNS server

## Hints

1. Three separate states are graded: packages installed, service
   running, service enabled at boot. The packaged default
   configuration already makes named listen on port 53.
2. Use dnf for the packages and systemctl for the service. In
   man systemctl, look at the enable command and the option that
   starts the unit in the same step.
3. To see the listeners, use ss with the options -l and -n, plus -u
   for UDP or -t for TCP. See man ss.

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
