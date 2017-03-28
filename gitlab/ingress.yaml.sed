apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: gitlab
  namespace: gitlab
spec:
  rules:
  - host: REPLACE_ME
    http:
      paths:
      - path: /
        backend:
          serviceName: gitlab
          servicePort: 80
