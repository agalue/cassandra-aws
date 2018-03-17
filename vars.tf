# @author: Alejandro Galue <agalue@opennms.org>

# Access (make sure to use your own keys)

variable "aws_key_name" {
  description = "AWS Key Name, to access EC2 instances through SSH"
  default     = "agalue"                                            # For testing purposes only
}

variable "aws_private_key" {
  description = "AWS Private Key Full Path"
  default     = "/Users/agalue/.ssh/agalue.private.aws.us-west-2.pem" # For testing purposes only
}

# Region and AMIs
# Make sure to run Packer on the same region

variable "aws_region" {
  description = "EC2 Region for the VPC"
  default     = "us-west-2"              # For testing purposes only
}

data "aws_ami" "cassandra" {
  most_recent = true

  filter {
    name   = "name"
    values = ["cassandra-*"]
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

variable "cassandra_ip_addresses" {
  description = "Cassandra Servers Private IPs"
  type        = "list"

  default = [
    ["172.17.1.21", "172.17.1.22", "172.17.1.23"],
    ["172.17.1.31", "172.17.1.32", "172.17.1.33"],
    ["172.17.1.41", "172.17.1.42", "172.17.1.43"],
    ["172.17.1.51", "172.17.1.52", "172.17.1.53"],
  ]
}

variable "settings" {
  description = "Common application settings"
  type        = "map"

  default = {
    cassandra_instance_type      = "t2.2xlarge"
    cassandra_cluster_name       = "Cassandra-Cluster"
    cassandra_seed               = "172.17.1.21"
    cassandra_instance_heap_size = 8192
  }
}
