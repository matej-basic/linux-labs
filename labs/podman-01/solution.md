# podman-01: Rootless httpd container as a systemd user service

## Hints

1. Do the container work in your own SSH session as your normal user.
   A container started with sudo belongs to root and is a different
   container, with its own images. Only the package install and the
   linger setting need root.
2. Read man podman-run for publishing a port and for the volume
   options. One volume option relabels the host directory for the
   container, so no separate SELinux command is needed.
3. Podman can write a systemd unit file for an existing container.
   Read man podman-generate-systemd, the options that create a new
   container on each start and write the unit to a file. User units
   live in the directory systemd/user below your configuration
   directory, and systemctl takes an option for the user manager.
4. User services start at boot only when the user manager starts
   without a login. Read man loginctl, the linger subcommands.

## Solution

1. [sudo] Install Podman if it is missing:

   ```bash
   rpm -q podman || sudo dnf -y install podman
   ```

2. [sudo] Enable linger for your user, so that your user manager runs
   from boot:

   ```bash
   sudo loginctl enable-linger $USER
   ```

3. [user] Run the container with the published port and the
   relabelled volume, then test it:

   ```bash
   podman run -d --name webapp -p 8080:8080 \
     -v /srv/webapp:/var/www/html:Z \
     registry.access.redhat.com/ubi9/httpd-24
   curl http://localhost:8080
   ls -Zd /srv/webapp /srv/webapp/index.html
   ```

4. [user] Write a unit file for the container into the user unit
   directory:

   ```bash
   mkdir -p ~/.config/systemd/user
   cd ~/.config/systemd/user
   podman generate systemd --new --name webapp --files
   ```

5. [user] Remove the test container, since the unit creates its own,
   and enable and start the unit:

   ```bash
   podman rm -f webapp
   systemctl --user daemon-reload
   systemctl --user enable --now container-webapp.service
   ```

## Verification

```bash
systemctl --user status container-webapp.service
podman ps
curl http://localhost:8080
loginctl show-user $USER -p Linger
labctl grade podman-01
```

## Explanation

Rootless Podman keeps images and containers in the home directory of
the user who runs it, so the same commands with sudo would create a
second, separate container under root. The process that publishes
port 8080 on the host belongs to your user, which the grader checks.
Ports above 1023 need no privilege, so a rootless container can
publish 8080 directly.

The volume suffix Z makes Podman relabel /srv/webapp with the type
container_file_t and a category private to this container. Without
it, SELinux denies the container access to a directory of type var_t
and Apache answers 403. Setup made you the owner of /srv/webapp,
which a rootless relabel needs. The image runs Apache as an
unprivileged user inside the container, so the page must stay
readable for others, as setup left it.

The solution uses podman generate systemd because it works on both
releases. Rocky 8 ships Podman 4 and Rocky 9 ships Podman 5. In
Podman 5 the command is deprecated in favour of Quadlet and prints a
warning, but it still writes the same unit. On Rocky 9 a Quadlet file
named container-webapp.container in ~/.config/containers/systemd
passes as well: the grader checks the running unit, not how it was
made. On Rocky 8 a rootless Quadlet unit is generated but fails to
start, because Quadlet runs the container with split cgroups and
Rocky 8 uses cgroup version 1, where a rootless user may not create
them. The option --new makes the unit create a fresh container on
every start and remove it on stop, which is why the test container
goes before the unit starts. The generated unit is wanted by
default.target, the target of the user manager.

Without linger, systemd starts the user manager only at login and
stops it at the last logout, so the service would not run after a
reboot until you log in. After a reboot the container can take a
minute to come up: Podman 5 waits for the system to report that the
network is online before it starts a user container.
