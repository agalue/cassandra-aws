# Cassandra in AWS

**This repository is not maintained anymore, please use [this](https://github.com/agalue/cassandra-multi-instance) instead.**

Ideally, it is recommended to have medium-size servers as Cassandra nodes rather than large or huge servers as Cassandra nodes.

Unfortunately, we might get something different from what we expect when we request a set of servers to build a database cluster like this one, as probably the company already has established rules for the kind of hardware you'll get for a given role.

Having big servers for Cassandra is a waste of resources, unfortunately. The best way to work around this problem, and obtain the best from these big servers in terms of performance, assuming that [ScyllaDB](https://www.scylladb.com/) is not an option, is by having multiple instances of Cassandra running simultaneously on the same node.

Of course, this imposes some challenges when configuring the solution.

This recipe shows one way to solve this problem:

1) Have a dedicated directory for each instance to hold the configuration, data, and logs. This directory must point to a dedicated disk (or RAID0 set, but not RAID1 or RAID5) on the server (SSD is preferred).

2) As it is the IP address that Cassandra uses to identify itself as a node in the cluster, we need a dedicated NIC per instance so that each of them can have its own IP address.

3) Use a single `systemd` service definition to manage all the instances on a given server, offering a way to manipulate them individually when required.

4) Use Network Topology to enable rack-awareness so that each physical node can act as a rack from Cassandra's perspective, so replication would never happen in the same "rack" (or physical server). Otherwise, it is possible to lose data when a physical server goes down regardless of the replication factor (as that means multiple Cassandra instances will go down simultaneously).

Based on the latest RPMs for Apache Cassandra (3.11.x), the only file that has to be modified from the installed files is `/usr/share/cassandra/cassandra.in.sh`, but that should not be a problem when upgrading the application.

The OpenNMS instance will have PostgreSQL 10 embedded and a customized keyspace for Newts designed for Multi-DC in mind (but for rack-awareness in our use case) using TWCS for the compaction strategy, the recommended configuration for production (see `packer/config/opennms/newts.cql`).

## Installation and usage

* Make sure you have your AWS credentials on `~/.aws/credentials`, for example:

```ini
[default]
aws_access_key_id = XXXXXXXXXXXXXXXXX
aws_secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

* Install the latest Terraform binary from [terraform.io](https://www.terraform.io). Version 0.12.x or newer required.

* Install the latest Packer binary from [packer.io](https://www.packer.io)

* If necessary, tweak the versions on the packer initialization scripts located at `packer/scripts`.

* Tweak the common settings on `vars.tf`, specially `aws_key_name`, and `aws_region`.

  All the customizable settings are defined on `vars.tf`. Please do not change the other `.tf` files.

* Build the custom AMIs using Packer:

```bash
cd packer
packer build cassandra.json
packer build opennms.json
```

* Execute the following commands from the repository's root directory (at the same level as the .tf files):

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

* Wait for the Cassandra cluster to be ready. Each Cassandra instance is added one at a time (as only one node can be joining a cluster at any given time). Use `nodetool` to make sure all the 12 instances have joined the cluster:

```bash
nodetool -u cassandra -pw cassandra status
```

If there are missing instances, log into the appropriate Cassandra server and check which instances are running:

```bash
systemctl status cassandra3*
```

Let's say that the instance identified with `node2` is not running. Assuming that no other instance is joining the cluster, run the following:

```bash
systemctl start cassandra3@node2
```

Example of healthy status:

```bash
nodetool -u cassandra -pw cassandra status

Datacenter: Main
================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address      Load       Tokens       Owns (effective)  Host ID                               Rack
UN  172.17.1.33  69.92 KiB  256          16.3%             6e81946d-71fa-4543-ac09-fea0362f9799  cassandra2
UN  172.17.1.32  69.94 KiB  256          17.1%             b208f75c-255c-467d-89d1-b0a90a3f2d22  cassandra2
UN  172.17.1.51  69.94 KiB  256          17.4%             41caa47b-61fa-4e54-a5a5-fe4d2dc4bb6c  cassandra4
UN  172.17.1.21  98.65 KiB  256          16.6%             dcbfd31b-62a6-4629-8c1b-ba9150aff59d  cassandra1
UN  172.17.1.53  69.89 KiB  256          15.8%             52acbe92-fff1-4c4f-b952-cf4f20930de6  cassandra4
UN  172.17.1.52  92.77 KiB  256          16.3%             09eeeb3d-023e-44ea-9bc6-17bc28fb75f6  cassandra4
UN  172.17.1.23  74.99 KiB  256          17.3%             d1eea34f-24a3-4f37-b8f4-6f86e9807710  cassandra1
UN  172.17.1.22  93.95 KiB  256          16.1%             970d8eab-0479-4157-bfdb-20bdffee27e0  cassandra1
UN  172.17.1.41  69.95 KiB  256          17.4%             b1eb7d96-4f83-4aca-9b42-83fa44650b8c  cassandra3
UN  172.17.1.43  69.86 KiB  256          16.6%             d9527cb8-1f56-425d-854b-a13e38bef41e  cassandra3
UN  172.17.1.42  94.72 KiB  256          17.2%             3544f267-e72e-4637-a5b4-6bd1d8fed0bb  cassandra3
UN  172.17.1.31  69.92 KiB  256          15.9%             7d1f6f39-f666-47fa-8adb-60d05b146d17  cassandra2
```

* Import the requisitions, to collect JMX metrics from OpenNMS and the Cassandra servers every 30 seconds.

```bash
/opt/opennms/bin/provision.pl requisition import Cassandra
/opt/opennms/bin/provision.pl requisition import OpenNMS
```

* Connect to the Karaf Shell through SSH:

```bash
ssh -o ServerAliveInterval=10 -p 8101 admin@localhost
```

* Execute the `opennms:stress-metrics` command. The following is an example to generate 100000 samples per second:

```bash
opennms:stress-metrics -r 60 -n 15000 -f 20 -g 1 -a 100 -s 2 -t 100 -i 300
```

  Keep in mind, you'd need a ring buffer of 2097152 and a cache size of about 600000 for the above command.

* Check the OpenNMS performance graphs to understand how it behaves. Additionally, you could check the Monitoring Tab on the AWS Console for each EC2 instance.

* Enjoy!

## Termination

To destroy all the resources:

```shell
terraform destroy
```

In case there are issues while destroying the objects, please manually terminate the instances using the AWS console prior running `terraform destroy`.
