# @author: Alejandro Galue <agalue@opennms.org>

module "cassandra" {
  source              = "./cassandra"

  for_each = var.cassandra_servers

  aws_ami             = data.aws_ami.cassandra.image_id
  aws_instance_type   = var.settings["cassandra_instance_type"]
  aws_avail_zone      = data.aws_availability_zones.available.names[0]
  aws_subnet_id       = aws_subnet.public.id
  aws_key_name        = var.aws_key_name
  aws_ebs_volume_size = var.settings["cassandra_volume_size"]
  aws_private_key     = var.aws_private_key
  aws_tag_name        = "Terraform ${each.key}"
  aws_security_groups = [aws_security_group.common.id, aws_security_group.cassandra.id]
  hostname            = each.key
  cluster_name        = var.settings["cassandra_cluster_name"]
  snitch              = var.settings["cassandra_snitch"]
  datacenter          = var.settings["cassandra_datacenter_name"]
  rack                = each.key # Same as hostname
  seed_name           = var.settings["cassandra_seed"]
  private_ips         = each.value.iplist
  heap_size           = var.settings["cassandra_instance_heap_size"]
  startup_delay       = each.value.delay
  instance_delay      = 60
}


data "template_file" "opennms" {
  template = file("${path.module}/opennms.tpl")

  vars = {
    hostname                    = "opennms"
    cassandra_seed              = var.settings["cassandra_seed"]
    cassandra_snitch            = var.settings["cassandra_snitch"]
    cassandra_rf                = var.settings["cassandra_replication_factor"]
    cassandra_dc                = var.settings["cassandra_datacenter_name"]
    cache_max_entries           = var.settings["opennms_cache_max_entries"]
    ring_buffer_size            = var.settings["opennms_ring_buffer_size"]
    newts_ttl                   = var.settings["opennms_newts_ttl"]
    newts_resource_shard        = var.settings["opennms_newts_resource_shard"]
    twcs_gc_grace_seconds       = var.settings["twcs_gc_grace_seconds"]
    twcs_window_size            = var.settings["twcs_window_size"]
    twcs_window_unit            = var.settings["twcs_window_unit"]
    twcs_exp_sstable_check_freq = var.settings["twcs_exp_sstable_check_freq"]
    use_redis                   = var.settings["opennms_cache_use_redis"]
  }
}

resource "aws_instance" "opennms" {
  ami           = data.aws_ami.opennms.image_id
  instance_type = var.settings["opennms_instance_type"]
  subnet_id     = aws_subnet.public.id
  key_name      = var.aws_key_name
  private_ip    = var.settings["opennms_private_ip"]
  user_data     = data.template_file.opennms.rendered

  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.common.id,
    aws_security_group.opennms.id,
  ]

  depends_on = [
    module.cassandra,
  ]

  connection {
    host        = coalesce(self.public_ip, self.private_ip)
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.aws_private_key)
  }

  tags = {
    Name        = "Terraform OpenNMS Server"
    Environment = "Test"
    Department  = "Support"
  }
}

output "opennms" {
  value = aws_instance.opennms.public_ip
}

output "cassandra" {
  value = [
    for instance in module.cassandra:
    instance.public_ip
  ]
}