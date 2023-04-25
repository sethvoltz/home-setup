# Seth Kubernetes Setup

Useful for labbing at home, this repository provides a quick and easy way to deploy a [K3s](https://k3s.io/) cluster on an existing [Proxmox VE](https://www.proxmox.com/en/proxmox-ve) hypervisor using [Terraform](https://www.terraform.io/) and [Ansible](https://www.ansible.com/).

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
./scripts/build-vm-template
```

## Define and deploy machines in Terraform

Copy `physical/terraform.tfvars.sample` to `physical/terraform.tfvars` and update the values according to the inline comments. The `proxmox_settings` block is where to put the API token and secret values generated earlier, along with the URL for the Proxmox API endpoint.

Plan and apply. In tests, it took ~11m to create a 6 node cluster (3 control + 3 worker) on a Proxmox cluster of 3 physical machines, but of course this varies based on hardware and inter-Proxmox networking.

```sh
./scripts/physical deploy
```

## Provision the k3s cluster

The Terraform provisioners are particularly flaky on the Proxmox engine. There is an Ansible playbook for spinning up K3s, MetalLB and Kube-VIP to give a single virtual IP for the HA control-plane.

```sh
./scripts/cluster deploy
```

Additional commands in the `cluster` command, via playbooks, are `reset` and `reboot`.

## Using the k3s cluster

Copy the kubectl config from a server node so you can access the cluster from your local machine:

```sh
./scripts/get-kubeconfig
kubectl get nodes -o wide
kubectl get pods --all-namespaces
```

### Cert-Manager

```sh
# First apply the CRDs
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.1/cert-manager.crds.yaml

helm repo add jetstack https://charts.jetstack.io

helm repo update

# Then install
kubectl create namespace cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --values=./kubernetes/cert-manager/values.yaml \
  --version v1.11.1

# Verify it's working by checking the pods
kubectl get pods --namespace cert-manager

# Copy and edit the Secret and ClusterIssuer files with your credentials
cp kubernetes/cert-manager/issuers/secret-{{TYPE}}-token.yaml{.example,}
cp kubernetes/cert-manager/issuers/letsencrypt-production.yaml{.example,}

# Apply them
kubectl apply -f kubernetes/cert-manager/issuers/secret-{{TYPE}}-token.yaml
kubectl apply -f kubernetes/cert-manager/issuers/letsencrypt-production.yaml

# Create a wildcard Certificate file, fill out with your needs
cp kubernetes/cert-manager/certificates/production/{local-example-com,your-domain-here}.yaml

# Apply
kubectl apply -f kubernetes/cert-manager/certificates/production/your-domain-here.yaml

# Get active challenges
kubectl get challenges

# Once challenges are done, you can check the certs
kubectl describe cert your-domain-here --namespace default
```

### Install Traefik

```sh
helm repo add traefik https://helm.traefik.io/traefik

helm repo update

kubectl create namespace traefik

# Copy and edit the domain info for Traefik, then request it
cp kubernetes/cert-manager/certificates/production/traefik-{local-example-com,your-domain-here}.yaml
kubectl apply -f kubernetes/cert-manager/certificates/production/traefik-{{your-domain-here}}.yaml

# Then install
helm install traefik traefik/traefik \
  --namespace=traefik \
  --values=./kubernetes/traefik/values.yaml

# Verify install
kubectl get svc --all-namespaces -o wide
kubectl get pods --namespace traefik

# Apply middleware
kubectl apply -f ./kubernetes/traefik/default-headers.yaml

# Get htpassword value for BASIC auth
htpasswd -nb {{username}} {{password}} | openssl base64

# Copy and edit the secret and ingress
cp kubernetes/traefik/dashboard/secret-dashboard.yaml{.example,}
cp kubernetes/traefik/dashboard/ingress.yaml{.example,}

# Apply
kubectl apply -f ./kubernetes/traefik/dashboard/secret-dashboard.yaml
kubectl apply -f ./kubernetes/traefik/dashboard/middleware.yaml
kubectl apply -f ./kubernetes/traefik/dashboard/ingress.yaml

# Check it out: https://traefik.{{your-domain-here}}
```

### Install Rancher

A popular choice on K3s is to deploy the Rancher UI. See: [Quick Start Guide](https://rancher.com/docs/rancher/v2.6/en/quick-start-guide/deployment/quickstart-manual-setup/) for more info.

```sh
# Set a bootstrap admin password
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest

kubectl create namespace cattle-system

# Copy and edit the domain
cp kubernetes/rancher/values.yaml{.example,}

# Install it
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --values=./kubernetes/rancher/values.yaml

# Wait for Rancher to be rolled out
kubectl -n cattle-system rollout status deploy/rancher

# Take the opportunity to change admin's password or you will be locked out...
# If you end up locked out, you can reset the password using:
kubectl -n cattle-system exec $(kubectl -n cattle-system get pods -l app=rancher | grep '1/1' | head -1 | awk '{ print $1 }') -- reset-password
# Then login using admin/<new-password> and change it in the UI properly.
```

To delete the Rancher UI:

First, download the latest release of Rancher `system-tools`, e.g. `system-tools_darwin-amd64`

```sh
./system-tools_darwin-amd64 remove --kubeconfig ~/.kube/config --namespace cattle-system
```


## Destroying the cluster

In tests, it took ~2m to destroy a 6 node cluster (3 control + 3 worker), but of course this varies based on hardware and network.

```sh
./scripts/physical reset
```

## Docs

https://registry.terraform.io/providers/Telmate/proxmox/latest/docs
