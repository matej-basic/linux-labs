# ansible-03: Ansible Vault, facts and conditionals

## Hints

1. Work in an SSH session on node 1 in ~/ansible-lab. Set up the vault
   password file and ansible.cfg first, so that every later command
   finds the vault password by itself.
2. The command ansible-vault encrypts an existing file and shows an
   encrypted one. The key vault_password_file belongs in the section
   defaults of ansible.cfg. Files in group_vars/appservers apply to
   every host of the group.
3. The module group takes one group per call, so the task needs the
   key loop. The filter password_hash takes the hash type sha512 and a
   fixed salt as a second argument. The user module takes a list of
   supplementary groups.
4. The facts distribution_major_version and memtotal_mb hold the two
   numbers for the template. The custom fact is
   ansible_local['lab']['server']['role'], and the key when compares it
   with admin.

## Solution

The addresses below are the classroom defaults: node 1 is
172.25.250.10, node 2 is 172.25.250.11 and node 3 is 172.25.250.12.
Use the addresses from the TOPOLOGY section of labctl task ansible-03
if yours differ.

1. [user] On the workstation, log in to node 1 as the SSH user of the
   lab configuration. All further steps run on node 1:

   ```bash
   ssh opsadmin@172.25.250.10
   ```

2. [user] Check the prepared project. Write a vault password to
   .vault_pass with mode 0600 and name the file in ansible.cfg:

   ```bash
   cd ~/ansible-lab
   ansible all -m ansible.builtin.ping
   (umask 077; echo 'lab-vault-secret' > .vault_pass)
   sed -i '/^\[defaults\]/a vault_password_file = .vault_pass' \
     ansible.cfg
   ls -l .vault_pass
   ```

3. [user] Write the password of appadmin to vault.yml and encrypt the
   file. The password comes from ~/appadmin-password.txt:

   ```bash
   mkdir -p group_vars/appservers
   pw=$(sed -n 's/^Password of the user appadmin: //p' \
     ~/appadmin-password.txt)
   printf -- '---\nappadmin_password: %s\n' "$pw" \
     > group_vars/appservers/vault.yml
   ansible-vault encrypt group_vars/appservers/vault.yml
   head -n 1 group_vars/appservers/vault.yml
   ansible-vault view group_vars/appservers/vault.yml
   ```

4. [user] Write the list of groups:

   ```bash
   cat > group_vars/appservers/vars.yml <<'EOF'
   ---
   app_groups:
     - appdev
     - appops
     - appaudit
   EOF
   ```

5. [user] Write the template for /etc/motd. The two numbers come from
   variables that the play sets from facts:

   ```bash
   mkdir -p templates
   cat > templates/motd.j2 <<'EOF'
   Managed by Ansible
   Release {{ motd_release }} with {{ motd_memory }} MB of memory
   EOF
   ```

6. [user] Write the playbook. The hash has a fixed salt, so it is the
   same on every run:

   ```bash
   cat > users.yml <<'EOF'
   ---
   - name: Manage appadmin, its groups and the login message
     hosts: appservers
     vars:
       motd_release: "{{ ansible_facts['distribution_major_version'] }}"
       motd_memory: "{{ ansible_facts['memtotal_mb'] }}"
       appadmin_hash: >-
         {{ appadmin_password | password_hash('sha512', 'ansible03') }}
     tasks:
       - name: The application groups exist
         ansible.builtin.group:
           name: "{{ item }}"
           state: present
         loop: "{{ app_groups }}"

       - name: appadmin exists with the password from the vault
         ansible.builtin.user:
           name: appadmin
           groups: "{{ app_groups }}"
           append: true
           password: "{{ appadmin_hash }}"

       - name: /etc/motd shows the release and the memory
         ansible.builtin.template:
           src: templates/motd.j2
           dest: /etc/motd
           owner: root
           group: root
           mode: "0644"

       - name: zsh is installed on admin nodes
         ansible.builtin.dnf:
           name: zsh
           state: present
         when: ansible_local['lab']['server']['role'] == 'admin'
   EOF
   ```

7. [user] Check the syntax, run the playbook, then run it in check
   mode:

   ```bash
   ansible-playbook --syntax-check users.yml
   ansible-playbook users.yml
   ansible-playbook --check users.yml
   ```

## Verification

The check-mode run shows changed=0 for both nodes. The zsh task is
skipped on node 3:

```bash
ansible appservers -a 'cat /etc/motd'
ansible appservers -a 'id appadmin'
ansible appservers -a 'rpm -q zsh'
```

Then grade on the workstation:

```bash
labctl grade ansible-03
```

## Explanation

ansible-vault encrypts the whole file with AES256. The first line,
$ANSIBLE_VAULT;1.1;AES256, names the format; a vault ID would give
format 1.2. With vault_password_file in ansible.cfg, ansible-vault and
ansible-playbook read the password from .vault_pass and never prompt.
The file must not be readable by others, and it does not belong in
version control.

Ansible loads every file in group_vars/appservers for the hosts of the
group, so the secret and the plain variables can sit in separate files.
The grader decrypts vault.yml and also searches every other file of
the project for the password, so the password must not stay in a
plain file.

The filter password_hash with the type sha512 gives a hash that starts
with $6$. Without a fixed salt it picks a new random salt on every run,
the hash changes, and the user module reports a change each time. That
breaks the check-mode criterion. A fixed salt, or the user option
update_password with on_create, keeps the run idempotent. Rocky Linux
8 ships ansible-core 2.16 on Python 3.12 and Rocky Linux 9 ships 2.14
on Python 3.9. Without the passlib library the filter uses the Python
module crypt on both. On Rocky Linux 8 the run then prints a
deprecation warning about crypt; the hash is correct and the warning
does not count as a failure.

The module group creates one group per call, and loop runs the task
once for each entry of app_groups. The user module takes the same list
for the supplementary groups, and append keeps groups that appadmin
already has.

The template renders on the control node with the facts that the play
gathered from each node, so each node gets its own release and memory
values. The local fact file on each managed node appears as
ansible_local, with one key per file, then per section. The condition
compares the role with admin, so zsh is installed on node 2 and the
task is skipped on node 3.
