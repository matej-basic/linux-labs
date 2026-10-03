# ansible-02: Ansible roles, templates and handlers

## Hints

1. Work in an SSH session on node 1 in ~/ansible-lab. A role is a
   directory under roles with one subdirectory per kind of content:
   tasks, handlers, defaults and templates each hold a main.yml or
   the template files.
2. The command ansible-galaxy with the subcommand role init creates
   the skeleton of a role. The command ansible-inventory with the
   option --host shows the variables a host gets from group_vars and
   host_vars.
3. In a template, a variable is written in double braces. The facts
   are in the variable ansible_facts, and the short host name is its
   key hostname. The name of the host in the inventory is the
   variable inventory_hostname.
4. A handler is a task in handlers/main.yml with a name. A task lists
   that name under its key notify. The module service restarts a
   service with the state restarted. A play applies a role through
   its key roles.

## Solution

The addresses below are the classroom defaults: node 1 is
172.25.250.10, node 2 is 172.25.250.11 and node 3 is 172.25.250.12.
Use the addresses from the TOPOLOGY section of labctl task ansible-02
if yours differ.

1. [user] On the workstation, log in to node 1 as the SSH user of the
   lab configuration. All further steps run on node 1:

   ```bash
   ssh opsadmin@172.25.250.10
   ```

2. [user] Check the prepared project, then create the directories of
   the role:

   ```bash
   cd ~/ansible-lab
   ansible all -m ansible.builtin.ping
   mkdir -p roles/webserver/tasks roles/webserver/handlers
   mkdir -p roles/webserver/defaults roles/webserver/templates
   mkdir -p group_vars host_vars
   ```

3. [user] Write the role defaults, the tasks and the handler:

   ```bash
   cat > roles/webserver/defaults/main.yml <<'EOF'
   ---
   web_greeting: Hello from Ansible
   EOF
   cat > roles/webserver/tasks/main.yml <<'EOF'
   ---
   - name: The package httpd is installed
     ansible.builtin.dnf:
       name: httpd
       state: present

   - name: The index page is deployed
     ansible.builtin.template:
       src: index.html.j2
       dest: /var/www/html/index.html
       owner: root
       group: root
       mode: "0644"

   - name: The httpd configuration is deployed
     ansible.builtin.template:
       src: webserver.conf.j2
       dest: /etc/httpd/conf.d/webserver.conf
       owner: root
       group: root
       mode: "0644"
     notify: Restart httpd

   - name: httpd is enabled and running
     ansible.builtin.service:
       name: httpd
       state: started
       enabled: true
   EOF
   cat > roles/webserver/handlers/main.yml <<'EOF'
   ---
   - name: Restart httpd
     ansible.builtin.service:
       name: httpd
       state: restarted
   EOF
   ```

4. [user] Write the two templates:

   ```bash
   cat > roles/webserver/templates/index.html.j2 <<'EOF'
   {{ web_greeting }}
   Served by {{ ansible_facts['hostname'] }}
   EOF
   cat > roles/webserver/templates/webserver.conf.j2 <<'EOF'
   # Managed by Ansible
   ServerName {{ inventory_hostname }}
   EOF
   ```

5. [user] Set the greeting for the group and for node 3, and check
   what each host gets:

   ```bash
   cat > group_vars/webservers.yml <<'EOF'
   ---
   web_greeting: Welcome to the web farm
   EOF
   cat > host_vars/172.25.250.12.yml <<'EOF'
   ---
   web_greeting: Welcome to the staging server
   EOF
   ansible-inventory --host 172.25.250.11
   ansible-inventory --host 172.25.250.12
   ```

6. [user] Write the playbook:

   ```bash
   cat > site.yml <<'EOF'
   ---
   - name: Deploy the web servers
     hosts: webservers
     roles:
       - webserver
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

The check-mode run shows changed=0 for both nodes. Each node has its
own page and configuration file:

```bash
ansible webservers -a 'cat /var/www/html/index.html'
ansible webservers -a 'cat /etc/httpd/conf.d/webserver.conf'
```

Then grade on the workstation:

```bash
labctl grade ansible-02
```

## Explanation

A role bundles tasks, handlers, default variables and templates in a
fixed directory layout, so a play needs only the role name. Ansible
finds the role in the directory roles next to the playbook. A task in
a role finds its template in the templates directory of the role
without a path.

The variable web_greeting is set three times. The role default is the
fallback with the lowest precedence. group_vars/webservers.yml
overrides it for every host in the group, and host_vars for node 3
overrides the group value for that host alone. Node 2 therefore shows
the group greeting and node 3 the staging greeting. The files are
named after the group and after the host exactly as the inventory
names them, here by address.

The template module renders Jinja2 on the control node with the
variables and facts of each host, then copies the result. The fact
hostname is the short host name of the node, and inventory_hostname
is the name of the host in the inventory.

The task for webserver.conf notifies the handler Restart httpd. The
handler runs once at the end of the play, and only on a host where the
task changed the file. The grader edits webserver.conf on node 2, runs
site.yml and expects the file back and a new httpd main process. A
task that restarts httpd on every run instead would break the
check-mode criterion, since it always reports a change. A handler
with the state reloaded keeps the main process and does not count as
a restart.

Rocky Linux 8 ships ansible-core 2.16 and Rocky Linux 9 ships 2.14.
The modules dnf, template and service behave the same in both, and the
managed nodes on Rocky Linux 8 run the modules with
/usr/libexec/platform-python.
