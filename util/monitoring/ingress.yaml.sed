apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: monitoring
  namespace: monitoring
spec:
  rules:
  - host: REPLACE_ME
    http:
      paths:
      - path: /
        backend:
          serviceName: grafana
          servicePort: 80
