# @author: Alejandro Galue <agalue@opennms.org>

# Access (make sure to use your own keys)

variable "aws_key_name" {
  description = "AWS Key Name, to access EC2 instances through SSH"
  default     = "agalue" # For testing purposes only (change accordingly)
}

# Region and AMIs
# Make sure to run Packer on the same region

variable "aws_region" {
  description = "EC2 Region for the VPC"
  default     = "us-east-2" # For testing purposes only (change accordingly)
}

data "aws_ami" "cassandra" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["cassandra-*"]
  }
}

data "aws_ami" "opennms" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["horizon-pg10-cass-*"]
  }
}

variable "vpc_cidr" {
  description = "CIDR for the whole VPC"
  default     = "172.17.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for the public subnet"
  default     = "172.17.1.0/24"
}

# Only one instance can join the cluster at a time.
# By default, the cassandra module waits 60sec before start each instance.
# There are going to be 3 instances per server/module.
# Therefore, the total time to wait per server is 180sec (delay).
# IP Addresses must be consistent with packer/config/imports/pending/Cassandra.xml
variable "cassandra_servers" {
  description = "Servers with multiple Cassandra instances (each acting as a rack)"
  type        = map

  default = {
    "cassandra1": {
      "delay": 0,
      "iplist": ["172.17.1.21", "172.17.1.22", "172.17.1.23"],
    },
    "cassandra2": {
      "delay": 180,
      "iplist": ["172.17.1.31", "172.17.1.32", "172.17.1.33"],
    },
    "cassandra3": {
      "delay": 360,
      "iplist": ["172.17.1.41", "172.17.1.42", "172.17.1.43"],
    },
    "cassandra4": {
      "delay": 540,
      "iplist": ["172.17.1.51", "172.17.1.52", "172.17.1.53"],
    },
  }
}

variable "settings" {
  description = "Common application settings"
  type        = map

  default = {
    cassandra_instance_type      = "m4.10xlarge"
    cassandra_seed               = "172.17.1.21" # First instance from first rack
    cassandra_cluster_name       = "Production"
    cassandra_datacenter_name    = "Main"
    cassandra_volume_size        = 200 # In GB
    cassandra_num_tokens         = 256 # 16 recommended
    cassandra_instance_heap_size = 24576 # In MB per instance
    cassandra_replication_factor = 3 # Should be less than total racks (or servers)
    cassandra_snitch             = "GossipingPropertyFileSnitch" # Do not change

    # Should be consistent with opennms_newts_ttl
    twcs_window_size             = 7
    twcs_window_unit             = "DAYS"
    twcs_exp_sstable_check_freq  = 86400
    twcs_gc_grace_seconds        = 604800

    opennms_instance_type        = "m4.10xlarge"
    opennms_private_ip           = "172.17.1.100"
    opennms_newts_ttl            = 31540000 # In Seconds
    opennms_newts_resource_shard = 604800 # In Seconds
    opennms_cache_use_redis      = false

    # opennms:stress-metrics -r 60 -n 15000 -f 20 -g 1 -a 100 -s 2 -t 100 -i 300
    opennms_cache_max_entries    = 1000000
    opennms_ring_buffer_size     = 2097152
  }
}

