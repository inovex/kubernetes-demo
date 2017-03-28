apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: quobyte
  namespace: quobyte
spec:
  rules:
  - host: REPLACE_ME
    http:
      paths:
      - path: /api
        backend:
          serviceName: api
          servicePort: 80
      - path: /
        backend:
          serviceName: webconsole
          servicePort: 80
