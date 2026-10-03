# Lab ideas

Proposed labs that do not exist yet. Finished labs are listed in
[catalog.md](catalog.md), which `scripts/gen-catalog.sh` generates from
the labs themselves. When a lab from this list is built, remove its line
here and regenerate the catalog.

An id below is a working name. The real lab id follows the existing
prefixes in `labs/` and takes the next free two-digit number.

## Database and data services

- redis-01 (Beginner): Redis installation and basic operations
- redis-02 (Intermediate): Redis data structures and persistence
- redis-03 (Advanced): Redis replication and clustering
- mongodb-01 (Beginner): MongoDB installation and document basics
- mongodb-02 (Intermediate): Indexing and query optimization
- mongodb-03 (Advanced): Sharding and replication

## Container and virtualization

- docker-01 (Beginner): Docker installation and basic containers
- docker-02 (Intermediate): Dockerfile and image creation
- docker-03 (Advanced): Docker Compose and networking
- podman-03 (Advanced): Podman networking and storage
- lxc-01 (Beginner): LXC container basics
- lxc-02 (Intermediate): LXC networking and profiles
- lxc-03 (Advanced): LXC snapshots and backups
- kvm-01 (Beginner): KVM/QEMU basics
- kvm-02 (Intermediate): Virtual machine management
- kvm-03 (Advanced): KVM networking and storage

## Advanced networking

- nfs-03 (Advanced): NFS performance tuning
- samba-02 (Intermediate): Active Directory integration
- samba-03 (Advanced): Samba performance and security
- vpn-01 (Beginner): OpenVPN installation and setup
- vpn-02 (Intermediate): WireGuard configuration
- vpn-03 (Advanced): VPN routing and failover
- bonding-01 (Beginner): Network interface bonding
- bonding-02 (Intermediate): Team networking
- bonding-03 (Advanced): LACP and advanced bonding
- routing-02 (Intermediate): Dynamic routing with OSPF
- routing-03 (Advanced): BGP configuration

## Security and access control

- fail2ban-01 (Beginner): Fail2ban installation and basics
- fail2ban-02 (Intermediate): Custom rules and filters
- fail2ban-03 (Advanced): Integration with other services
- iptables-01 (Beginner): Iptables basics
- iptables-02 (Intermediate): Firewall rules and NAT
- iptables-03 (Advanced): Stateful firewalling
- certs-01 (Beginner): Certificate basics and generation
- certs-02 (Intermediate): Let's Encrypt automation
- certs-03 (Advanced): Certificate pinning and validation
- pwd-policy-03 (Advanced): Multi-factor authentication
- 2fa-01 (Beginner): TOTP setup with Google Authenticator
- 2fa-02 (Intermediate): FIDO2 security keys
- 2fa-03 (Advanced): MFA for SSH and applications

## Performance and monitoring

- prometheus-01 (Beginner): Prometheus installation
- prometheus-02 (Intermediate): Metrics collection
- prometheus-03 (Advanced): Alerting and dashboards
- grafana-01 (Beginner): Grafana installation
- grafana-02 (Intermediate): Dashboard creation
- grafana-03 (Advanced): Data source integration
- elk-01 (Beginner): Elasticsearch installation
- elk-02 (Intermediate): Logstash pipeline setup
- elk-03 (Advanced): ELK stack integration with Kibana
- nagios-01 (Beginner): Nagios/Icinga installation
- nagios-02 (Intermediate): Host and service monitoring
- nagios-03 (Advanced): Custom checks and plugins
- tuning-02 (Intermediate): CPU and I/O optimization
- tuning-03 (Advanced): Kernel parameter tuning

## Backup and disaster recovery

- backup-rsync-02 (Intermediate): Incremental backups
- backup-rsync-03 (Advanced): Automated backup strategies
- amanda-01 (Beginner): Amanda backup system setup
- amanda-02 (Intermediate): Backup scheduling
- amanda-03 (Advanced): Restore procedures
- bacula-01 (Beginner): Bacula installation
- bacula-02 (Intermediate): Backup job configuration
- bacula-03 (Advanced): Disaster recovery
- dr-01 (Beginner): DR planning basics
- dr-02 (Intermediate): Backup testing
- dr-03 (Advanced): Full system recovery

## Application deployment

- git-01 (Beginner): Git basics and setup
- git-02 (Intermediate): Repository management
- git-03 (Advanced): GitLab/Gitea self-hosted setup
- jenkins-01 (Beginner): Jenkins installation
- jenkins-02 (Intermediate): Pipeline creation
- jenkins-03 (Advanced): Integration and automation
- ansible-03 (Advanced): Complex automation scenarios
- k8s-01 (Beginner): Kubernetes cluster setup
- k8s-02 (Intermediate): Deployment and services
- k8s-03 (Advanced): Advanced networking and storage

## Infrastructure and configuration management

