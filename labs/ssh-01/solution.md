# ssh-01: SSH key authentication and a client host alias

## Hints

1. Three pieces work together: a key pair in your own ~/.ssh, the
   public half in the authorized_keys file of the target account, and
   a Host block in your client configuration. Do them in this order.
2. The command ssh-keygen chooses the key type, the output file and
   the passphrase with options. Read man ssh-keygen. deploy has no
   password, so ssh-copy-id cannot log in to install the key: copy the
   public key with sudo instead.
3. sshd ignores authorized_keys when the directory or the file is
   writable by others or owned by another user. Check ownership and
   modes with ls -la as root.
4. In man ssh_config, a Host block needs HostName, User and
   IdentityFile. The command ssh -G prints what an alias resolves to.

## Solution

1. [user] Create the key pair without a passphrase:

   ```bash
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   ssh-keygen -t ed25519 -N '' -f ~/.ssh/deploy_ed25519
   ```

2. [sudo] Create the .ssh directory of deploy and install the public
   key as its authorized_keys file, with owner, modes and SELinux
   context:

   ```bash
   sudo install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
   sudo install -m 600 -o deploy -g deploy ~/.ssh/deploy_ed25519.pub \
     /home/deploy/.ssh/authorized_keys
   sudo restorecon -Rv /home/deploy/.ssh
   ```

3. [user] Add the host alias to your client configuration:

   ```bash
   cat >> ~/.ssh/config <<'CONFIG'
   Host deploy-local
       HostName localhost
       User deploy
       IdentityFile ~/.ssh/deploy_ed25519
   CONFIG
   chmod 600 ~/.ssh/config
   ```

4. [user] Log in through the alias. Answer yes when ssh asks to confirm
   the host key of localhost:

   ```bash
   ssh deploy-local id -un
   ```

## Verification

```bash
ls -l ~/.ssh/deploy_ed25519*
sudo ls -laZ /home/deploy/.ssh
ssh -G deploy-local | grep -E '^(user|hostname|identityfile) '
ssh -o BatchMode=yes deploy-local id -un
labctl grade ssh-01
```

## Explanation

ssh-keygen writes the private key with mode 0600 and the public key
with mode 0644. The private key must stay readable only by you,
otherwise ssh refuses to use it.

sshd runs as root but checks the files of the target account with
StrictModes: the home directory, ~/.ssh and authorized_keys must not be
writable by group or others and must belong to the account or root.
`restorecon` gives the files their default SELinux context ssh_home_t.
A file moved into place from /tmp would otherwise keep user_tmp_t.
The targeted policy of Rocky 8 and 9 lets sshd read that too, so the
context is not graded, but the default context is the clean state.

The Host block applies to the name given on the command line, so
`ssh deploy-local` picks up HostName, User and IdentityFile from it.
`ssh -G` shows the resolved settings without connecting. The grader
logs in with StrictHostKeyChecking off, so it does not depend on your
known_hosts file. `ssh-keygen -R localhost` removes a stale host key
from it.
