# podman-03: Rootless pod with a database and a web container

## Hints

1. Work in your own SSH session as your normal user. Containers made
   with sudo belong to root, and the grader wants none there. A pod
   is a group of containers that share one network namespace, so the
   published port belongs to the pod and its containers reach each
   other on 127.0.0.1. Read man podman-pod-create.
2. Read man podman-run for the options that put a container into a
   pod, set an environment variable and mount a host directory. The
   mount options there include the SELinux label for a directory that
   only this container uses.
3. In a rootless container, UID 27 is not UID 27 on the host. The
   command podman unshare runs a command in the user namespace of
   your containers, where a change of owner to UID 27 gives the
   directory to the mysql user of the container.
4. The command podman exec runs a program in a running container.
   The image has the mysql client, which takes the user, the password
   and the database on the command line.

## Solution

1. [sudo] Install Podman if it is missing:

   ```bash
   rpm -q podman || sudo dnf -y install podman
   ```

2. [user] Create the pod with the published port:

   ```bash
   podman pod create --name apppod -p 8082:8080
   ```

3. [user] Create the data directory, give it to UID 27 of the
   container and run the database in the pod:

   ```bash
   mkdir ~/dbdata
   podman unshare chown 27:27 ~/dbdata
   podman run -d --pod apppod --name db \
     -e MYSQL_DATABASE=inventory -e MYSQL_USER=app \
     -e MYSQL_PASSWORD=Inv3ntory \
     -v ~/dbdata:/var/lib/mysql/data:Z \
     quay.io/sclorg/mariadb-1011-c9s
   ```

4. [user] Wait until the log shows that the server is ready, then
   create the table and its row as app:

   ```bash
   podman logs db
   podman exec db mysql -h 127.0.0.1 -u app -pInv3ntory inventory -e "
     CREATE TABLE items (id INT PRIMARY KEY, name VARCHAR(64));
     INSERT INTO items VALUES (1, 'blue widget');"
   ```

5. [user] Run the web container in the pod with the page directory:

   ```bash
   podman run -d --pod apppod --name web \
     -v ~/podlab:/opt/app-root/src:Z \
     registry.access.redhat.com/ubi9/php-81 /usr/libexec/s2i/run
   ```

6. [user] Test the page:

   ```bash
   curl http://127.0.0.1:8082/
   ```

## Verification

```bash
podman pod ps
podman ps --pod
ls -l ~/dbdata
labctl grade podman-03
```

## Explanation

A pod is a set of containers that share an infra container, and with
it one network namespace. The port 8082 is published when the pod is
created, because the containers that join later use the network of
the pod and cannot publish ports of their own. Inside the pod both
containers see the same 127.0.0.1, so the PHP page reaches MariaDB at
127.0.0.1:3306 although the database port is not published on the
host at all.

Rootless Podman maps UID 0 of the container to your own UID and the
other container UIDs to your subordinate range in /etc/subuid. The
mysql user (UID 27) of the container is therefore a high, unnamed UID
on the host, and a directory you own looks like it belongs to root in
the container. podman unshare runs chown inside that mapping, so the
server can write its files. ls -l on the host then shows the numeric
owner, for example 100026. The mount option U does the same change
of owner when the container starts. The mysql user of the image is
also in the root group, so a directory with group write permission
works without the change of owner; the change of owner does not
depend on that.

The option Z relabels the directory with a private SELinux label for
the container, so SELinux can stay enforcing. Both containers of the
pod share one SELinux label, so Z works on both directories here.

The MariaDB image reads MYSQL_DATABASE, MYSQL_USER and MYSQL_PASSWORD
only on its first start with an empty data directory. When ~/dbdata
already holds a database, a new container with the same mount uses
the existing data and its row survives. The database files belong to
your subordinate UIDs, so removing ~/dbdata needs podman unshare.

Podman 4 on Rocky 8 uses CNI for networking and Podman 5 on Rocky 9
uses netavark, but pods, port publishing and the commands here work
the same on both.