- ldap-01 (Beginner): OpenLDAP directory services basics
- ldap-02 (Intermediate): User authentication and groups
- ldap-03 (Advanced): LDAP replication and security
- terraform-01 (Beginner): Infrastructure as Code basics
- terraform-02 (Intermediate): State management and modules
- terraform-03 (Advanced): Advanced patterns and automation
- puppet-01 (Beginner): Puppet configuration management
- puppet-02 (Intermediate): Manifest development
- puppet-03 (Advanced): Module creation and scaling
- chef-01 (Beginner): Chef basics
- chef-02 (Intermediate): Cookbook development
- chef-03 (Advanced): Chef server setup and management

## CI/CD and DevOps

- gitlab-01 (Beginner): GitLab installation and setup
- gitlab-02 (Intermediate): CI/CD pipelines
- gitlab-03 (Advanced): Runner configuration and scaling
- container-registry-01 (Beginner): Docker Registry setup
- container-registry-02 (Intermediate): Registry security
- container-registry-03 (Advanced): Harbor implementation

## Application servers and services

- tomcat-01 (Beginner): Tomcat installation and basics
- tomcat-02 (Intermediate): WAR deployment
- tomcat-03 (Advanced): Clustering and load balancing
- nodejs-01 (Beginner): Node.js runtime setup
- nodejs-02 (Intermediate): Application deployment
- nodejs-03 (Advanced): Clustering and PM2
- rabbitmq-01 (Beginner): RabbitMQ installation
- rabbitmq-02 (Intermediate): Queue and exchange configuration
- rabbitmq-03 (Advanced): Clustering and federation
- kafka-01 (Beginner): Kafka cluster setup
- kafka-02 (Intermediate): Topic and partition management
- kafka-03 (Advanced): Consumer groups and monitoring

## Secrets and identity management

- vault-01 (Beginner): HashiCorp Vault installation
- vault-02 (Intermediate): Secret engines and auth methods
- vault-03 (Advanced): High availability and disaster recovery
- oauth-01 (Beginner): OAuth2 basics
- oauth-02 (Intermediate): OIDC implementation
- oauth-03 (Advanced): SSO and federation

## Advanced security

- zero-trust-01 (Beginner): Zero-trust architecture basics
- zero-trust-02 (Intermediate): Micro-segmentation
- zero-trust-03 (Advanced): Continuous verification
- secrets-rotation-01 (Beginner): Automated credential rotation
- secrets-rotation-02 (Intermediate): Key management systems
- secrets-rotation-03 (Advanced): Enterprise-scale rotation
- compliance-01 (Beginner): CIS benchmarks basics
- compliance-02 (Intermediate): Automated compliance checks
- compliance-03 (Advanced): NIST/SOC2 compliance

## Advanced observability

- distributed-tracing-01 (Beginner): Jaeger basics
- distributed-tracing-02 (Intermediate): Span correlation
- distributed-tracing-03 (Advanced): APM integration
- log-aggregation-01 (Beginner): Fluentd basics
- log-aggregation-02 (Intermediate): Advanced filtering
- log-aggregation-03 (Advanced): Multi-cluster aggregation

## Advanced system administration

- cgroups-v2-01 (Beginner): Cgroups v2 basics
- cgroups-v2-02 (Intermediate): Unified hierarchy
- cgroups-v2-03 (Advanced): systemd integration
- audit-framework-02 (Intermediate): Complex audit rules
- audit-framework-03 (Advanced): Real-time monitoring
- compliance-hardening-01 (Beginner): Hardening basics
- compliance-hardening-02 (Intermediate): FIPS mode
- compliance-hardening-03 (Advanced): Compliance automation

## Advanced virtualization

- kvm-advanced-01 (Beginner): Live migration basics
- kvm-advanced-02 (Intermediate): NUMA tuning
- kvm-advanced-03 (Advanced): vGPU and nested virtualization
- libvirt-clustering-01 (Beginner): Libvirt clustering
- libvirt-clustering-02 (Intermediate): Shared storage
- libvirt-clustering-03 (Advanced): Failover automation
- qemu-optimization-01 (Beginner): QEMU acceleration
- qemu-optimization-02 (Intermediate): CPU pinning
- qemu-optimization-03 (Advanced): Memory optimization

## Advanced monitoring

- metrics-aggregation-01 (Beginner): Prometheus federation
- metrics-aggregation-02 (Intermediate): Long-term storage
- metrics-aggregation-03 (Advanced): Downsampling strategies
- alerting-rules-01 (Beginner): Alert rule basics
- alerting-rules-02 (Intermediate): Multi-condition alerting
- alerting-rules-03 (Advanced): Runbook integration
- chaos-engineering-01 (Beginner): Chaos Monkey basics
- chaos-engineering-02 (Intermediate): Failure injection
- chaos-engineering-03 (Advanced): Resilience testing

## Advanced deployment

