apiVersion: v1
kind: Secret
metadata:
  name: quobyte-admin-secret
  namespace: kube-system
type: "kubernetes.io/quobyte"
data:
  password: cXVvYnl0ZQ==
  user: YWRtaW4=
---
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
   name: quobyte
provisioner: kubernetes.io/quobyte
parameters:
    quobyteAPIServer: "http://REPLACE_ME/api"
    registry: "registry:7871"
    adminSecretName: "quobyte-admin-secret"
    adminSecretNamespace: "kube-system"
    user: "root"
    group: "root"
    quobyteConfig: "BASE"
    quobyteTenant: ""
