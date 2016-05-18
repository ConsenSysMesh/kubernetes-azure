# Preparing your parameters file

We will configure our parameters file. This will set up the environment
variables needed for the provisioning files and commands.

All these variables have the prefix `IFR_`.

## Operation

You need to copy the file from `templates/parameters.sample` into
`parameters` in this repository root directory.

```
cp ./templates/parameters.sample ./parameters
```

Modify the variables as needed

## Variable Description

### Azure Variables

```
# The name of your resource group
export IFR_PREFIX="k8s-sample"

# The location of your cluster
export IFR_LOCATION="eastus"

# Storage account name, must be only lowercase letters and numbers
export IFR_STORAGE_ACC_NAME="k8ssample"
```

## Networking

Please review the [document on network topology](network_topology.md)

```
# Virtual Network
export IFR_NETWORK_VNET_CIDR="10.42.0.0/16"

# Kubernetes
export IFR_NETWORK_ETCD_CIDR="10.42.0.0/24"
export IFR_NETWORK_MASTER_CIDR="10.42.1.0/24"
export IFR_NETWORK_WORKER_CIDR="10.42.2.0/24"
# Kubernetes Virtual
export IFR_NETWORK_SERVICES_CIDR="10.42.3.0/24"
export IFR_NETWORK_PODS_CIDR="10.42.4.0/24"

## Private IP Addresses
export IFR_NETWORK_ETCD_PRIV_IP_00="10.42.0.4"
export IFR_NETWORK_MASTER_PRIV_IP_00="10.42.1.4"
export IFR_NETWORK_K8S_SERVICE_IP="10.42.3.1"
export IFR_NETWORK_DNS_SERVICE_IP="10.42.3.10"
export IFR_NETWORK_WORKER_PRIV_IP_00="10.42.2.4"
```

## SSH Public Keys

We need them to access the servers. CoreOS by design does not enable
to authenticate with user/pass.

You can generate your key pairs with `ssh-keygen -t rsa -b 4096`.

```
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export IFR_ETCD_SSH_PUB_FILEPATH=$CURRENT_DIR/secrets/ssh/etcd_rsa.pub
export IFR_MASTER_SSH_PUB_FILEPATH=$CURRENT_DIR/secrets/ssh/master_rsa.pub
export IFR_WORKER_SSH_PUB_FILEPATH=$CURRENT_DIR/secrets/ssh/worker_rsa.pub
```

## Custom Data Files

These files contain specifications to provision the servers. Specific details
on each of them are to be found in the following documents:

* [ETCD](deploying_etcd.md)
* [Master](deploying_master.md)
* [Worker](deploying_workers.md)
* [DNS Addon](deploying_dns_add_on.md)

```
# The location of the etcd, master and worker templates
export IFR_ETCD_TEMPLATE=$CURRENT_DIR/templates/etcd.yaml
export IFR_ETCD_TEMPLATE_RENDERED=$CURRENT_DIR/secrets/templates/etcd.yaml.rendered

export IFR_MASTER_TEMPLATE=$CURRENT_DIR/templates/master.yaml
export IFR_MASTER_TEMPLATE_RENDERED=$CURRENT_DIR/secrets/templates/master.yaml.rendered

export IFR_WORKER_TEMPLATE=$CURRENT_DIR/templates/worker.yaml
export IFR_WORKER_TEMPLATE_RENDERED=$CURRENT_DIR/secrets/templates/worker.yaml.rendered

export IFR_DNS_TEMPLATE=$CURRENT_DIR/templates/dns.yaml
export IFR_DNS_TEMPLATE_RENDERED=$CURRENT_DIR/secrets/templates/dns.yaml.rendered
```

## Configuration for `kubectl`

Finally, these variables will help us to communicate with the kubernetes cluster
via `kubectl`.

```
# Setup kubectl parameters
export IFR_MASTER_FQDN_00=${IFR_PREFIX}-master-00.${IFR_LOCATION}.cloudapp.azure.com
export IFR_CA_CERT=$CURRENT_DIR/secrets/k8s/ca.pem
export IFR_ADMIN_KEY_CERT=$CURRENT_DIR/secrets/k8s/admin-key.pem
export IFR_ADMIN_CERT=$CURRENT_DIR/secrets/k8s/admin.pem
```
