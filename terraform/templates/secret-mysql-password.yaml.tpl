apiVersion: v1
kind: Secret
metadata:
  name: airflow-cluster1-mysql-password
  namespace: airflow
stringData:
  mysql-password: "${password}"