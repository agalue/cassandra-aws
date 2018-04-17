output "cluster_name" {
  value = "${var.cluster_name}"
}

output "datacenter" {
  value = "${var.datacenter}"
}

output "rack" {
  value = "${var.rack}"
}

output "bootstrap" {
  value = "${data.template_file.cassandra.rendered}"
}
