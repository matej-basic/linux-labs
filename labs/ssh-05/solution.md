# ssh-05: SSH user certificates signed by a local CA

## Hints

1. An SSH certificate authority is an ordinary key pair. Its private
   key signs the public keys of users, and sshd accepts every key that
   carries a valid signature from a CA it trusts. Read man ssh-keygen,
   section CERTIFICATES.
2. The command ssh-keygen signs a public key with the option -s. Other
   options set the key ID, the principals and the validity interval.
   The certificate lands next to the public key, with -cert.pub in
   place of .pub.
3. The keyword TrustedUserCAKeys in man sshd_config names the public
   key of the CA. It is allowed in a Match block, and so is
   AuthorizedKeysFile, which can be none. The command sshd with the
   options -T and -C prints the effective settings for one user.
4. Test as root with the lab private key. The ssh client option
   CertificateFile adds the certificate to the login.

## Solution

1. [sudo] Create the CA key pair without a passphrase:

   ```bash
   sudo ssh-keygen -t ed25519 -N '' -C lab_user_ca \
     -f /etc/ssh/lab_user_ca
   sudo ls -l /etc/ssh/lab_user_ca /etc/ssh/lab_user_ca.pub
   ```

   ssh-keygen creates the private key with mode 0600 and the public key
   with mode 0644, both owned by root.

2. [sudo] Append a Match block for deploy to the end of
   /etc/ssh/sshd_config. It trusts the CA and turns off the authorized
   keys file for deploy. Test the configuration and reload sshd only
   when the test passes:

   ```bash
   sudo tee -a /etc/ssh/sshd_config >/dev/null <<'END'

   Match User deploy
       TrustedUserCAKeys /etc/ssh/lab_user_ca.pub
       AuthorizedKeysFile none
   END
   sudo sshd -t && sudo systemctl reload sshd
   ```

   On Rocky 9 the Include of /etc/ssh/sshd_config.d is at the top of
   the main file, so a block at the end of the main file is the last
   thing sshd reads on both releases.

3. [sudo] Compare the effective settings of deploy and of yourself:

   ```bash
   sudo sshd -T -C user=deploy,host=localhost,addr=127.0.0.1 |
     grep -E '^(trustedusercakeys|authorizedkeysfile)'
   sudo sshd -T -C user=$USER,host=localhost,addr=127.0.0.1 |
     grep -E '^(trustedusercakeys|authorizedkeysfile)'
   ```

   For deploy the output shows the CA and none, for you it shows none
   and .ssh/authorized_keys as before.

4. [sudo] Sign the public key of deploy. Only root can read the CA
   private key:

   ```bash
   sudo ssh-keygen -s /etc/ssh/lab_user_ca -I deploy-cert -n deploy \
     -V +52w ~/deploy_ed25519.pub
   ```

   The certificate is ~/deploy_ed25519-cert.pub.

5. [user] Check the certificate:

   ```bash
   ssh-keygen -L -f ~/deploy_ed25519-cert.pub
   ```

   The output shows a user certificate, the key ID deploy-cert, the
   principal deploy, the fingerprint of the CA as the signing CA and a
   validity period of 52 weeks.

6. [sudo] Log in as deploy with the lab key and the certificate:

   ```bash
   sudo ssh -i /opt/linux-labs/state/ssh-05.d/deploy_ed25519 \
     -o CertificateFile=$HOME/deploy_ed25519-cert.pub \
     -o StrictHostKeyChecking=accept-new deploy@localhost id -un
   ```

   The command prints deploy.

7. [sudo] Try the key alone. sshd refuses it:

   ```bash
   sudo ssh -i /opt/linux-labs/state/ssh-05.d/deploy_ed25519 \
     -o IdentitiesOnly=yes -o BatchMode=yes deploy@localhost id -un
   ```

   The command ends with "Permission denied (publickey...)".

## Verification

```bash
sudo sshd -t
labctl grade ssh-05
```

## Explanation

A user certificate is a public key that a CA has signed together with
a key ID, a list of principals and a validity interval. sshd checks
the signature against the keys named by TrustedUserCAKeys, checks that
the user name is one of the principals and that the certificate is
valid now. No authorized keys file is needed, so a new key only needs
a new signature, not a change on every server. The key ID appears in
the sshd log of every login, which shows which certificate was used.

The certificate does not replace the private key: the client proves
that it holds the private key, and sends the certificate with it. ssh
loads <key>-cert.pub next to the private key on its own; with the key
in another directory, CertificateFile names the certificate.

AuthorizedKeysFile none in the Match block makes sure that deploy can
never log in with a plain key, even when someone adds an authorized
keys file later. The Match block applies to deploy only, so the key
logins of every other account stay as they were. A global
TrustedUserCAKeys would also work and only adds trust; it changes no
other account's existing logins.
