# Change Cluster Topology

This [Ansible](https://www.ansible.com/) recipe helps with the tasks involved in changing the topology on a Cassandra cluster when switching the `endpoint_snitch` from `SimpleSnitch` to `GossipingPropertyFileSnitch`, updating the keyspaces that use`SimpleStrategy` to start using `NetworkTopologyStrategy`.

This procedure assumes the cluster is healthy. If you're unsure, it is recommended to run a full repair prior to executing this operation, and I recommend doing it using [Cassandra Reaper](http://cassandra-reaper.io/).

It is expected to have `Ansible` installed on the OpenNMS server and execute the recipes from there:

```bash=
ansible-playbook playbook.yaml
```

Beware that this process can take days as decommissioning and bootstrapping nodes as new, can take a long time, and it has to be one node at a time. Consider updating the throttle settings to allow higher throughput when streaming data.

Make sure to adjust the [inventory.yaml](inventory.yaml) file with the appropriate information for your cluster. The example content is based on the Cassandra inventory described in `vars.tf` in the main directory.