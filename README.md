# eks-opa-demo

See also: https://aws.amazon.com/blogs/opensource/using-open-policy-agent-on-amazon-eks/

## Prerequisites
- eksctl – http://eksctl.io
- kubectl - https://kubernetes.io/docs/tasks/tools/install-kubectl/
- AWS credentials configured

## Create an EKS cluster

```
$ eksctl create cluster -f cluster.yaml --profile <aws profile>
```

This will probably take around 15 minutes.

## Create Resources

### Create a CA

```
$ penssl genrsa -out ca.key 2048
$ openssl req -x509 -new -nodes -key ca.key -days 100000 -out ca.crt -subj "/CN=admission_ca"
```

### Create TLS key and certificate for OPA

```
$ cat >server.conf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
EOF
$ openssl genrsa -out server.key 2048
$ openssl req -new -key server.key -out server.csr -subj "/CN=opa.opa.svc" -config server.conf
$ openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 100000 -extensions v3_req -extfile server.conf
```

## Deploy Resources

```
$ kubectl create namespace opa
$ kubectl config set-context --namespace opa --current
$ kubectl create secret tls opa-server --cert=server.crt --key=server.key
$ kubectl apply -f admission-controller.yaml
$ kubectl apply -f webhook-configuration.yaml
$ kubectl create configmap image-source --from-file=image_source.rego
```

Check OPA configuration

```
$ kubectl get configmap image-source -o jsonpath="{.metadata.annotations}"
map[openpolicyagent.org/policy-status (http://openpolicyagent.org/policy-status):{"status":"ok"}]
```

## Test Policy

```
$ kubectl apply -f nginx.yaml
Error from server (pod "nginx" has invalid registry "nginx"): error when creating "nginx.yaml": admission webhook "validating-webhook.openpolicyagent.org" denied the request: pod "nginx" has invalid registry "nginx"
```

## Clean Up

```
$ kubectl delete namespace opa
$ eksctl delete cluster -f cluster.yaml --profile <aws profile>
```
