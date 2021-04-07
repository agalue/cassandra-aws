# Change Cluster Topology

This [Ansible](https://www.ansible.com/) recipe helps with the tasks involved in changing the topology on a Cassandra cluster when switching the `endpoint_snitch` from `SimpleSnitch` to `GossipingPropertyFileSnitch` (and updating the `Newts` keyspace from `SimpleStrategy` to `NetworkTopologyStrategy`).

Of course, the operator work doesn't end there as due to the topology change, a full sequential repair has to be executed to update the replicas across the cluster.

For this operation, I recommend using [Cassandra Reaper](http://cassandra-reaper.io/).

It is expected to have `Ansible` installed on the OpenNMS server and execute the recipes from there:

```bash=
ansible-playbook playbook.yaml
```

**WARNING**: Make sure to adjust the [inventory.yaml](inventory.yaml) file with the appropriate information for your cluster. The example content is based on the Cassandra inventory described in `vars.tf` in the main directory.