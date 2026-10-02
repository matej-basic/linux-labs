# ansible-01: Ansible control node and a first playbook

## Hints

1. Work in an SSH session on node 1. Install the control node
   software first, then make SSH as the user ansible work without a
   password, then write the project files in ~/ansible-lab.
2. The command ssh-keygen creates the key pair and ssh-copy-id
   installs the public key for the user ansible on a node. It asks
   once for the password redhat.
3. An ansible.cfg has a [defaults] section with the keys inventory
   and remote_user. The keys become and become_method, in a play or
   in the section [privilege_escalation], give the tasks root through
   sudo. The command ansible-config with the subcommand dump and the
   option --only-changed shows what your file sets.
4. A play is a list item with the keys name, hosts and tasks. The
   module copy takes the file content directly in its option content,
   and its options owner, group and mode set the rest. The command
   ansible-playbook has the options --syntax-check and --check.

## Solution

The addresses below are the classroom defaults: node 1 is
172.25.250.10, node 2 is 172.25.250.11 and node 3 is 172.25.250.12.
Use the addresses from the TOPOLOGY section of labctl task ansible-01
if yours differ.

1. [user] On the workstation, log in to node 1 as the SSH user of the
   lab configuration. All further steps run on node 1:

   ```bash
   ssh opsadmin@172.25.250.10
   ```

2. [sudo] Install ansible-core where it is missing:

   ```bash
   rpm -q ansible-core || sudo dnf -y install ansible-core
   ```

3. [user] Create a key pair without a passphrase and install the
   public key for the user ansible on nodes 2 and 3. Confirm each host
   key with yes and enter the password redhat:

   ```bash
   N2=172.25.250.11; N3=172.25.250.12
   ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
   for ip in $N2 $N3; do ssh-copy-id ansible@$ip; done
   ```

4. [user] Create the project directory with ansible.cfg and the
   inventory:

   ```bash
   mkdir -p ~/ansible-lab
   cd ~/ansible-lab
   cat > ansible.cfg <<'EOF'
   [defaults]
   inventory = ./inventory
   remote_user = ansible

   [privilege_escalation]
   become = true
   become_method = sudo
   EOF
   cat > inventory <<EOF
   [webservers]
   $N2
   $N3
   EOF
   ```

5. [user] Check the configuration and run the module ping against all
   hosts:

   ```bash
   ansible --version | grep 'config file'
   ansible-config dump --only-changed
   ansible all -m ansible.builtin.ping
   ```

6. [user] Write the playbook:

   ```bash
   cat > site.yml <<'EOF'
   ---
   - name: Deploy a web server
     hosts: webservers
     become: true
     tasks:
       - name: The package httpd is installed
         ansible.builtin.dnf:
           name: httpd
           state: present

       - name: The index page is deployed
         ansible.builtin.copy:
           content: "This web server is managed by Ansible.\n"
           dest: /var/www/html/index.html
           owner: root
           group: root
           mode: "0644"

       - name: httpd is enabled and running
         ansible.builtin.service:
           name: httpd
           state: started
           enabled: true
   EOF
   ```

7. [user] Check the syntax, run the playbook, then run it in check
   mode:

   ```bash
   ansible-playbook --syntax-check site.yml
   ansible-playbook site.yml
   ansible-playbook --check site.yml
   ```

## Verification

The check-mode run shows changed=0 for both nodes, and the page is in
place on each managed node:

```bash
ansible webservers -a 'cat /var/www/html/index.html'
```

Then grade on the workstation:

```bash
labctl grade ansible-01
```

## Explanation

Ansible needs software only on the control node. It connects to the
managed nodes over SSH and runs its modules there with the Python of
the node, so nodes 2 and 3 need nothing but sshd, Python and an account
it can log in to. Rocky Linux 8 keeps its system Python in
/usr/libexec/platform-python, and Ansible finds it there by itself.

The configuration comes from the first file found: the variable
ANSIBLE_CONFIG, ansible.cfg in the current directory, ~/.ansible.cfg,
then /etc/ansible/ansible.cfg. A project directory with its own
ansible.cfg therefore carries its inventory, remote user and privilege
settings with it. A relative inventory path in ansible.cfg is relative
to the directory of that file. The command ansible --version names the
file in use.

Ansible logs in without a password, so the key must be in the
authorized_keys of the user ansible on every node. The user ansible
then gets root through sudo, which the lab set up without a password.
Without become the package and file tasks fail with a permission
error.

A playbook describes the end state. A second run, or a run in check
mode, reports changed=0 when the nodes already match it. The grader
uses that to check that site.yml and the nodes agree: a page created by
hand with a different line or mode shows up as a change. The content
in the copy task ends with a newline so that the file is exactly one
line.

Rocky Linux 8 ships ansible-core 2.16 and Rocky Linux 9 ships 2.14.
The modules dnf, copy and service behave the same in both, and every
module the solution uses is in ansible.builtin, so no collection is
needed.
