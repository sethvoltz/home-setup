k3s_version: ${k3s_version}

ansible_user: ${ssh_user}
systemd_dir: /etc/systemd/system

# Set your timezone
system_timezone: "${system_timezone}"

# interface which will be used for flannel
flannel_iface: "eth0"

# apiserver_endpoint is virtual ip-address which will be configured on each master
apiserver_endpoint: "${apiserver_endpoint}"

# k3s_token is required  masters can talk together securely
# this token should be alpha numeric only
k3s_token: "${k3s_token}"

# The IP on which the node is reachable in the cluster.
# Here, a sensible default is provided, you can still override
# it for each of your hosts, though.
k3s_node_ip: '{{ ansible_facts[flannel_iface]["ipv4"]["address"] }}'

# Disable the taint manually by setting: k3s_master_taint = false
k3s_master_taint: "{{ true if groups['node'] | default([]) | length >= 1 else false }}"

# these arguments are recommended for servers as well as agents:
extra_args: >-
  --flannel-iface={{ flannel_iface }}
  --node-ip={{ k3s_node_ip }}

# change these to your liking, the only required are: --disable servicelb, --tls-san {{ apiserver_endpoint }}
extra_server_args: >-
  {{ extra_args }}
  {{ '--node-taint node-role.kubernetes.io/master=true:NoSchedule' if k3s_master_taint else '' }}
  --tls-san {{ apiserver_endpoint }}
  --write-kubeconfig-mode=640
  --disable servicelb
  --disable traefik
extra_agent_args: >-
  {{ extra_args }}

# image tag for kube-vip
kube_vip_tag_version: "v0.5.11"

# metallb type frr or native
metal_lb_type: "native"

# metallb mode layer2 or bgp
metal_lb_mode: "layer2"

# bgp options
# metal_lb_bgp_my_asn: "64513"
# metal_lb_bgp_peer_asn: "64512"
# metal_lb_bgp_peer_address: "192.168.30.1"

# image tag for metal lb
metal_lb_frr_tag_version: "v7.5.1"
metal_lb_speaker_tag_version: "v0.13.9"
metal_lb_controller_tag_version: "v0.13.9"

# metallb ip range for load balancer
metal_lb_ip_range: "${metal_lb_ip_range}"
