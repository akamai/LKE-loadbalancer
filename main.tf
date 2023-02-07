terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "1.28.0"
    }
  }
}
provider "linode" {
    token = var.token
}

resource "linode_instance" "loadbalancer" {
	label = var.label
	region = var.region
	type = "g6-dedicated-8"
	image = "linode/ubuntu22.04"
	private_ip = true
	
}
