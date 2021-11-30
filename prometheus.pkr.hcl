variable "region" { default = "us-east1" }
variable "zone" { default = "us-east1-b" }

variable "project" {
  type = string
}

source "amazon-ebs" "dev" {
  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      name                = "u21*"
      root-device-type    = "ebs"
    }
    owners      = ["self"]
    most_recent = true
  }

  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/sda1"
    encrypted             = false
    volume_size           = 16
    volume_type           = "gp2"
  }

  ami_name = "prometheus"

  ami_virtualization_type = "hvm"
  ena_support             = true
  encrypt_boot            = false
  force_deregister        = true
  force_delete_snapshot   = true
  instance_type           = "m5.large"
  ami_description         = "prometheus"
  region                  = var.region
  ssh_username            = "ubuntu"
  user_data_file          = "prometheus/cloudconfig.yml"

  tags = {
    OS_Version    = "Ubuntu"
    Release       = "Latest"
    Base_AMI_Name = "{{ .SourceAMIName }}"
    Name          = "Prometheus Server"
  }
}

source "googlecompute" "dev" {
  project_id          = var.project
  source_image_family = "ubuntu-dev"
  ssh_username        = "ubuntu"
  preemptible         = true
  zone                = var.zone

  image_storage_locations = [var.region]
  machine_type            = "n1-standard-1"
  image_family            = "prometheus"
  metadata_files = {
    user-data = "prometheus/cloudconfig.yml"
  }

  wrap_startup_script = false
  image_name          = "prometheus-${local.timestamp}"
  // service_account_email = local.gservice_account_id
  scopes = [
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/devstorage.full_control",
  ]
}


locals {
  timestamp   = regex_replace(timestamp(), "[- TZ:]", "")
  wait_script = <<EOT
      while [ ! -f /var/lib/cloud/instance/boot-finished ]
				  do echo 'Waiting for cloud-init...'
				sleep 10
				done	
    EOT
}

build {
  sources = ["sources.googlecompute.dev", "sources.amazon-ebs.dev", ]

  provisioner "shell-local" {
    inline = [
      "echo 'Running source ${source.type}'",
    ]
  }

  provisioner "shell" {
    inline = [
      local.wait_script,
      "echo finished",
    ]
    expect_disconnect = false
  }

  provisioner "file" {
    sources      = ["prometheus/prometheus.service", "prometheus/prometheus.yml"]
    destination = "/tmp/"
  }

  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} {{ .Path }}"
    inline = [
      "mv /tmp/prometheus.service /etc/systemd/system/",
      "mv /tmp/prometheus.yml /etc/prometheus/"
    ]
    inline_shebang = "/bin/bash -ex"
  }
}
