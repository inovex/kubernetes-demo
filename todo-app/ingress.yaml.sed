apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: todo-app
  namespace: todo-app
spec:
  rules:
  - host: REPLACE_ME
    http:
      paths:
      - path: /
        backend:
          serviceName: todo-app
          servicePort: 80
