#!/bin/bash

################################################################################
#
# Script to deploy the base kubernetes system on azure
#
# Requirements:
#
# * Set the variables at `parameters.sh`
# * Have your TLS assets in the `secret` directory
# * You need kubectl installed in your system
# * Login into azure
#
################################################################################

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $CURRENT_DIR/hack/deploy-functions.sh

# GENERAL
set_azure_resource_manager
create_resource_group
create_vnet
create_storage_account

# ETCD
## Network
create_subnet "${IFR_PREFIX}-etcd-sn" "${IFR_NETWORK_ETCD_CIDR}"
create_network_security_group "${IFR_PREFIX}-etcd-nsg"
link_subnet_to_nsg "${IFR_PREFIX}-etcd-sn" "${IFR_PREFIX}-etcd-nsg"

## Machine
create_nic "${IFR_PREFIX}-etcd-nic-00" "${IFR_PREFIX}-etcd-sn" \
   "${IFR_NETWORK_ETCD_PRIV_IP_00}"
render_etcd_template
create_vm "${IFR_PREFIX}-etcd-vm-00" "${IFR_PREFIX}-etcd-sn" \
    "${IFR_PREFIX}-etcd-00" "${IFR_PREFIX}-etcd-nic-00" \
    "${IFR_ETCD_SSH_PUB_FILEPATH}" "${IFR_ETCD_TEMPLATE_RENDERED}" \
    "Standard_A0"

# MASTER
## Network
create_subnet "${IFR_PREFIX}-master-sn" "${IFR_NETWORK_MASTER_CIDR}"
create_network_security_group "${IFR_PREFIX}-master-nsg"
add_inbound_rule_to_nsg "${IFR_PREFIX}-ssh-master-rule" "${IFR_PREFIX}-master-nsg" "100" "22"
add_inbound_rule_to_nsg "${IFR_PREFIX}-https-master-rule" "${IFR_PREFIX}-master-nsg" "200" "443"
link_subnet_to_nsg "${IFR_PREFIX}-master-sn" "${IFR_PREFIX}-master-nsg"

## Machine
create_public_ip "${IFR_PREFIX}-master-pip-00" "${IFR_PREFIX}-master-00"
create_nic "${IFR_PREFIX}-master-nic-00" "${IFR_PREFIX}-master-sn" \
   "${IFR_NETWORK_MASTER_PRIV_IP_00}" "${IFR_PREFIX}-master-pip-00"
render_master_template
create_vm "${IFR_PREFIX}-master-vm-00" "${IFR_PREFIX}-master-sn" \
    "${IFR_PREFIX}-master-00" "${IFR_PREFIX}-master-nic-00" \
    "${IFR_MASTER_SSH_PUB_FILEPATH}" "${IFR_MASTER_TEMPLATE_RENDERED}" \
    "Standard_A0"

# KUBECTL
## kubectl setup
kubectl config set-cluster default-cluster \
   --server=https://${IFR_MASTER_FQDN_00} \
   --certificate-authority=${IFR_CA_CERT}
kubectl config set-credentials default-admin \
  --certificate-authority=${IFR_CA_CERT} \
  --client-key=${IFR_ADMIN_KEY_CERT} \
  --client-certificate=${IFR_ADMIN_CERT}
kubectl config set-context default-system \
  --cluster=default-cluster \
  --user=default-admin
kubectl config use-context default-system

## Wait for master's kubernetes to be ready...
until kubectl get nodes 2>/dev/null; do printf '.'; sleep 5; done

## Label master
kubectl label nodes ${IFR_NETWORK_MASTER_PRIV_IP_00} role=master

## Create kube-system namespace in kubernetes
NAMESPACE=`eval "kubectl get namespaces | grep kube-system | cat"`
if [ ! "$NAMESPACE" ]; then
    kubectl create -f  $CURRENT_DIR/templates/kube-system-namespace.yaml
fi

## Deploy DNS Add on
sed -e "s/\${IFR_NETWORK_DNS_SERVICE_IP}/${IFR_NETWORK_DNS_SERVICE_IP}/g" < ${IFR_DNS_TEMPLATE} > ${IFR_DNS_TEMPLATE_RENDERED}
kubectl create -f ${IFR_DNS_TEMPLATE_RENDERED}

# WORKERS
## Network
create_subnet "${IFR_PREFIX}-worker-sn" "${IFR_NETWORK_WORKER_CIDR}"
create_network_security_group "${IFR_PREFIX}-worker-nsg"
link_subnet_to_nsg "${IFR_PREFIX}-worker-sn" "${IFR_PREFIX}-worker-nsg"

## Machine
create_nic "${IFR_PREFIX}-worker-nic-00" "${IFR_PREFIX}-worker-sn" \
    "${IFR_NETWORK_WORKER_PRIV_IP_00}"
render_worker_template
create_vm "${IFR_PREFIX}-worker-vm-00" "${IFR_PREFIX}-worker-sn" \
    "${IFR_PREFIX}-worker-00" "${IFR_PREFIX}-worker-nic-00" \
    "${IFR_WORKER_SSH_PUB_FILEPATH}" "${IFR_WORKER_TEMPLATE_RENDERED}" \
    "Standard_A1"
