# firewall-03: Masquerading, port forwarding and custom services

## Solution

1. [sudo] Make sure firewalld is enabled and running:

   ```bash
   sudo systemctl enable --now firewalld
   ```

2. [sudo] Enable masquerading in the internal zone and add the port
   forward and the http service to the public zone (permanent):

   ```bash
   sudo firewall-cmd --permanent --zone=internal --add-masquerade
   sudo firewall-cmd --permanent --zone=public \
     --add-forward-port=port=8443:proto=tcp:toport=443
   sudo firewall-cmd --permanent --zone=public --add-service=http
   ```

3. [sudo] Define the custom service. This creates
   /etc/firewalld/services/custom-app.xml:

   ```bash
   sudo firewall-cmd --permanent --new-service=custom-app
   sudo firewall-cmd --permanent --service=custom-app \
     --set-description="Sample Custom Application Service"
   sudo firewall-cmd --permanent --service=custom-app \
     --add-port=9090/tcp
   sudo firewall-cmd --permanent --service=custom-app \
     --add-port=9090/udp
   ```

4. [sudo] Allow the service in the public zone and reload:

   ```bash
   sudo firewall-cmd --permanent --zone=public --add-service=custom-app
   sudo firewall-cmd --reload
   ```

## Verification

```bash
sudo firewall-cmd --zone=internal --query-masquerade
sudo firewall-cmd --zone=public --list-all
sudo firewall-cmd --info-service=custom-app
labctl grade firewall-03
```

## Explanation

With --permanent the changes go to the configuration on disk and the
running firewall is not touched until the reload, which is why step 4
ends with it. A service must exist in the permanent configuration
before it can be added to a zone, so the definition comes first.

The grader reads both the permanent configuration and the running
firewall. A forgotten reload fails the last criterion, and a rule added
only at runtime fails the permanent ones. The forward rule must have no
destination address, so it applies to the local host.