- blue-green-01 (Beginner): Blue-green deployment basics
- blue-green-02 (Intermediate): Traffic switching
- blue-green-03 (Advanced): Automated rollback
- canary-releases-01 (Beginner): Progressive rollout basics
- canary-releases-02 (Intermediate): Traffic splitting
- canary-releases-03 (Advanced): Metrics-based promotion
- feature-flags-01 (Beginner): Feature flag systems
- feature-flags-02 (Intermediate): A/B testing
- feature-flags-03 (Advanced): Gradual rollouts

## Advanced networking and protocols

- bgp-01 (Beginner): BGP fundamentals
- bgp-02 (Intermediate): AS path manipulation
- bgp-03 (Advanced): Route filtering and failover
- ospf-01 (Beginner): OSPF basics
- ospf-02 (Intermediate): Area design
- ospf-03 (Advanced): Multi-area topologies
- mpls-01 (Beginner): MPLS fundamentals
- mpls-02 (Intermediate): LSP creation
- mpls-03 (Advanced): Traffic engineering
- vxlan-01 (Beginner): VXLAN overlay networks
- vxlan-02 (Intermediate): Multi-site deployments
- vxlan-03 (Advanced): Physical network integration
- segment-routing-01 (Beginner): Segment routing basics
- segment-routing-02 (Intermediate): SRv6
- segment-routing-03 (Advanced): Policy-based forwarding

## Advanced Kubernetes

- k8s-networking-01 (Beginner): CNI plugins basics
- k8s-networking-02 (Intermediate): Service mesh (Istio)
- k8s-networking-03 (Advanced): Network policies and ingress
- k8s-storage-01 (Beginner): StatefulSets
- k8s-storage-02 (Intermediate): Persistent volumes
- k8s-storage-03 (Advanced): CSI drivers and backup
- k8s-security-01 (Beginner): RBAC basics
- k8s-security-02 (Intermediate): Pod security policies
- k8s-security-03 (Advanced): Admission controllers
- k8s-operators-01 (Beginner): Custom Resource Definitions
- k8s-operators-02 (Intermediate): Operator development
- k8s-operators-03 (Advanced): Lifecycle management

## Advanced kernel and performance

- ebpf-01 (Beginner): eBPF fundamentals
- ebpf-02 (Intermediate): Kernel probes and tracing
- ebpf-03 (Advanced): Custom monitoring programs
- perf-profiling-01 (Beginner): CPU profiling
- perf-profiling-02 (Intermediate): Flame graphs
- perf-profiling-03 (Advanced): Lock contention analysis
- cgroups-advanced-01 (Beginner): Resource limits
- cgroups-advanced-02 (Intermediate): CPU quotas
- cgroups-advanced-03 (Advanced): Advanced accounting

## Advanced storage and distributed systems

- ceph-01 (Beginner): Ceph cluster setup
- ceph-02 (Intermediate): Pool and replication management
- ceph-03 (Advanced): Rebalancing and recovery
- zfs-01 (Beginner): ZFS fundamentals
- zfs-02 (Intermediate): Snapshots and replication
- zfs-03 (Advanced): Compression and performance
- glusterfs-01 (Beginner): GlusterFS deployment
- glusterfs-02 (Intermediate): Replication and sharding
- glusterfs-03 (Advanced): Geo-replication
- database-sharding-01 (Beginner): Sharding fundamentals
- database-sharding-02 (Intermediate): Consistent hashing
- database-sharding-03 (Advanced): Shard migration

## Advanced cryptography and TLS

- tls-mutual-auth-01 (Beginner): mTLS setup
- tls-mutual-auth-02 (Intermediate): Certificate pinning
- tls-mutual-auth-03 (Advanced): Rotation at scale
- kerberos-01 (Beginner): Kerberos fundamentals
- kerberos-02 (Intermediate): Service principals
- kerberos-03 (Advanced): Cross-realm trusts
- hardware-security-01 (Beginner): TPM basics
- hardware-security-02 (Intermediate): Measured boot
- hardware-security-03 (Advanced): Remote attestation
- cryptographic-key-01 (Beginner): Key derivation
- cryptographic-key-02 (Intermediate): Key management
- cryptographic-key-03 (Advanced): Threshold cryptography

## Business continuity and cloud

- failover-testing-01 (Beginner): RTO/RPO planning
- failover-testing-02 (Intermediate): DR drills
- failover-testing-03 (Advanced): Automated failover
- aws-basics-01 (Beginner): AWS fundamentals
- aws-basics-02 (Intermediate): IAM and security groups
- aws-basics-03 (Advanced): Advanced VPC and automation
- azure-basics-01 (Beginner): Azure fundamentals
- azure-basics-02 (Intermediate): Resource groups and VMs
- azure-basics-03 (Advanced): Advanced networking
- openstack-01 (Beginner): OpenStack deployment
- openstack-02 (Intermediate): Instance and network management
- openstack-03 (Advanced): Advanced features and scaling
