# @author: Alejandro Galue <agalue@opennms.org>

module "cassandra1" {
  source              = "./cassandra"
  aws_ami             = "${data.aws_ami.cassandra.image_id}"
  aws_instance_type   = "${var.settings["cassandra_instance_type"]}"
  aws_avail_zone      = "${data.aws_availability_zones.available.names[0]}"
  aws_subnet_id       = "${aws_subnet.public.id}"
  aws_key_name        = "${var.aws_key_name}"
  aws_ebs_volume_size = "60"
  aws_private_key     = "${var.aws_private_key}"
  aws_tag_name        = "Terraform Cassandra 1"
  aws_security_groups = ["${aws_security_group.common.id}", "${aws_security_group.cassandra.id}"]
  hostname            = "cassandra01"
  cluster_name        = "${var.settings["cassandra_cluster_name"]}"
  datacenter          = "${var.settings["cassandra_datacenter_name"]}"
  rack                = "Rack1"
  seed_name           = "${var.settings["cassandra_seed"]}"
  private_ips         = "${var.cassandra_ip_addresses[0]}"
  heap_size           = "${var.settings["cassandra_instance_heap_size"]}"
  startup_delay       = "0"
}

module "cassandra2" {
  source              = "./cassandra"
  aws_ami             = "${data.aws_ami.cassandra.image_id}"
  aws_instance_type   = "${var.settings["cassandra_instance_type"]}"
  aws_avail_zone      = "${data.aws_availability_zones.available.names[0]}"
  aws_subnet_id       = "${aws_subnet.public.id}"
  aws_key_name        = "${var.aws_key_name}"
  aws_ebs_volume_size = "60"
  aws_private_key     = "${var.aws_private_key}"
  aws_tag_name        = "Terraform Cassandra 2"
  aws_security_groups = ["${aws_security_group.common.id}", "${aws_security_group.cassandra.id}"]
  hostname            = "cassandra02"
  cluster_name        = "${var.settings["cassandra_cluster_name"]}"
  datacenter          = "${var.settings["cassandra_datacenter_name"]}"
  rack                = "Rack2"
  seed_name           = "${var.settings["cassandra_seed"]}"
  private_ips         = "${var.cassandra_ip_addresses[1]}"
  heap_size           = "${var.settings["cassandra_instance_heap_size"]}"
  startup_delay       = "120"
}

module "cassandra3" {
  source              = "./cassandra"
  aws_ami             = "${data.aws_ami.cassandra.image_id}"
  aws_instance_type   = "${var.settings["cassandra_instance_type"]}"
  aws_avail_zone      = "${data.aws_availability_zones.available.names[0]}"
  aws_subnet_id       = "${aws_subnet.public.id}"
  aws_key_name        = "${var.aws_key_name}"
  aws_ebs_volume_size = "60"
  aws_private_key     = "${var.aws_private_key}"
  aws_tag_name        = "Terraform Cassandra 3"
  aws_security_groups = ["${aws_security_group.common.id}", "${aws_security_group.cassandra.id}"]
  hostname            = "cassandra03"
  cluster_name        = "${var.settings["cassandra_cluster_name"]}"
  datacenter          = "${var.settings["cassandra_datacenter_name"]}"
  rack                = "Rack3"
  seed_name           = "${var.settings["cassandra_seed"]}"
  private_ips         = "${var.cassandra_ip_addresses[2]}"
  heap_size           = "${var.settings["cassandra_instance_heap_size"]}"
  startup_delay       = "240"
}

module "cassandra4" {
  source              = "./cassandra"
  aws_ami             = "${data.aws_ami.cassandra.image_id}"
  aws_instance_type   = "${var.settings["cassandra_instance_type"]}"
  aws_avail_zone      = "${data.aws_availability_zones.available.names[0]}"
  aws_subnet_id       = "${aws_subnet.public.id}"
  aws_key_name        = "${var.aws_key_name}"
  aws_ebs_volume_size = "60"
  aws_private_key     = "${var.aws_private_key}"
  aws_tag_name        = "Terraform Cassandra 4"
  aws_security_groups = ["${aws_security_group.common.id}", "${aws_security_group.cassandra.id}"]
  hostname            = "cassandra04"
  cluster_name        = "${var.settings["cassandra_cluster_name"]}"
  datacenter          = "${var.settings["cassandra_datacenter_name"]}"
  rack                = "Rack4"
  seed_name           = "${var.settings["cassandra_seed"]}"
  private_ips         = "${var.cassandra_ip_addresses[3]}"
  heap_size           = "${var.settings["cassandra_instance_heap_size"]}"
  startup_delay       = "360"
}
