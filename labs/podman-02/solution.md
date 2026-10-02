# podman-02: Build a container image and run it with Podman

## Hints

1. Work in your own SSH session as your normal user. Images and
   containers built with sudo belong to root and are not the ones the
   grader looks at. Only the package install needs root.
2. A Containerfile is a list of instructions, one per line. Read man
   Containerfile for the instructions that name the base image, copy
   a file from the build directory, set a label and set an
   environment variable.
3. Read man podman-build for the option that names and tags the new
   image. The build directory is the last argument.
4. Read man podman-run for publishing a port, mounting a volume and
   the restart policy. A volume given by a name instead of a host path
   is a named volume, and man podman-volume shows how to manage it.

## Solution

1. [sudo] Install Podman if it is missing:

   ```bash
   rpm -q podman || sudo dnf -y install podman
   ```

2. [user] Write the Containerfile next to the page:

   ```bash
   cd ~/webimg
   cat >Containerfile <<'END'
   FROM registry.access.redhat.com/ubi9/httpd-24
   LABEL version="1.0"
   ENV APP_ENV=production
   COPY index.html /var/www/html/index.html
   END
   ```

3. [user] Build the image and check its label and variable:

   ```bash
   podman build -t localhost/webapp:1.0 .
   podman image inspect --format '{{.Labels.version}}' \
     localhost/webapp:1.0
   podman image inspect --format '{{.Config.Env}}' localhost/webapp:1.0
   ```

4. [user] Create the volume and run the container:

   ```bash
   podman volume create webdata
   podman run -d --name web -p 8081:8080 \
     -v webdata:/var/www/data --restart always \
     localhost/webapp:1.0
   ```

5. [user] Test the page:

   ```bash
   curl http://localhost:8081
   ```

## Verification

```bash
podman ps
podman inspect --format '{{.HostConfig.RestartPolicy.Name}}' web
podman inspect --format '{{.Mounts}}' web
labctl grade podman-02
```

## Explanation

podman build reads the Containerfile in the build directory and runs
its instructions on top of the base image. COPY takes the file from
the build directory, which is why the page sits next to the
Containerfile. LABEL and ENV become part of the image configuration,
so every container of the image has APP_ENV set. The base image
already has a version label; the new value 1.0 replaces it. The name
localhost/webapp:1.0 marks a local image that was never pushed to a
registry.

Rootless Podman keeps images, containers and volumes in the home
directory of the user who runs it. The same commands with sudo would
create a second, separate set under root, which the grader does not
see. Ports above 1023 need no privilege, so a rootless container can
publish 8081 directly.

podman run creates a named volume on first use as well, so the
volume create step is optional. The volume lives in Podman's storage,
not in a directory you choose, and it survives when the container is
removed. A volume mounted over /var/www/html would hide the page in
the image, which is why the data volume goes to another path.

The restart policy always makes Podman start the container again when
its process exits. Podman 4 on Rocky 8 and Podman 5 on Rocky 9 accept
the same commands and show the same inspect fields used here. After a
reboot, rootless containers with this policy start only when the
user service podman-restart.service is enabled, which this lab does
not require.
