variable "aws_ami" {
  type = string
}

variable "aws_instance_type" {
  type = string
}

variable "aws_avail_zone" {
  type = string
}

variable "aws_subnet_id" {
  type = string
}

variable "aws_key_name" {
  type = string
}

variable "aws_security_groups" {
  type = list(string)
}

variable "aws_ebs_volume_size" {
  type = string
}

variable "aws_private_key" {
  type = string
}

variable "aws_tag_name" {
  type = string
}

variable "aws_ebs_device_names" {
  type = list(string)

  default = [
    "/dev/sdh",
    "/dev/sdi",
    "/dev/sdk",
    "/dev/sdl",
    "/dev/sdm",
    "/dev/sdn",
    "/dev/sdo",
  ]
}

variable "hostname" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "datacenter" {
  type = string
}

variable "rack" {
  type = string
}

variable "seed_name" {
  type = string
}

variable "heap_size" {
  type = string
}

variable "private_ips" {
  type = list(string)
}

variable "startup_delay" {
  type    = string
  default = "0"
}

variable "instance_delay" {
  type    = string
  default = "45"
}

