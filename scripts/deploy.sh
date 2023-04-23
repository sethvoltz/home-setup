#!/bin/bash

basepath=$(realpath $(dirname $0)/..)
ansible-playbook -i "${basepath}/inventory/my-cluster/hosts.ini" "${basepath}/site.yml"
