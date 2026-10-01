# clustering-02: STONITH fencing for a Pacemaker cluster

## Hints

1. Fencing needs two things first: the agent installed on every node
   and one device per node. Switch fencing on only after the devices
   exist.
2. Fence devices are managed with the stonith part of pcs, not with
   pcs resource. See man pcs, section stonith, and the output of
   crm_node with the -l option for the node names Pacemaker uses.
3. Each device needs a host list restricting it to one node, set with
   the pcmk_host_list option. Without it a device claims to fence
   every node.
4. The fence_virsh agent needs ipaddr and login values, but any values
   are accepted here. The cluster property to switch on is
   stonith-enabled.

## Solution

The names servera, serverb and serverc below are the Pacemaker node
names of the classroom layout. Use the names the cluster reports.

1. [sudo] On each of the three nodes, install the package with the
   fence_virsh agent. Depending on the release it comes from AppStream
   or from the ha repository, which is disabled by default (on a stock
   Rocky 9 system its id is highavailability):

   ```bash
   sudo dnf -y install --enablerepo=ha fence-agents-virsh
   ```

2. [sudo] On node 1, list the node names known to Pacemaker. Node N
   gets the device stonith-nodeN, in the order of the lab nodes:

   ```bash
   sudo crm_node -l
   ```

3. [sudo] On node 1, create the three fence devices. Each is
   restricted to one node by its host list:

   ```bash
   sudo pcs stonith create stonith-node1 fence_virsh \
     ipaddr=127.0.0.1 login=root pcmk_host_list=servera \
     meta migration-threshold=INFINITY
   sudo pcs stonith create stonith-node2 fence_virsh \
     ipaddr=127.0.0.1 login=root pcmk_host_list=serverb \
     meta migration-threshold=INFINITY
   sudo pcs stonith create stonith-node3 fence_virsh \
     ipaddr=127.0.0.1 login=root pcmk_host_list=serverc \
     meta migration-threshold=INFINITY
   ```

4. [sudo] On node 1, enable fencing:

   ```bash
   sudo pcs property set stonith-enabled=true
   ```

5. [sudo] On node 1, check that the devices are defined and that
   apache_web is still started:

   ```bash
   sudo pcs stonith config
   sudo pcs status
   ```

## Verification

```bash
sudo pcs property config | grep stonith-enabled
labctl grade clustering-02
```

## Explanation

STONITH makes the cluster power off a node it has lost contact with
before it moves that node's resources, so two nodes never write to the
same resource. Clustering-01 had to switch it off because Pacemaker
does not start resources while fencing is on and no device exists.
Here the devices are defined first and fencing is switched on after
them.

In pcs 0.10 and later fence devices are managed with pcs stonith, not
pcs resource, and they show up only in pcs stonith config. The grader
reads the cluster configuration directly: a device must be of type
fence_virsh, and its host list must hold the Pacemaker name of its own
node. A device without a host list claims it can fence every node,
which the grader does not accept.

fence_virsh logs in to a hypervisor over SSH and runs virsh there. The
nodes have no hypervisor, so the address 127.0.0.1 is a placeholder,
the devices fail their monitor operation and are stopped, and the
cluster could not fence a node that really died. That is acceptable in
the lab because the grader checks the configuration and that apache_web
keeps running, and it ignores failed actions of the fence devices. In
production the agent would be fence_ipmilan, fence_aws or a real
virsh host. The meta attribute migration-threshold=INFINITY is the
Pacemaker default made explicit; it keeps a failing fence device from
being moved away from a node for good.

A typical mistake is a missing fence_virsh binary on one node: the
agent has to exist on every node, because any node may have to run the
fence device. The package fence-agents-all does not pull in
fence-agents-virsh on Rocky 8, so fence_virsh can be missing even where
fence-agents-all is installed.
