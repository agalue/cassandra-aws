# @author: Alejandro Galue <agalue@opennms.org>

resource "aws_security_group" "common" {
  name        = "terraform-opennms-common-sq"
  description = "Allow basic protocols"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 161
    to_port     = 161
    protocol    = "udp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = "${aws_vpc.default.id}"

  tags {
    Name = "Terraform Common SG"
  }
}

resource "aws_security_group" "cassandra" {
  name        = "terraform-opennms-cassandra-sg"
  description = "Allow Cassandra connections."

  ingress {
    from_port   = 7199
    to_port     = 7599
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    from_port   = 7000
    to_port     = 7020
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    from_port   = 9042
    to_port     = 9442
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    from_port   = 9160
    to_port     = 9560
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = "${aws_vpc.default.id}"

  tags {
    Name = "Terraform Cassandra SG"
  }
}

resource "aws_security_group" "opennms" {
  name        = "terraform-opennms-sg"
  description = "Allow OpenNMS connections."

  ingress {
    from_port   = 8980
    to_port     = 8980
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 18980
    to_port     = 18980
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = "${aws_vpc.default.id}"

  tags {
    Name = "Terraform OpenNMS Core SG"
  }
}
