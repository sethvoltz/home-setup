#!/bin/bash

if [[ $HOSTNAME =~ ^kube-control-* ]]
then
    # Server (Control Plane)
    if [[ $HOSTNAME -eq 'kube-control-00' ]]
    then
        echo "==> Initializing k3s cluster installation..." && \
        curl -sfL ${k3s_get_url} | K3S_TOKEN=${k3s_token} sh -s - --write-kubeconfig-mode=644 --cluster-init
    else
        # TODO: Write a loop to check that control-0 is available before proceeding
        echo "==> Installing k3s server and joining to cluster..." && \
        curl -sfL ${k3s_get_url} | K3S_TOKEN=${k3s_token} sh -s - --write-kubeconfig-mode=644 --server=https://${k3s_cluster_join_ip}:6443
    fi

    echo "==> Control install complete. Getting nodes."
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    k3s kubectl get nodes -o wide
else
    # Agent (Worker)
    echo "==> Installing k3s agent and joining to cluster..." && \
    curl -sfL ${k3s_get_url} | K3S_TOKEN=${k3s_token} K3S_URL=https://${k3s_cluster_join_ip}:6443 sh -
    echo "==> Worker install complete."
fi
