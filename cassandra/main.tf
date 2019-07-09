data "template_file" "cassandra" {
  template = file("${path.module}/template.tpl")

  vars = {
    hostname       = var.hostname
    cluster_name   = var.cluster_name
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

  connection {
    host        = coalesce(self.public_ip, self.private_ip)
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.aws_private_key)
  }

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
  count     = length(var.private_ips) - 1
  subnet_id = var.aws_subnet_id
  # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
  # force an interpolation expression to be interpreted as a list by wrapping it
  # in an extra set of list brackets. That form was supported for compatibilty in
  # v0.11, but is no longer supported in Terraform v0.12.
  #
  # If the expression in the following list itself returns a list, remove the
  # brackets to avoid interpretation as a list of lists. If the expression
  # returns a single list item then leave it as-is and remove this TODO comment.
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
