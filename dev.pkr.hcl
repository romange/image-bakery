packer {
  required_plugins {
    amazon = {
      version = ">= 1.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "project" {
  type = string
}

variable "zone" { default = "us-east1-b" }
variable "region" { default = "us-east1" }
variable "userdata_file" { type = string }
variable "az_resource_group" { type = string }
variable "arch" { default = "amd64" }
variable "os_ver" { default = "21.10" }
variable "use_debian" {
  type    = bool
  default = false
}

locals {
  gservice_account_id = "packer@${var.project}.iam.gserviceaccount.com"
  wait_script         = <<EOT
      while [ ! -f /var/lib/cloud/instance/boot-finished ]
				  do echo 'Waiting for cloud-init...'
				sleep 10
				done
    EOT
  timestamp           = regex_replace(timestamp(), "[- TZ:]", "")
  osver               = replace(var.os_ver, ".", "")
  ami_name            = "udev-${local.osver}-${var.arch}-${local.timestamp}"
  ami_owner           = var.use_debian ? "903794441882" : "099720109477"
  ami_templ           = var.use_debian ? "debian-12-${var.arch}-daily*" : "ubuntu/images/hvm-ssd/ubuntu-*-${var.os_ver}-${var.arch}-server-*"
  #userdata            = templatefile("${path.root}/provision/userdata.pkrtpl.yml", { os = "ubuntu" })
}

source "amazon-ebs" "dev" {
  source_ami_filter {
    filters = {
      virtualization-type = "hvm"

      name             = local.ami_templ
      root-device-type = "ebs"
    }
    owners      = [local.ami_owner]
    most_recent = true
  }

  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/sda1"
    encrypted             = false
    volume_size           = 16
    volume_type           = "gp2"
  }

  ami_name = local.ami_name

  ami_virtualization_type = "hvm"
  ena_support             = true
  encrypt_boot            = false
  force_deregister        = true
  force_delete_snapshot   = true
  iam_instance_profile    = "PackerBuilderRole"
  instance_type           = var.arch == "amd64" ? "m5.xlarge" : "m6g.xlarge"
  ami_description         = "udev-${local.osver}-${local.timestamp}"
  region                  = var.region
  ssh_username            = var.use_debian ? "admin" : "ubuntu"
  user_data_file          = var.userdata_file
  # spot does not work here because spo can not set ena_support attribute.

  run_tags = {
    Name  = "Packer Builder ${local.ami_name}"
  }

  tags = {
    OS_Version    = var.use_debian ? "Debian" : "Ubuntu"
    Release       = "Latest"
    Base_AMI_Name = "{{ .SourceAMIName }}"
    Name          = format("%s Development %s", var.use_debian ? "Debian" : "Ubuntu", var.os_ver)
  }
}

source "googlecompute" "dev" {
  project_id          = var.project
  source_image_family = format("ubuntu-%s", local.osver)
  ssh_username        = "ubuntu"
  preemptible         = true
  zone                = var.zone

  image_storage_locations = [split("-", var.region)[0]]
  machine_type            = "n1-standard-1"
  image_family            = "ubuntu-dev"
  metadata_files = {
    user-data = var.userdata_file
  }
  wrap_startup_script   = false
  image_name            = format("udev-%s-%s", local.osver, local.timestamp)
  service_account_email = local.gservice_account_id
  scopes = [
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/devstorage.full_control",
    "https://www.googleapis.com/auth/cloud-platform" # needed for secret manager
  ]

  image_labels = {
    type = "custom"
  }
}

source "azure-arm" "dev" {
  subscription_id = var.project

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-impish"
  image_sku       = "21_10-gen2"

  azure_tags = {
    dept = "dev"
  }

  location = var.region
  vm_size  = "Standard_B2s"

  shared_image_gallery_destination {
    subscription         = var.project
    resource_group       = var.az_resource_group
    gallery_name         = "MyGallery"
    image_name           = "ubuntu-dev"
    image_version        = "1.0.0"
    replication_regions  = [var.region]
    storage_account_type = "Standard_LRS"
  }

  managed_image_name                = "udev-2110-${local.timestamp}"
  managed_image_resource_group_name = var.az_resource_group
  user_data_file                    = var.userdata_file
}


// I could not use data source amazon-parameterstore because validate
// requires that shell environment would be set before it runs.
/*data "amazon-parameterstore" "bucket" {
  name = "artifactdir"
  with_decryption = false
}
*/

locals {
  cloud_env = {
    "amazon-ebs"    = ["AWS_DEFAULT_REGION=${var.region}"]
    "googlecompute" = []
    "azure-arm"     = []
  }
}

build {
  sources = ["sources.googlecompute.dev", "sources.amazon-ebs.dev",
  "sources.azure-arm.dev"]

  provisioner "shell-local" {
    inline = [
      "echo 'Running source ${source.type}'",
    ]
  }

  provisioner "shell" {
    inline = [
      local.wait_script,
      "echo finished, rebooting",
      "sudo reboot",
    ]
    expect_disconnect = true
  }

  provisioner "file" {
    source      = "provision/files"
    destination = "/tmp/"
  }

  provisioner "shell" {
    only             = ["googlecompute.dev", "amazon-ebs.dev", ]
    environment_vars = concat(["DEBIAN_FRONTEND=noninteractive"], local.cloud_env[source.type])
    execute_command  = "sudo env {{ .Vars }} {{ .Path }}"
    script           = "${path.root}/provision/base.sh"
  }

  provisioner "shell" {
    only            = ["azure-arm.dev"]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    inline_shebang = "/bin/sh -x"
  }

}
