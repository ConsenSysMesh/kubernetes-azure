# Preparing SSL Assets

In this tutorial we will assume that we are self signing our certificates.

You will find that `/hack/generate-tls-assets.sh` will make your assets and
put it into the `/secrets/k8s` directory.

## Generate TLS assets script

`/hack/generate-tls-assets.sh`

```
#!/bin/bash

###############################################################################
#
# Generate TLS Assets
#
# Usage:
#
# source ./parameters.sh
# ./hack/generate-tls-assets.sh
#
# Will output in secrets your TLS assets
#
###############################################################################

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SECRETS_DIR=$CURRENT_DIR/../secrets/k8s

openssl genrsa -out $SECRETS_DIR/ca-key.pem 2048
openssl req -x509 -new -nodes -key $SECRETS_DIR/ca-key.pem -days 10000 -out $SECRETS_DIR/ca.pem -subj "/CN=kube-ca"

sed -e "s/\${IFR_MASTER_FQDN_00}/${IFR_MASTER_FQDN_00}/" < $PWD/hack/openssl.cnf.template > $SECRETS_DIR/openssl.cnf
sed -i "s/\${IFR_NETWORK_K8S_SERVICE_IP}/${IFR_NETWORK_K8S_SERVICE_IP}/" $SECRETS_DIR/openssl.cnf
sed -i "s/\${IFR_NETWORK_MASTER_PRIV_IP_00}/${IFR_NETWORK_MASTER_PRIV_IP_00}/" $SECRETS_DIR/openssl.cnf

openssl genrsa -out $SECRETS_DIR/apiserver-key.pem 2048
openssl req -new -key $SECRETS_DIR/apiserver-key.pem -out $SECRETS_DIR/apiserver.csr -subj "/CN=kube-apiserver" -config $SECRETS_DIR/openssl.cnf
openssl x509 -req -in $SECRETS_DIR/apiserver.csr -CA $SECRETS_DIR/ca.pem -CAkey $SECRETS_DIR/ca-key.pem -CAcreateserial -out $SECRETS_DIR/apiserver.pem -days 365 -extensions v3_req -extfile $SECRETS_DIR/openssl.cnf

openssl genrsa -out $SECRETS_DIR/worker-key.pem 2048
openssl req -new -key $SECRETS_DIR/worker-key.pem -out $SECRETS_DIR/worker.csr -subj "/CN=kube-worker"
openssl x509 -req -in $SECRETS_DIR/worker.csr -CA $SECRETS_DIR/ca.pem -CAkey $SECRETS_DIR/ca-key.pem -CAcreateserial -out $SECRETS_DIR/worker.pem -days 365

openssl genrsa -out $SECRETS_DIR/admin-key.pem 2048
openssl req -new -key $SECRETS_DIR/admin-key.pem -out $SECRETS_DIR/admin.csr -subj "/CN=kube-admin"
openssl x509 -req -in $SECRETS_DIR/admin.csr -CA $SECRETS_DIR/ca.pem -CAkey $SECRETS_DIR/ca-key.pem -CAcreateserial -out $SECRETS_DIR/admin.pem -days 365

# Cleanup
rm $SECRETS_DIR/*.csr
rm $SECRETS_DIR/openssl.cnf
```

Let's discuss what this script does:

* As the usage inside specifies, you need to `source` the file `/parameters.sh`.
We have already done so, if we followed the instructions at the document
[Preparing the parameters file](parameters_file.md).

* The script will set the variables `CURRENT_DIR` and `SECRETS_DIR`.

* After that, The certificate authority `ca.pem` is generated.

* There are three replacements made to the file `openssl.cnf.template`, the new
file is put in the `/secrets` directory. And deleted at the end of the script.

  * We need to set the master FQDN, to enable the apiserver to take calls
  from the internet. In certain way, is good to operate with an FQDN rather
  than the public IP. As the latter could be changed in the future for a number
  of reasons.

  * We replace the next two variables, related to the Kubernetes Service
  (an overlay network IP) and the master's private IP, which we entirely control.

* The rest of the script are calls to `openssl` using the certificate authority,
to finish with a directory cleanup.

## Execution of the script

```
source ./parameters
./hack/generate-tls-assets.sh
```

## Quick testing

Let's check the contents of `apiserver.pem`.

```
openssl x509 -in ./secrets/k8s/apiserver.pem -noout -text | grep DNS
```

Should give us back which HTTP invocations we are accepting

```
DNS:kubernetes, DNS:kubernetes.default, DNS:k8s-master-00.eastus.cloudapp.azure.com, IP Address:10.103.3.1, IP Address:10.103.1.4
```

Be aware that _you_ are the one that chooses the FQDN of master, so
`k8s-master-00...` is an example.

Is important to stress, that most of the problems (found by this post's author)
you will find trying to access your kubernetes cluster are related to
misconfigurations happening at the certificate level. For example, the _devops_
will want to access its cluster, using the master's IP, and this wasn't
registered in the certificates, being the access denied on SSL terms.

## Backup your assets!

Please, after generating them, make sure you keep them safe somewhere. Failing
to find them later will mean that you need to access your nodes via SSH and
reinstall them manually.
