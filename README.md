# linux-labs

Hands-on Linux administration labs in the style of the RHCSA exam, for Rocky Linux, RHEL and AlmaLinux 8 and 9. Each lab prepares the machine, gives the student a task, grades the final state with one PASS or FAIL line per requirement, and resets the machine afterwards. There are 89 labs, from files and permissions to SELinux, storage, DNS, databases and three-node Pacemaker clusters.

## Install

```bash
curl -fsSL https://matej-basic.github.io/linux-labs/install | sudo bash
```

The installer adds the `linux-labs` dnf repository, imports its signing key and installs the package. Other distributions and EL10 are rejected.

## A first lab

```bash
labctl list
sudo labctl start files-01
labctl grade files-01
labctl solution files-01
sudo labctl reset files-01
```

`start` prints the task. Do the work with ordinary Linux commands, then grade as often as you like until the overall result is PASS.

## Documentation

- [docs/](docs/README.md): guides for students, teachers and lab authors
- [docs/catalog.md](docs/catalog.md): every lab with its level, course and requirements
- `man labctl` on an installed machine

## License

MIT, see [LICENSE](LICENSE).
