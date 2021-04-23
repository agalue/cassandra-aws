data "template_file" "cassandra" {
  template = file("${path.module}/template.tpl")

  vars = {
    hostname       = var.hostname
    cluster_name   = var.cluster_name
    snitch         = var.snitch
    datacenter     = var.datacenter
    rack           = var.rack
    seed_name      = var.seed_name
    private_ips    = join(",", var.private_ips)
    heap_size      = var.heap_size
    startup_delay  = var.startup_delay
    instance_delay = var.instance_delay
    device_names   = join(",", var.aws_ebs_device_names)
  }
}

resource "aws_instance" "cassandra" {
  ami           = var.aws_ami
  instance_type = var.aws_instance_type
  subnet_id     = var.aws_subnet_id
  key_name      = var.aws_key_name
  private_ip    = element(var.private_ips, 0)
  user_data     = data.template_file.cassandra.rendered

  associate_public_ip_address = true

  vpc_security_group_ids = var.aws_security_groups

  timeouts {
    create = "30m"
    delete = "15m"
  }

  tags = {
    Name        = var.aws_tag_name
    Environment = "Test"
    Department  = "Support"
  }
}

resource "aws_network_interface" "cassandra" {
  count           = length(var.private_ips) - 1
  subnet_id       = var.aws_subnet_id
  private_ips     = [var.private_ips[count.index + 1]]
  security_groups = var.aws_security_groups

  attachment {
    instance     = aws_instance.cassandra.id
    device_index = count.index + 1
  }

  tags = {
    Name        = "${var.aws_tag_name} NIC ${count.index + 1}"
    Environment = "Test"
    Department  = "Support"
  }
}

resource "aws_ebs_volume" "cassandra" {
  count             = length(var.private_ips)
  availability_zone = var.aws_avail_zone
  size              = var.aws_ebs_volume_size
  type              = "gp2"

  tags = {
    Name        = "${var.aws_tag_name} Volume ${count.index + 1}"
    Environment = "Test"
    Department  = "Support"
  }
}

resource "aws_volume_attachment" "cassandra" {
  count        = length(var.private_ips)
  device_name  = element(var.aws_ebs_device_names, count.index)
  volume_id    = element(aws_ebs_volume.cassandra.*.id, count.index)
  instance_id  = aws_instance.cassandra.id
  force_detach = true
}
