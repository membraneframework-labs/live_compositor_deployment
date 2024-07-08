packer {
  required_plugins {
    vsphere = {
      version = ">= 1.2.9"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "with-gpu" {
  type    = bool
  default = false
}

source "amazon-ebs" "image" {
  ami_name      = var.with-gpu ? "membrane_live_compositor_example_with_gpu_ubuntu_24.04_{{timestamp}}" : "membrane_live_compositor_example_ubuntu_24.04_{{timestamp}}"
  instance_type = var.with-gpu ? "g4dn.xlarge" : "t3.micro"
  region        = var.region
  source_ami_filter {
    filters = {
      // For instances with GPU you can use an older version of ubuntu, but CPU only
      // instances need at least ubuntu 23.10 (It includes Vulkan MESA drivers that implemnt all
      // necessary features that compositor relies on).
      name                = "ubuntu/images/*ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] // Canonical
  }
  ssh_username = "ubuntu"
}

build {
  sources = ["source.amazon-ebs.image"]

  provisioner "file" {
    source = "./membrane.service"
    destination = "/tmp/live-compositor.service"
  }

  provisioner "shell" {
    inline = ["mkdir -p /home/ubuntu/project"]
  }

  provisioner "file" {
    sources = [
        "../../project/mix.exs",
        "../../project/mix.lock",
        "../../project/lib"
    ]
    destination = "/home/ubuntu/project/"
  }

  provisioner "shell" {
    script = "./membrane_setup.sh"
    env = {
      ENABLE_GPU = var.with-gpu ? "1" : "0"
    }
  }
}
