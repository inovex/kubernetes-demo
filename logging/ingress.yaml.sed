apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: kube-system
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
          serviceName: kibana-logging
          servicePort: 80
