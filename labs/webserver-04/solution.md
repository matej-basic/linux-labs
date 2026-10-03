# webserver-04: Nginx HTTPS reverse proxy for a local application

## Hints

1. Work in layers: package, certificate, nginx server blocks, then
   SELinux and the firewall. Test each layer with curl on the server
   before you go to the next one.
2. The command openssl req creates a key and a self-signed certificate
   in one run; see man openssl-req for the subject and the extension
   options. A file in /etc/nginx/conf.d can hold two server blocks: one
   for port 80 and one for port 443 with ssl.
3. The directives proxy_pass and proxy_set_header come from the
   ngx_http_proxy_module documentation. The variables $scheme,
   $proxy_add_x_forwarded_for, $host and $request_uri hold what the
   headers and the redirect need.
4. A proxy that answers 502 Bad Gateway with SELinux enforcing has its
   connection denied. nginx runs in the domain httpd_t; look for a
   boolean about network connections with getsebool, and make the
   change persistent.

## Solution

1. [sudo] Install nginx:

   ```bash
   rpm -q nginx || sudo dnf -y install nginx
   ```

2. [sudo] Create the key and the self-signed certificate, and protect
   the key:

   ```bash
   sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout /etc/pki/tls/private/app.lab.local.key \
     -out /etc/pki/tls/certs/app.lab.local.crt \
     -subj "/CN=app.lab.local" \
     -addext "subjectAltName=DNS:app.lab.local"
   sudo chown root:root /etc/pki/tls/private/app.lab.local.key
   sudo chmod 0600 /etc/pki/tls/private/app.lab.local.key
   ```

3. [sudo] Write the two server blocks and test the configuration:

   ```bash
   sudo tee /etc/nginx/conf.d/app.lab.local.conf >/dev/null <<'EOT'
   server {
       listen 80;
       server_name app.lab.local;
       return 301 https://$host$request_uri;
   }

   server {
       listen 443 ssl;
       server_name app.lab.local;
       ssl_certificate /etc/pki/tls/certs/app.lab.local.crt;
       ssl_certificate_key /etc/pki/tls/private/app.lab.local.key;

       location / {
           proxy_pass http://127.0.0.1:8081;
           proxy_set_header Host $host;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   EOT
   sudo nginx -t
   ```

4. [sudo] Allow nginx to open network connections, persistently:

   ```bash
   sudo setsebool -P httpd_can_network_connect on
   ```

5. [sudo] Start nginx and enable it at boot:

   ```bash
   sudo systemctl enable --now nginx
   ```

6. [sudo] Open HTTP and HTTPS in the firewall, now and permanently:

   ```bash
   sudo firewall-cmd --add-service=http --add-service=https
   sudo firewall-cmd --permanent --add-service=http --add-service=https
   ```

7. [user] Test the proxy with the lab name sent to 127.0.0.1:

   ```bash
   curl -k --resolve app.lab.local:443:127.0.0.1 https://app.lab.local/
   curl -k --resolve app.lab.local:443:127.0.0.1 \
     https://app.lab.local/headers
   curl -I --resolve app.lab.local:80:127.0.0.1 http://app.lab.local/a
   ```

## Verification

```bash
labctl grade webserver-04
```

## Explanation

The stock nginx.conf on Rocky 8 and 9 keeps its own default server on
port 80. The new port 80 block does not conflict with it, because nginx
picks the server block by the Host header: requests for app.lab.local
get the redirect, others still get the default page. $request_uri
carries the path and the query string into the redirect.

proxy_pass sends every request to the application. $scheme is https in
the TLS server, and $proxy_add_x_forwarded_for appends the client
address to an X-Forwarded-For header the client may have sent.

Without the SELinux change nginx answers 502 Bad Gateway, and the
audit log shows a denied name_connect: httpd_t may not connect to port
8081, which is labelled transproxy_port_t. The boolean
httpd_can_network_connect allows any outgoing TCP connection, and -P
writes it to the policy so that it survives a reboot. Changing the
label of port 8081 to http_port_t with semanage port -m is not enough:
with the default booleans of Rocky 8 and 9 nginx still answers 502,
and the lab grades the boolean.

The commands work on both releases. Rocky 8 ships nginx 1.14 and
Rocky 9 a newer release; only the HTTP/2 syntax differs, and HTTP/2 is
not graded. The certificate and the key keep the default context
cert_t of /etc/pki/tls, which nginx may read.
