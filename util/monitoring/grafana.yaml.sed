apiVersion: v1
kind: Secret
metadata:
  name: grafana-login
  namespace: monitoring
type: Opaque
data:
  password: UEFTU1dPUkQ=
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      name: grafana
      labels:
        app: grafana
    spec:
      volumes:
        - name: data-volume
          persistentVolumeClaim:
            claimName: grafana-data-pvc
      containers:
      - name: grafana
        image: grafana/grafana:4.1.1
        env:
          - name: GF_SECURITY_ADMIN_PASSWORD
            valueFrom:
              secretKeyRef:
                name: grafana-login
                key: password
          - name: GF_AUTH_ANONYMOUS_ENABLED
            value: "false"
          - name: GF_USERS_ALLOW_SIGN_UP
            value: "false"
          - name: GF_SERVER_ROOT_URL
            value: "http://REPLACE_ME"
        volumeMounts:
          - mountPath: /var/lib/grafana
            name: data-volume
        ports:
          - name: web
            containerPort: 3000
---
apiVersion: batch/v1
kind: Job
metadata:
  name: grafana-init
  namespace: monitoring
spec:
  template:
    metadata:
      name: grafana-init
    spec:
      restartPolicy: Never
      volumes:
      - name: grafana-config
        configMap:
          name: grafana-config
      - name: dashboards
        configMap:
          name: dashboards
      containers:
      - name: grafana-init
        image: ubuntu:16.04
        env:
          - name: PASSWORD
            valueFrom:
              secretKeyRef:
                name: grafana-login
                key: password
        command:
          - /bin/bash
          - -xec
          - |
            apt-get -qq update && apt-get -qq install -y curl
            while [[ -z $(curl -sI http://admin:${PASSWORD}@grafana) ]]; do
              sleep 5
            done
            curl -vX POST http://admin:${PASSWORD}@grafana/api/datasources -d @/tmp/grafana-config/grafana-source.json --header "Content-Type: application/json"
            sleep 2

            for f in /tmp/dashboards/*; do curl -vX POST http://admin:PASSWORD@grafana/api/dashboards/db -d @$f --header "Content-Type: application/json"; sleep 1; done
        volumeMounts:
          - name: grafana-config
            mountPath: /tmp/grafana-config/
          - name: dashboards
            mountPath: /tmp/dashboards
---
apiVersion: v1
kind: Service
metadata:
  labels:
    name: grafana
  name: grafana
  namespace: monitoring
spec:
  selector:
    app: grafana
  ports:
  - name: grafana
    protocol: TCP
    port: 80
    targetPort: 3000
