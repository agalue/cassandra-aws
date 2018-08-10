# Cassandra in AWS

Ideally, it is recommended to have medium size servers as Cassandra nodes, rather than large or very large servers as Cassandra nodes.

Unfortunately, we might get something different from what we expect when we request a set of servers to build a database cluster like this one (as probably the company already has stablished rules for the kind of hardware you'll get for a given role).

Having big servers for Cassandra is a waste of resources, and the best way to workaround this problem, and have a better usage of this big servers in terms of performance, is by having multiple instances of Cassandra running at the same time on the same node.

Of course, this impose some challenges when configuring the solution.

This recipe, shows one way to solve this problem, by having a dedicated directory for each instance to hold the configuration, the data and the logs. This directory must point to a dedicated disk (or RAID0 set, but not RAID1 or RAID5) on the server (SSD is preffered).

Then, use a single systemd service definition to manage all the instances.

Based on the latest RPMs for Apache Cassandra (3.11.x), the only file that has to be modified from the installed files is `/usr/share/cassandra/cassandra.in.sh`, but that should not be a problem when upgrading the nodes.

This solution creates a network interface and a dedicated disk volume per Cassandra instance on each server (EC2 instance), this is due to the fact that a given Cassandra instance requires a least one dedicated disk and a dedicated fixed IP address.

The OpenNMS instance will have PostgreSQL 10 embedded, as well as a customized keyspace for Newts designed for Multi-DC in mind using TWCS for the compaction strategy, which is the recommended configuration for production (see `packer/config/opennms/newts.cql`).

## Installation and usage

* Make sure you have your AWS credentials on `~/.aws/credentials`, for example:

```INI
[default]
aws_access_key_id = XXXXXXXXXXXXXXXXX
aws_secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

* Install the Terraform binary from [terraform.io](https://www.terraform.io)

* Install the Packer binary from [packer.io](https://www.packer.io)

* If necessary, tweak the versions on the packer initialization scripts located at `packer/scripts`.

* Tweak the common settings on `vars.tf`, specially `aws_key_name`, `aws_private_key` and `aws_region`.

  All the customizable settings are defined on `vars.tf`. Please do not change the other `.tf` files.

* Build the custom AMIs using Packer:

```SHELL
cd packer
packer build cassandra.json
packer build opennms.json
```

* Execute the following commands from the repository's root directory (at the same level as the .tf files):

```SHELL
terraform init
terraform plan
terraform apply -auto-approve
```

* Wait for the Cassandra cluster to be ready. Each Cassandra instances is added one at a time (as only one node at a time can be joining a cluster). Use `nodetool` to make sure all the 12 instances have joined the cluster:

```SHELL
nodetool -u cassandra -pw cassandra status
```

If there are missing instances, log into the appropriate Cassandra server and check which instances are running:

```SHELL
systemctl status cassandra3*
```

Let's say that the instance identified with `node2` is not running. Assuming that no other instance is joining the cluster, run the following:

```SHELL
systemctl start cassandra3@node2
```

Example of healthy status:

```SHELL
[ec2-user@cassandra01 ~]$ nodetool -u cassandra -pw cassandra status
Datacenter: Main
================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address      Load       Tokens       Owns (effective)  Host ID                               Rack
UN  172.17.1.33  69.92 KiB  256          16.3%             6e81946d-71fa-4543-ac09-fea0362f9799  Rack2
UN  172.17.1.32  69.94 KiB  256          17.1%             b208f75c-255c-467d-89d1-b0a90a3f2d22  Rack2
UN  172.17.1.51  69.94 KiB  256          17.4%             41caa47b-61fa-4e54-a5a5-fe4d2dc4bb6c  Rack4
UN  172.17.1.21  98.65 KiB  256          16.6%             dcbfd31b-62a6-4629-8c1b-ba9150aff59d  Rack1
UN  172.17.1.53  69.89 KiB  256          15.8%             52acbe92-fff1-4c4f-b952-cf4f20930de6  Rack4
UN  172.17.1.52  92.77 KiB  256          16.3%             09eeeb3d-023e-44ea-9bc6-17bc28fb75f6  Rack4
UN  172.17.1.23  74.99 KiB  256          17.3%             d1eea34f-24a3-4f37-b8f4-6f86e9807710  Rack1
UN  172.17.1.22  93.95 KiB  256          16.1%             970d8eab-0479-4157-bfdb-20bdffee27e0  Rack1
UN  172.17.1.41  69.95 KiB  256          17.4%             b1eb7d96-4f83-4aca-9b42-83fa44650b8c  Rack3
UN  172.17.1.43  69.86 KiB  256          16.6%             d9527cb8-1f56-425d-854b-a13e38bef41e  Rack3
UN  172.17.1.42  94.72 KiB  256          17.2%             3544f267-e72e-4637-a5b4-6bd1d8fed0bb  Rack3
UN  172.17.1.31  69.92 KiB  256          15.9%             7d1f6f39-f666-47fa-8adb-60d05b146d17  Rack2
```

* Import the requisitions, to collect JMX metrics from OpenNMS and the Cassandra servers every 30 seconds.

```SHELL
[root@opennms ~]# /opt/opennms/bin/provision.pl requisition import Cassandra
[root@opennms ~]# /opt/opennms/bin/provision.pl requisition import OpenNMS
```

* Connect to the Karaf Shell through SSH:

```SHELL
[root@opennms ~]# ssh -o ServerAliveInterval=10 -p 8101 admin@localhost
```

  Make sure it is running at least Karaf 4.1.5.

* Execute the `metrics:stress` command. The following is an example to generate 100000 samples per second:

```
metrics:stress -r 60 -n 15000 -f 20 -g 10 -a 10 -s 1 -t 200 -i 300
```

* Check the OpenNMS performance graphs to understand how it behaves. Additionally, you could check the Monitoring Tab on the AWS Console for each EC2 instance.

* Enjoy!

## Termination

To destroy all the resources:

```shell
terraform destroy
```

It seems like terraform has some dependency issues when destroying the lab using modules. If this happens, you have to manually terminate the instances prior running `terraform destoy`; otherwise it stays forever waiting on destroying the internet gateway without even trying to shutdown the resources created inside the modules.