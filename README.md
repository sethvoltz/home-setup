# terraform-proxmox-k3s-rancher

Useful for labbing at home, this repository provides a quick and easy way to deploy a [K3s](https://k3s.io/) cluster on an existing [Proxmox VE](https://www.proxmox.com/en/proxmox-ve) hypervisor using [Terraform](https://www.terraform.io/).

## Setup

Before getting started, a Proxmox API token is required so that you can use Terraform with your Proxmox datacenter.

On your Proxmox host:

```sh
pveum role add TerraformProv -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit"

pveum user add terraform-prov@pve

### IMPORTANT: Copy/paste and save the token value (secret) presented after running the command below. You are only shown it once and need to set it later as in terraform.tfvars
pveum user token add terraform-prov@pve api

pveum aclmod / -user terraform-prov@pve -tokens 'terraform-prov@pve!api' -role TerraformProv
```

On your workstation:

```sh
# Set to path of SSH key to be used (must be passwordless)
export SSH_KEY_PATH=~/.ssh/terraform_proxmox_ssh_key_nopassword

# Generate a passwordless SSH keypair to be used
ssh-keygen -f $SSH_KEY_PATH -t ed25519 -C "terraform-prov@pve!api" -N "" -q
```

## Prepare a Machine Image

In order to deploy VMs or CTs, you need to prepare an image, and have it available as a template on your Proxmox cluster. On your Proxmox host:

```sh
DISTRO="ubuntu" # change for correct distro, e.g. debian
RELEASE="kinetic" # change to current release, e.g. bullseye
RELEASE_VERSION=22.10 # 11 for debian
VM_ID=8000
SSH_KEY="" # put ssh key here
STORAGE_NAME="ceph" # change for preferred PVE storage, e.g. local-lvm

IMAGE_NAME=${DISTRO}-${RELEASE}-${RELEASE_VERSION}
ISO_PATH="/mnt/pve/cephfs/template/iso/" # e.g. /var/lib/vz/template/iso/

# Ubuntu
wget -O ${ISO_PATH}${IMAGE_NAME}.img https://cloud-images.ubuntu.com/releases/${RELEASE_VERSION}/release/${DISTRO}-${RELEASE_VERSION}-server-cloudimg-amd64.img

# Debian
#wget -O ${ISO_PATH}${IMAGE_NAME}.qcow https://cloud.debian.org/images/cloud/${RELEASE}/latest/debian-${RELEASE_VERSION}-genericcloud-amd64.qcow2

virt-sysprep \
  -a ${ISO_PATH}${IMAGE_NAME}.img \
  --network \
  --update \
  --install qemu-guest-agent,jq,git,curl,vim,wget,unzip \
  --truncate /etc/machine-id

qm create ${VM_ID} --name cloud-${IMAGE_NAME} \
  --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0

qm importdisk ${VM_ID} ${ISO_PATH}${IMAGE_NAME}.img $STORAGE_NAME # Ubuntu
#qm importdisk ${VM_ID} ${IMAGE_NAME}.qcow $STORAGE_NAME # Debian

ssh_tmpfile=$(mktemp /tmp/sshkey.XXX.pub)
echo $SSH_KEY > $ssh_tmpfile

qm set ${VM_ID} --description "Cloud-Image ${IMAGE_NAME}" \
  --scsihw virtio-scsi-pci --scsi0 ${STORAGE_NAME}:vm-${VM_ID}-disk-0 \
  --ide2 ${STORAGE_NAME}:cloudinit \
  --boot c --bootdisk scsi0 \
  --serial0 socket --vga serial0 \
  --ipconfig0 ip=dhcp --onboot 1 --ostype l26 --agent enabled=1 \
  --sshkeys $ssh_tmpfile
#   --cicustom "user=snippets:snippets/user-data.yml" \
#   --ciuser ${STD_USER_NAME} --cipassword ${STD_USER_PASS}

qm resize ${VM_ID} scsi0 "20G"

rm -v $ssh_tmpfile

# No going back after this
# On NFS storage this will fail to `chattr` the FS, when making it immutable
qm template ${VM_ID}
```

## Define and deploy machines in Terraform

Copy `terraform.tfvars.sample` to `terraform.tfvars` and update the values according to the inline comments. The `proxmox_settings` block is where to put the API token and secret values generated earlier, along with the URL for the Proxmox API endpoint.

Plan and apply. In tests, it took ~11m to create a 6 node cluster (3 control + 3 worker) on a Proxmox cluster of 3 physical machines, but of course this varies based on hardware and inter-Proxmox networking.

```sh
terraform plan
terraform apply -auto-approve
```

## Provision the k3s cluster

The Terraform provisioners are particularly flaky on the Proxmox engine. There is an Ansible playbook for spinning up K3s, MetalLB and Kube-VIP to give a single virtual IP for the HA control-plane.

```sh
./scripts/deploy.sh
```

Additional playbooks for resetting the cluster and rebooting are available as well.

```sh
# Reboot all the machines, generally don't do this
./script/reboot.sh

# Reset and wipe the cluster. This will also reboot the machines
ansible-playbook -i "./inventory/my-cluster/hosts.ini" ./site.yml"
```

## Using the k3s cluster

Copy the kube config from a server node so you can access the cluster from your local machine:

```sh
export CONTROL_VIP=$(terraform output -raw control-plane-vip)
export SSH_KEY_PATH=$(terraform output -raw ssh-private-key-path)
export SSH_USERNAME=$(terraform output -raw ssh-user)
scp -i $SSH_KEY_PATH $SSH_USERNAME@$CONTROL_VIP:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Update the downloaded config file to point to the IP of the control plane VIP
sed -i.bak "s/127.0.0.1/${CONTROL_VIP}/" ~/.kube/config
kubectl get nodes -o wide
kubectl get pods --all-namespaces
```

### TBD Get Traefik running again


### Install Rancher

A popular choice on K3s is to deploy the Rancher UI. See: [Quick Start Guide](https://rancher.com/docs/rancher/v2.6/en/quick-start-guide/deployment/quickstart-manual-setup/) for more info.

```sh
# Set a bootstrap admin password
export PASSWORD_FOR_RANCHER_ADMIN="p4nc4K3s"

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest

kubectl create namespace cattle-system

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml

helm repo add jetstack https://charts.jetstack.io

helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.7.1

# Verify it's working by checking the pods
kubectl get pods --namespace cert-manager

helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=$CONTROL0.nip.io \
  --set bootstrapPassword=$PASSWORD_FOR_RANCHER_ADMIN

# Wait for Rancher to be rolled out
kubectl -n cattle-system rollout status deploy/rancher

echo "Open your browser to: https://${CONTROL0}.nip.io for the Rancher UI."

# Take the opportunity to change admin's password or you will be locked out...
# If you end up locked out, you can reset the password using:
kubectl -n cattle-system exec $(kubectl -n cattle-system get pods -l app=rancher | grep '1/1' | head -1 | awk '{ print $1 }') -- reset-password
# Then login using admin/<new-password> and change it in the UI properly.
```

To delete the Rancher UI:

```sh
kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml
helm uninstall rancher --namespace cattle-system
helm uninstall cert-manager --namespace cert-manager
helm repo remove jetstack
helm repo remove rancher-latest
kubectl delete namespace cattle-system
```


## Destroying the cluster

In tests, it took ~2m to destroy a 6 node cluster (3 control + 3 worker), but of course this varies based on hardware and network.

```sh
terraform destroy
```

## Docs

https://registry.terraform.io/providers/Telmate/proxmox/latest/docs
