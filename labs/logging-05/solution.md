# logging-05: Central rsyslog server over TCP

## Hints

1. Node 1 needs a TCP input module and a rule that writes only the
   messages of that input. A ruleset bound to the input keeps the
   remote messages apart from the local ones.
2. In rsyslog, a template of type string can hold a file path with the
   property HOSTNAME in it. The omfile action uses such a template as
   its dynaFile parameter.
3. On node 2 the omfwd action sends messages to another host. Its
   parameters target, port and protocol pick the server and TCP, and
   the queue parameters (queue.type, queue.filename) and
   action.resumeRetryCount belong in the same action.
4. Check a configuration with the rsyslogd option -N1 before the
   restart. The firewall needs the port in both configurations.

## Solution

1. [user] From the workstation, log in to node 1 as opsadmin. Use the
   node 1 address from the TOPOLOGY section of the task:

   ```bash
   ssh opsadmin@172.25.250.10
   ```

2. [sudo] On node 1, create the drop-in file for the server. The
   ruleset is bound to the TCP input, so only remote messages reach
   it, and they do not go to the rules of /etc/rsyslog.conf:

   ```bash
   sudo tee /etc/rsyslog.d/remote-server.conf <<'EOF'
   module(load="imtcp")

   template(name="RemoteHostFile" type="string"
            string="/var/log/remote/%HOSTNAME%/messages")

   ruleset(name="remote") {
       action(type="omfile" dynaFile="RemoteHostFile")
   }

   input(type="imtcp" port="514" ruleset="remote")
   EOF
   ```

3. [sudo] Check the configuration, then enable and restart rsyslog:

   ```bash
   sudo rsyslogd -N1
   sudo systemctl enable rsyslog
   sudo systemctl restart rsyslog
   sudo ss -ltnp | grep ':514 '
   ```

4. [sudo] Open 514/tcp in the firewall, now and permanently:

   ```bash
   sudo firewall-cmd --add-port=514/tcp
   sudo firewall-cmd --permanent --add-port=514/tcp
   ```

5. [user] Log out of node 1 and log in to node 2 from the
   workstation:

   ```bash
   exit
   ssh opsadmin@172.25.250.11
   ```

6. [sudo] On node 2, create the drop-in file for the forwarding. Use
   the node 1 address from the task:

   ```bash
   sudo tee /etc/rsyslog.d/forward.conf <<'EOF'
   *.info action(type="omfwd" target="172.25.250.10" port="514"
                 protocol="tcp"
                 queue.type="LinkedList" queue.filename="fwd_node1"
                 queue.maxDiskSpace="100m" queue.saveOnShutdown="on"
                 action.resumeRetryCount="-1")
   EOF
   ```

7. [sudo] Check the configuration, then enable and restart rsyslog:

   ```bash
   sudo rsyslogd -N1
   sudo systemctl enable rsyslog
   sudo systemctl restart rsyslog
   ```

## Verification

On node 2:

```bash
logger -p user.info "test message from node 2"
```

On node 1:

```bash
sudo tail /var/log/remote/serverb/messages
```

On the workstation:

```bash
labctl grade logging-05
```

## Explanation

imtcp opens the TCP listener. Bound to an input, a ruleset processes
only the messages of that input, so the messages from other hosts go
through the omfile action of the ruleset alone. The local messages,
which rsyslog reads from the journal, still run through the rules of
/etc/rsyslog.conf and stay out of /var/log/remote. A rule with the
property fromhost-ip in the default ruleset would work as well, but
the remote messages would then also land in /var/log/messages unless
a stop follows.

dynaFile takes the name of a template and builds the file name for
every message. %HOSTNAME% is the host name the sender wrote into the
message, the short name serverb here. omfile creates the missing
directories under /var/log/remote by itself.

On node 2, omfwd with protocol tcp is the RainerScript form of the
legacy `@@host:514` action. queue.type LinkedList with queue.filename
makes the action queue disk-assisted: it stays in memory while node 1
answers and spills to files in the work directory /var/lib/rsyslog
when node 1 is down and the queue fills or rsyslog stops
(queue.saveOnShutdown). action.resumeRetryCount -1 makes rsyslog retry
the action forever instead of dropping messages after the first
failure.

Port 514/tcp has the SELinux type syslogd_port_t on Rocky Linux 8 and
9, so the listener needs no port label. The firewall needs the port in
the runtime configuration for now and in the permanent one for the
next reload or boot. The same files work on Rocky Linux 8 and 9.
