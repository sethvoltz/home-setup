###
# Proxmox and Kubernetes
###

variable "proxmox_settings" {
  type = object({
    api_url = string,
    token_id = string,
    token_secret = string
  })
  description = <<EOT
    proxmox_settings = {
      api_url : "URL of the JSON API endpoint for the proxmox server"
      token_id : "The API token that has permissions to perform provisioning"
      token_secret : "The secret value for the token_id"
    }
  EOT
  default = null
}

variable "proxmox_nodes" {
  type = list(string)
  description = "The set of Proxmox nodes to use for deploying the K3s cluster."
  default = ["examplenode"]

  validation {
    condition = length(var.proxmox_nodes) >= 1
    error_message = "At least one Proxmox node name must be declared."
  }
}

# Control Plane

variable "control_plane_node_count" {
  type = number
  description = "The total number of control plane nodes to provision. Must be an odd number."
  default = -1 # plan will override anything < 1 with calculated value

  validation {
    condition = var.control_plane_node_count % 2 != 0
    error_message = "Only odd numbers of control plane nodes are allowed."
  }
}

variable "control_start_vmid" {
  type = number
  description = "The ID to use as the first provisioned VM. Zero means use the next available ID."
  default = 0
}

# Workers

variable "worker_node_count" {
  type = number
  description = "The total number of worker nodes to provision."
  default = 1
}

variable "worker_start_vmid" {
  type = number
  description = "The ID to use as the first provisioned VM. Zero means use the next available ID."
  default = 0
}


###
# Individual Node Settings
###

# Node Network

variable "control_plane_vip" {
  type = string
  description = "The IP of the K3s control-plane VIP"
  default = null
}

variable "control_network" {
  type = object({
    dns = string,
    dhcp = bool,
    tag = number,
    network = string,
    first_host = number
  })
  description = <<EOT
    control_network = {
      dns : "The DNS server to assign to nodes"
      dhcp : "Whether to use DHCP or static assignment of IPs",
      tag : "VLAN tag for network, -1 to disable
      network : "CIDR slash notation network to use if assigning static IPs",
      first_host : "The first host IP to use on the network if assigning static IPs"
    }
  EOT
  default = {
    dns = "127.0.0.1",
    dhcp = true,
    tag = -1,
    network = null,
    first_host = null
  }

  validation {
    condition = var.control_network.dhcp || var.control_network.network != null
    error_message = "CIDR network required when DHCP is disabled"
  }
  validation {
    condition = var.control_network.dhcp || var.control_network.first_host != null
    error_message = "First host index required when DHCP is disabled"
  }
}

variable "worker_network" {
  type = object({
    dns = string,
    dhcp = bool,
    tag = number,
    network = string,
    first_host = number
  })
  description = <<EOT
    worker_network = {
      dns : "The DNS server to assign to nodes"
      dhcp : "Whether to use DHCP or static assignment of IPs",
      tag : "VLAN tag for network, -1 to disable
      network : "CIDR slash notation network to use if assigning static IPs",
      first_host : "The first host IP to use on the network if assigning static IPs"
    }
  EOT
  default = {
    dns = "127.0.0.1",
    dhcp = true,
    tag = -1,
    network = null,
    first_host = null
  }

  validation {
    condition = var.worker_network.dhcp || var.worker_network.network != null
    error_message = "CIDR network required when DHCP is disabled"
  }
  validation {
    condition = var.worker_network.dhcp || var.worker_network.first_host != null
    error_message = "First host index required when DHCP is disabled"
  }
}

# Node VMs

variable "control_vm" {
  type = object({
    cores = number,
    disk_gb = number,
    memory = number,
    storage = string
  })
  description = <<EOT
    control_vm = {
      cores : "The number of processor cores to give the VM"
      disk_gb : "The size of the VM disk in GB"
      memory : "The amount of RAM to give the VM in MB"
      storage : "Where to store the VM drive"
    }
  EOT
  default = {
    cores = 4,
    disk_gb = 20,
    memory = 4096,
    storage = "local-lvm"
  }
}

variable "worker_vm" {
  type = object({
    cores = number,
    disk_gb = number,
    memory = number,
    storage = string
  })
  description = <<EOT
    control_vm = {
      cores : "The number of processor cores to give the VM"
      disk_gb : "The size of the VM disk in GB"
      memory : "The amount of RAM to give the VM in MB"
      storage : "Where to store the VM drive"
    }
  EOT
  default = {
    cores = 2,
    disk_gb = 40,
    memory = 8192,
    storage = "local-lvm"
  }
}


###
# Provisioning
###

variable "template_name" {
  type = string
  default = "cloud-template-name"
}

variable "ssh_public_key_path" {
  type = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  type = string
  default   = "~/.ssh/id_ed25519"
  sensitive = true
}

variable "ssh_user" {
  type = string
  description = "The username configured in the template."
  default = "ubuntu"
}

variable "system_timezone" {
  type = string
  description = "The Linux timezone value to set the servers"
  default = "Etc/UTC"
}

variable "k3s_version" {
  type = string
  description = "Optional version specification to use."
  default = "v1.25.8+k3s1"
}

variable "k3s_token" {
  type = string
  default = "exampletoken"

  validation {
    condition = length(var.k3s_token) > 20
    error_message = "K3s token must be a long secure value. Please use a longer token."
  }
}

variable "metal_lb_ip_range" {
  type = string
  description = "The IP range to give to MetalLB for exposing services"
  default = "192.168.1.100-192.168.1.110"
}
