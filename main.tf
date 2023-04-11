locals {
  proxmox_node_count = length(var.proxmox_nodes)
  ha_control_count = local.proxmox_node_count % 2 == 0 ? local.proxmox_node_count - 1 : local.proxmox_node_count
  control_plane_node_count = var.control_plane_node_count < 1 ? local.ha_control_count : var.control_plane_node_count

  control_cidr_mask = split("/", var.control_network.network)[1]
  control_gateway_ip = cidrhost(var.control_network.network, 1)
  worker_cidr_mask = split("/", var.worker_network.network)[1]
  worker_gateway_ip = cidrhost(var.worker_network.network, 1)
}

# https://registry.terraform.io/providers/Telmate/proxmox/latest/docs/resources/vm_qemu
# control-plane nodes are known in k3s as a server; worker nodes are agent

resource "proxmox_vm_qemu" "control-plane" {
  count   = local.control_plane_node_count
  name    = format("kube-control-%02d", count.index)
  desc    = "Kube control-plane node"
  tags    = join(";", sort(["control-plane", "k3s", "kubernetes"]))
  target_node = var.proxmox_nodes[count.index % local.proxmox_node_count]

  depends_on = [
    proxmox_vm_qemu.control-plane[0]
  ]

  clone = var.template_name
  vmid  = var.control_start_vmid == 0 ? 0 : var.control_start_vmid + count.index

  agent    = 1
  os_type  = "cloud-init"
  cores    = var.control_vm.cores
  sockets  = 1
  memory   = var.control_vm.memory
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disk {
    slot     = 0
    size     = "${var.control_vm.disk_gb}G"
    type     = "scsi"
    storage  = var.control_vm.storage
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = var.control_network.tag
  }

  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  ipconfig0 = (
    var.control_network.dhcp
      ? "ip=dhcp"
      : "ip=${cidrhost(var.control_network.network, var.control_network.first_host + count.index)}/${local.control_cidr_mask},gw=${local.control_gateway_ip}"
  )
  nameserver = "${var.control_network.dns}"

  sshkeys = file("${var.ssh_public_key_path}")

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file("${var.ssh_private_key_path}")
    host        = self.default_ipv4_address
  }

  provisioner "file" {
    destination = "/tmp/bootstrap_k3s.sh"
    content = templatefile("bootstrap_k3s.sh.tpl",
      {
        k3s_get_url = var.k3s_get_url,
        k3s_token = var.k3s_token,
        k3s_cluster_join_ip = proxmox_vm_qemu.control-plane[0].default_ipv4_address
        k3s_version_override = var.k3s_version_override
      }
    )
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "chmod +x /tmp/bootstrap_k3s.sh",
      "sudo /tmp/bootstrap_k3s.sh"
    ]
  }
}

resource "proxmox_vm_qemu" "worker" {
  # agent (worker) nodes
  count   = var.worker_node_count
  name    = format("kube-worker-%02d", count.index)
  desc    = "Kube worker node"
  tags    = join(";", sort(["worker", "k3s", "kubernetes"]))
  target_node = var.proxmox_nodes[(local.control_plane_node_count + count.index) % local.proxmox_node_count]

  depends_on = [
    proxmox_vm_qemu.control-plane[0]
  ]

  clone = var.template_name
  vmid  = var.worker_start_vmid == 0 ? 0 : var.worker_start_vmid + count.index

  agent    = 1
  os_type  = "cloud-init"
  cores    = var.worker_vm.cores
  sockets  = 1
  cpu      = "host"
  memory   = var.worker_vm.memory
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disk {
    slot     = 0
    size     = "${var.worker_vm.disk_gb}G"
    type     = "scsi"
    storage  = var.worker_vm.storage
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = var.worker_network.tag
  }

  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  ipconfig0  = (
    var.worker_network.dhcp
      ? "ip=dhcp"
      : "ip=${cidrhost(var.worker_network.network, var.worker_network.first_host + count.index)}/${local.worker_cidr_mask},gw=${local.worker_gateway_ip}"
  )
  nameserver = "${var.worker_network.dns}"

  sshkeys    = file("${var.ssh_public_key_path}")

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file("${var.ssh_private_key_path}")
    host        = self.default_ipv4_address
  }

  provisioner "file" {
    destination = "/tmp/bootstrap_k3s.sh"
    content = templatefile("bootstrap_k3s.sh.tpl",
      {
        k3s_get_url = var.k3s_get_url,
        k3s_token = var.k3s_token,
        k3s_cluster_join_ip = proxmox_vm_qemu.control-plane[0].default_ipv4_address
        k3s_version_override = var.k3s_version_override
      }
    )
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "chmod +x /tmp/bootstrap_k3s.sh",
      "sudo /tmp/bootstrap_k3s.sh"
    ]
  }
}
