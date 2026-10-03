# redis-01: Redis server with a password and persistence

## Hints

1. Settings changed at runtime are lost at a restart. Everything the
   task asks for, except the key, belongs in the Redis configuration
   file, which the comments in the file document setting by setting.
2. The settings to look for in the configuration file are bind,
   requirepass, appendonly, maxmemory and maxmemory-policy. When a
   setting appears twice, the last line wins.
3. The client redis-cli reads the password from the environment
   variable REDISCLI_AUTH, or takes it with its option -a. Its command
   CONFIG GET shows what the running server uses.
4. The firewall needs the port in the running configuration and in the
   permanent one. The command firewall-cmd changes only one of them per
   call unless you reload after a permanent change.

## Solution

1. [sudo] Install Redis:

   ```bash
   rpm -q redis || sudo dnf -y install redis
   ```

2. [sudo] Find the configuration file and the server address, then add
   the settings at the end of the configuration file. A later line
   overrides an earlier one, so the default bind line needs no edit:

   ```bash
   conf=/etc/redis.conf
   [ -f /etc/redis/redis.conf ] && conf=/etc/redis/redis.conf
   addr=$(sed -n 's/^address=//p' /opt/linux-labs/state/redis-01)
   sudo tee -a "$conf" <<END
   bind 127.0.0.1 $addr
   requirepass labredis42
   appendonly yes
   maxmemory 128mb
   maxmemory-policy allkeys-lru
   END
   ```

3. [sudo] Start Redis and enable it at boot:

   ```bash
   sudo systemctl enable --now redis
   ```

4. [sudo] Open the port in the permanent and the running firewall:

   ```bash
   sudo firewall-cmd --permanent --add-port=6379/tcp
   sudo firewall-cmd --reload
   ```

5. [user] Store the key, authenticated with the password:

   ```bash
   REDISCLI_AUTH=labredis42 redis-cli SET lab:status ready
   ```

## Verification

```bash
ss -tln | grep 6379
redis-cli PING
REDISCLI_AUTH=labredis42 redis-cli CONFIG GET maxmemory
REDISCLI_AUTH=labredis42 redis-cli GET lab:status
sudo firewall-cmd --list-ports
labctl grade redis-01
```

## Explanation

Redis reads its configuration file once, at start. CONFIG SET changes
a running server only, and the change is gone after a restart unless
CONFIG REWRITE writes it back to the file. The grader restarts the
service to catch exactly that. The bind setting cannot change at
runtime on Redis 5 at all.

The value 128mb means 128 times 1024 times 1024 bytes, which is
134217728. The value 128m means 128000000 bytes and fails the check.

With appendonly yes Redis logs every write to the append-only file in
its data directory, /var/lib/redis, and replays it at start, so the key
survives a restart. Redis 7 keeps the file in the subdirectory
appendonlydir; Redis 5 and 6 use the single file appendonly.aof. The
same steps work on Rocky Linux 8 and 9; only the path of the
configuration file differs.

redis-cli connects to 127.0.0.1 by default. Passing the password in
REDISCLI_AUTH keeps it out of the process list, where -a would show it.
