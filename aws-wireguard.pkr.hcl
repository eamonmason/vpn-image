packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  packerstarttime = formatdate("YYYY-MM-DD-hhmm", timestamp())
}

data "amazon-ami" "amazon-linux" {
  filters = {
    name = "*al2023-ami-2023*"
  }
  owners      = ["amazon"]
  most_recent = true
}


source "amazon-ebs" "al" {
  ami_name                    = "wireguard-server-${local.packerstarttime}"
  instance_type               = "${var.instance_type}"
  region                      = "${var.region}"
  source_ami                  = data.amazon-ami.amazon-linux.id
  ssh_username                = "ec2-user"
  vpc_id                      = "${var.vpc_id}"
  subnet_id                   = "${var.subnet_id}"
  security_group_ids          = ["${var.security_group_id}"]
  associate_public_ip_address = "true"
}


build {
  name = "wireguard-packer"
  sources = [
    "source.amazon-ebs.al"
  ]
  provisioner "shell" {
    pause_before = "30s"
    inline       = ["mkdir /tmp/provisioning-scripts"]
  }

  provisioner "file" {
    sources     = ["scripts/install-wireguard.sh", "scripts/wg0.conf"]
    destination = "/tmp/provisioning-scripts/"
  }

  provisioner "shell" {
    environment_vars = [
      "SERVER_PRIVATE_KEY=${var.server_private_key}",
      "SERVER_PUBLIC_KEY=${var.server_public_key}",
      "CLIENT_PUBLIC_KEY=${var.client_public_key}"
    ]
    inline  = ["sudo -E /tmp/provisioning-scripts/install-wireguard.sh"]
    timeout = "5m"
  }
}