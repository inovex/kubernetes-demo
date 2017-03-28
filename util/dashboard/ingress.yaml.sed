kind: Ingress
apiVersion: extensions/v1beta1
metadata:
  name: kubernetes-dashboard-ingress
  namespace: kube-system
  annotations:
    ingress.kubernetes.io/auth-type: basic
    ingress.kubernetes.io/auth-secret: basic-auth
    ingress.kubernetes.io/auth-realm: "Authentication Required - inovex Demo"
spec:
  rules:
  - host: REPLACE_ME
    http:
      paths:
      - path: /
        backend:
          serviceName: kubernetes-dashboard
          servicePort: 80
