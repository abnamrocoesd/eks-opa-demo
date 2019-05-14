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
$ openssl genrsa -out ca.key 2048
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

### Create the webhook configuration

```
$ cat > webhook-configuration.yaml <<EOF
kind: ValidatingWebhookConfiguration
apiVersion: admissionregistration.k8s.io/v1beta1
metadata:
  name: opa-validating-webhook
  namespace: opa
  labels:
    app: opa
webhooks:
  - name: validating-webhook.openpolicyagent.org
    rules:
      - operations: ["CREATE", "UPDATE"]
        apiGroups: ["*"]
        apiVersions: ["*"]
        resources:
          - pods
          - services
          - replicasets
          - deployments
          - daemonsets
          - cronjobs
          - jobs
          - ingresses
          - roles
          - statefulsets
          - podtemplates
          - configmaps
          - secrets
    clientConfig:
      caBundle: $(cat ca.crt | base64 | tr -d '\n')
      service:
        namespace: opa
        name: opa
    namespaceSelector:
      matchExpressions:
      - {key: opa-webhook, operator: NotIn, values: [ignore]}
EOF
```

### Create the OPA namespace

```
$ kubectl create namespace opa
$ kubectl config set-context --namespace opa --current
```

### Create the secret

```
$ kubectl create secret tls opa-server --cert=server.crt --key=server.key
```

### Deploy the admission controller

```
$ kubectl apply -f admission-controller.yaml
```

Wait until the resources become ready. You can use `kubectl get all` for checking the status.

### Deploy the webhook configuration

```
$ kubectl apply -f webhook-configuration.yaml
```

### Deploy the ConfigMaps  containing your OPA policies in Rego

```
$ kubectl create configmap image-source --from-file=policies/image-source.rego
$ kubectl create configmap ingress-sg --from-file=policies/ingress-sg.rego
```

### Check OPA configuration

```
$ kubectl get configmap image-source -o jsonpath="{.metadata.annotations}"
map[openpolicyagent.org/policy-status:{"status":"ok"}]
$ kubectl get configmap ingress-sg -o jsonpath="{.metadata.annotations}"
map[openpolicyagent.org/policy-status:{"status":"ok"}]
```

## Test Policies / Interesting Stuff

```
$ kubectl apply -f nginx.yaml
Error from server (pod "nginx" has invalid registry "nginx"): error when creating "nginx.yaml": admission webhook "validating-webhook.openpolicyagent.org" denied the request: pod "nginx" has invalid registry "nginx"
$ kubectl apply  -f ingress.yaml
Error from server (Compliance check failed: CISO-01: Application Load Balancers must use 'internal' scheme): error when creating "ingress.yaml": admission webhook "validating-webhook.openpolicyagent.org" denied the request: Compliance check failed: CISO-01: Application Load Balancers must use 'internal' scheme
```

## Clean Up

```
$ kubectl delete namespace opa
$ eksctl delete cluster -f cluster.yaml --profile <aws profile>
```
