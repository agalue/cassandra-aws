# @author: Alejandro Galue <agalue@opennms.org>

# Access (make sure to use your own keys)

variable "aws_key_name" {
  description = "AWS Key Name, to access EC2 instances through SSH"
  default     = "agalue" # For testing purposes only
}

variable "aws_private_key" {
  description = "AWS Private Key Full Path"
  default     = "/Users/agalue/.ssh/agalue.private.aws.us-east-2.pem" # For testing purposes only
}

# Region and AMIs
# Make sure to run Packer on the same region

variable "aws_region" {
  description = "EC2 Region for the VPC"
  default     = "us-east-2" # For testing purposes only
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
      "delay": 320,
      "iplist": ["172.17.1.41", "172.17.1.42", "172.17.1.43"],
    },
    "cassandra4": {
      "delay": 500,
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
    cassandra_instance_heap_size = 16384 # In MB
    cassandra_replication_factor = 3 # Should be less than total racks (or servers)
    cassandra_snitch             = "GossipingPropertyFileSnitch" # Do not change

    # Should be consistent with opennms_newts_ttl
    twcs_window_size             = 7
    twcs_window_unit             = "DAYS"
    twcs_exp_sstable_check_freq  = 86400

    opennms_instance_type        = "c5.9xlarge"
    opennms_private_ip           = "172.17.1.100"
    opennms_cache_max_entries    = 2000000
    opennms_ring_buffer_size     = 4194304
    opennms_newts_ttl            = 31540000 # In Seconds
    opennms_newts_resource_shard = 604800 # In Seconds
    opennms_cache_use_redis      = false
  }
}

