# clustering-02: known issues

- 2026-10-02 | all | workaround | No hypervisor is reachable from the
  nodes, so every start of the three fence_virsh devices fails and the
  devices end up stopped, with failed start actions in the cluster
  status. The grader ignores failed actions of the fence devices and
  the solution sets migration-threshold=INFINITY on them, so apache_web
  keeps running. The cluster could not fence a node that really fails.
