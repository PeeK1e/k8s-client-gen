## TL;DR

You will need an already functioning kubeconfig whith permissions to approve `CSRs`

Run `NAME=jason bash gen-client-conf.sh` to generate a kubeconfig and certificate signed for the user and group `jason`

There is a `Role` and `RoleBinding` for an read only User in the `rbac.yaml`

## Dependencies

```sh
openssl
kubectl
yq      # go-yq
base64
cat
tr
```

## The Script

This is a simple bash script creating a user certificate via a certificate signing request.

To set the username set the `NAME` environment variable.

Run the script to generate a certificate and kubeconfig.

The config will be output to `$(pwd)/kubeconfig.yaml`

