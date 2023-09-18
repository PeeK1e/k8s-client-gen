#!/bin/bash

set -ueo pipefail

function check_depends() {
  which base64  1>/dev/null
  which cat     1>/dev/null
  which tr      1>/dev/null
  which kubectl 1>/dev/null
  which openssl 1>/dev/null
  which yq      1>/dev/null
}

check_depends

K=$(which kubectl)
OPENSSL=$(which openssl)
YQ=$(which yq)
KUBECONFIG=${KUBECONFIG:-"$HOME/.kube/config"}

KUBE_API="$(cat $KUBECONFIG| $YQ '.clusters[0].cluster.server')"
KUBE_CRT="$(cat $KUBECONFIG | yq '.clusters[0].cluster.certificate-authority-data')"

KUBE_USER=${NAME:-"myclient"}

echo $NAME
echo $KUBE_USER

mkdir -p "$(pwd)/keys"

$OPENSSL genpkey -algorithm RSA -out "$(pwd)/keys/my-user.key"
$OPENSSL req -new -key "$(pwd)/keys/my-user.key" -out "$(pwd)/keys/my-user.csr" -subj "/CN=${KUBE_USER}/O=${KUBE_USER}"

CLIENT_CSR_BASE64=$(base64 -w 0 < "$(pwd)/keys/my-user.csr")
cat<<EOF > "$(pwd)/keys/csr.yaml"
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: "$USER"
spec:
  request: "$CLIENT_CSR_BASE64" 
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF

$K apply -f "$(pwd)/keys/csr.yaml"
$K certificate approve "$USER" 

$K get csr "$USER" -o jsonpath='{.status.certificate}' | base64 --decode > "$(pwd)/keys/my-signed-user.crt"

echo "$KUBE_CRT" > "$(pwd)/keys/server.crt"

CLIENT_CERT_BASE64=$(base64 -w 0 < "$(pwd)/keys/my-signed-user.crt")
CLIENT_KEY_BASE64=$(base64 -w 0 < "$(pwd)/keys/my-user.key")
CA_CERT_BASE64=$KUBE_CRT

cat <<EOF > "$(pwd)/kubeconfig.yaml"
apiVersion: v1
kind: Config
current-context: my-cluster
preferences: {}
clusters:
- cluster:
    certificate-authority-data: ${CA_CERT_BASE64}
    server: "$KUBE_API"
  name: my-cluster
contexts:
- context:
    cluster: my-cluster
    user: my-user
  name: my-cluster
users:
- name: my-user
  user:
    client-certificate-data: ${CLIENT_CERT_BASE64}
    client-key-data: ${CLIENT_KEY_BASE64}
EOF
