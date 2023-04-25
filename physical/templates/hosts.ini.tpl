[master]
%{ for instance in control_plane ~}
${instance.default_ipv4_address} ansible_ssh_private_key_file=${ssh_private_key_path}
%{ endfor ~}

[node]
%{ for instance in worker ~}
${instance.default_ipv4_address} ansible_ssh_private_key_file=${ssh_private_key_path}
%{ endfor ~}

[k3s_cluster:children]
master
node
