# @author: Alejandro Galue <agalue@opennms.org>

module "cassandra1" {
  source              = "./cassandra"
  aws_ami             = "${data.aws_ami.cassandra.image_id}"
  aws_instance_type   = "${var.settings["cassandra_instance_type"]}"
  aws_avail_zone      = "${data.aws_availability_zones.available.names[0]}"
  aws_subnet_id       = "${aws_subnet.public.id}"
  aws_key_name        = "${var.aws_key_name}"
  aws_ebs_volume_size = "${var.settings["cassandra_volume_size"]}"
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
  aws_ebs_volume_size = "${var.settings["cassandra_volume_size"]}"
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
  aws_ebs_volume_size = "${var.settings["cassandra_volume_size"]}"
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
  aws_ebs_volume_size = "${var.settings["cassandra_volume_size"]}"
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

data "template_file" "opennms" {
  template = "${file("${path.module}/opennms.tpl")}"

  vars {
    hostname          = "opennms"
    cassandra_server  = "${var.settings["cassandra_seed"]}"
    heap_size         = "${var.settings["opennms_heap_size"]}"
    cache_max_entries = "${var.settings["opennms_cache_max_entries"]}"
    ring_buffer_size  = "${var.settings["opennms_ring_buffer_size"]}"
  }
}

resource "aws_instance" "opennms" {
  ami           = "${data.aws_ami.opennms.image_id}"
  instance_type = "${var.settings["opennms_instance_type"]}"
  subnet_id     = "${aws_subnet.public.id}"
  key_name      = "${var.aws_key_name}"
  private_ip    = "${var.settings["opennms_private_ip"]}"
  user_data     = "${data.template_file.opennms.rendered}"

  associate_public_ip_address = true

  vpc_security_group_ids = [
    "${aws_security_group.common.id}",
    "${aws_security_group.opennms.id}",
  ]

  depends_on = [
    "module.cassandra1",
    "module.cassandra2",
    "module.cassandra3",
    "module.cassandra4",
  ]

  connection {
    user        = "ec2-user"
    private_key = "${file("${var.aws_private_key}")}"
  }

  tags {
    Name = "Terraform OpenNMS Server"
  }
}
