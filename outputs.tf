output "ssh-user" {
    value = var.ssh_user
}

output "ssh-private-key-path" {
    value = var.ssh_private_key_path
    sensitive = true
}

output "control-plane" {
    value = {
        for node in proxmox_vm_qemu.control-plane:
            node.name => node.default_ipv4_address
    }
}

output "control-plane-vip" {
    value = var.control_plane_vip
}

output "worker" {
    value = {
        for node in proxmox_vm_qemu.worker:
            node.name => node.default_ipv4_address
    }
}
