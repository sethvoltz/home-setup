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
./bin/build-vm-template
```

## Define and deploy machines in Terraform

Copy `physical/terraform.tfvars.sample` to `physical/terraform.tfvars` and update the values according to the inline comments. The `proxmox_settings` block is where to put the API token and secret values generated earlier, along with the URL for the Proxmox API endpoint.

Plan and apply. In tests, it took ~11m to create a 6 node cluster (3 control + 3 worker) on a Proxmox cluster of 3 physical machines, but of course this varies based on hardware and inter-Proxmox networking.

```sh
./bin/physical deploy
```

## Provision the k3s cluster

The Terraform provisioners are particularly flaky on the Proxmox engine. There is an Ansible playbook for spinning up K3s, MetalLB and Kube-VIP to give a single virtual IP for the HA control-plane.

```sh
./bin/cluster deploy
```

Additional commands in the `cluster` command, via playbooks, are `reset` and `reboot`.

## Using the k3s cluster

Copy the kubectl config from a server node so you can access the cluster from your local machine:

```sh
./bin/get-kubeconfig
kubectl config use-context config-k3s
kubectl get nodes -o wide
kubectl get pods --all-namespaces
```

## Provision the kubernetes services

In order for Terraform to properly request an access key for cert-manager, we also need a properly permissioned user called `k8s` for it to hang off of.

- Go to AWS > IAM > Policies
- Create a new Polocy called `lets-encrypt-access-policy` with the following permissions
  ```
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "VisualEditor0",
              "Effect": "Allow",
              "Action": [
                  "route53:GetChange",
                  "route53:ChangeResourceRecordSets",
                  "route53:ListResourceRecordSets"
              ],
              "Resource": [
                  "arn:aws:route53:::hostedzone/*",
                  "arn:aws:route53:::change/*"
              ]
          },
          {
              "Sid": "VisualEditor1",
              "Effect": "Allow",
              "Action": [
                  "route53:ListHostedZones",
                  "route53:ListHostedZonesByName"
              ],
              "Resource": "*"
          }
      ]
  }
  ```
- Go to AWS > IAM > Users
- Create a new user called `k8s` and assign it the policy created above

Once the AWS user is available, the remainder of the provisioning is a single command:

```sh
./bin/services deploy
```

## Destroying the cluster

In tests, it took ~2m to destroy a 6 node cluster (3 control + 3 worker), but of course this varies based on hardware and network.

```sh
./bin/physical reset
```

## Docs

https://registry.terraform.io/providers/Telmate/proxmox/latest/docs
