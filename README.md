# Cassandra in AWS

Ideally, it is recommended to have medium size servers as Cassandra nodes, rather than large or very large servers as Cassandra nodes.

Unfortunately, we get something different from what we expect when we want to setup a database.

Having big servers for Cassandra is a waste of resources, and the best way to workaround this problem, and have a better usage of this big servers in terms of performance, is by having multiple instances of Cassandra running at the same time on the same node.

Of course, this impose some challenges when consifuring the solution.

This recipe, shows one way to solve this problem, by having a dedicated directory for each instance to hold the configuration, the data and the logs.

Then, use a single systemd service definition to manage all of them.

Based on the latest RPMs for Apache Cassandra (3.11.x), the only file that has to be modified from the installed files is `/usr/share/cassandra/cassandra.in.sh`, but that should not be a problem when upgrading the nodes.

Naturally, the solution creates a network interface and a dedicated disk volume per Cassandra instance on each server (EC2 instance), this is due to the fact that a given Cassandra instance requires a least one dedicated disk and a dedicated IP address.

## Installation and usage

* Make sure you have your AWS credentials on `~/.aws/credentials`, for example:

```INI
[default]
aws_access_key_id = XXXXXXXXXXXXXXXXX
aws_secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

* Install the Terraform binary from [terraform.io](https://www.terraform.io)

* Install the Packer binary from [packer.io](https://www.packer.io)

* Tweak the versions on the packer initialization scripts located at `packer/scripts`.

* Tweak the common settings on `vars.tf`, specially `aws_key_name` and `aws_private_key`, to match the chosen region. All the customizable settings are defined on `vars.tf`. Please do not change the other `.tf` files.

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
terraform apply
```

* Once the Cassandra cluster is ready, initalize the keyspace, from one of the cassandra servers:

```SHELL
cat <<EOF > ~/newts.cql
CREATE KEYSPACE newts WITH replication = {'class' : 'NetworkTopologyStrategy', 'Main' : 3, 'DR': 3 };
CREATE TABLE newts.samples (context text, partition int, resource text, collected_at timestamp, metric_name text, value blob, attributes map<text, text>,    PRIMARY KEY((context, partition, resource), collected_at, metric_name)) WITH compaction = { 'compaction_window_size': '7', 'compaction_window_unit': 'DAYS',  'expired_sstable_check_frequency_seconds': '86400', 'class': 'org.apache.cassandra.db.compaction.TimeWindowCompactionStrategy' } AND gc_grace_seconds = 604800 AND read_repair_chance = 0;
CREATE TABLE newts.terms (context text, field text, value text, resource text, PRIMARY KEY((context, field, value), resource));
CREATE TABLE newts.resource_attributes (context text, resource text, attribute text, value text, PRIMARY KEY((context, resource), attribute));
CREATE TABLE newts.resource_metrics (context text, resource text, metric_name text, PRIMARY KEY((context, resource), metric_name));
EOF
cqlsh cassandra1 < ~/newts.cql
```

* Start OpenNMS

* Import the test requisition, to collect JMX metrics from OpenNMS and one of the Cassandra servers.

* Connect to the Karaf SSH Console

```SHELL
ssh -o ServerAliveInterval=10 -p 8101 admin@localhost
```

* Execute the `metrics:stress` command. The following is an example to generate 100000 samples per second:

```
metrics:stress -r 60 -n 15000 -f 20 -g 10 -a 10 -s 1 -t 200 -i 300
```

* Enjoy!
