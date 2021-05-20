#
# NOTE:
# - This is intended to be a `custom-values.yaml` starting point for production deployment in a GKE cluster
# - We are using GKE Workload Identity rather than storing Service Account JSON tokens:
#    https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
# - Airflow requires that `explicit_defaults_for_timestamp=1` in your CloudSQL MySQL instance

# External Dependencies:
# - Git repo for DAGs:      ssh://git@repo.example.com/my-airflow-dags.git
# - CloudSQL (MySQL):       mysql.example.com:3306
# - Cloud Storage Bucket:   gs://XXXXXXXX--airflow-cluster1/
# - SMTP server:            smtpmail.example.com
# - DNS A Record:           airflow-cluster1.example.com --> XXX.XXX.XXX.XXX
# - Google Service Account: airflow-cluster1@MY_PROJECT_ID.iam.gserviceaccount.com
#
# Google IAM:
# - (Storage Bucket)
#    - gs://XXXXXXXX--airflow-cluster1
#      - roles/storage.objectAdmin        --> serviceAccount:airflow-cluster1@$MY_PROJECT_NAME.iam.gserviceaccount.com
#      - roles/storage.legacyBucketReader --> serviceAccount:airflow-cluster1@$MY_PROJECT_NAME.iam.gserviceaccount.com
# - (Service Account)
#    - airflow-cluster1@MY_PROJECT_ID.iam.gserviceaccount.com
#      - roles/iam.workloadIdentityUser   --> MY_PROJECT_NAME.svc.id.goog[airflow-cluster1/airflow]
#
# Kubernetes Resources: (see: ./examples/google-gke/k8s_resources/)
# - Namespace: airflow-cluster1
# - Secret: airflow-cluster1-fernet-key
# - Secret: airflow-cluster1-mysql-password
# - Secret: airflow-cluster1-redis-password
# - Secret: airflow-cluster1-git-keys
# - ConfigMap: airflow-cluster1-webserver-config
# - cert-manager.io/Certificate: airflow-cluster1-cert
#
# Helm Install Commands:
#   helm install stable/airflow \
#     --version "X.X.X" \
#     --name "airflow-cluster1" \
#     --namespace "airflow-cluster1" \
#     --values ./custom-values.yaml
#
# Run bash commands in the Scheduler Pod: (use to: `airflow create_user`)
#   kubectl exec \
#     -it \
#     --namespace airflow-cluster1 \
#     --container airflow-scheduler \
#     Deployment/airflow--airflow-cluster1-scheduler \
#     /bin/bash
#

###################################
# Airflow - Common Configs
###################################
airflow:
  ## the airflow executor type to use
  ##
  executor: KubernetesExecutor

  image:
    repository: ${airflow_image_repo}
    tag: latest

  ## environment variables for the web/scheduler/worker Pods (for airflow configs)
  ##
  config:
      ## Security
      AIRFLOW__CORE__SECURE_MODE: "True"
      AIRFLOW__API__AUTH_BACKEND: "airflow.api.auth.backend.deny_all"
      AIRFLOW__WEBSERVER__EXPOSE_CONFIG: "False"
      AIRFLOW__WEBSERVER__RBAC: "True"

      ## SSL
      ## NOTE: This effectively disables HTTP, so `web.readinessProbe.scheme` and `web.livenessProbe.scheme`
      ##       need to be set accordingly
      #AIRFLOW__WEBSERVER__WEB_SERVER_SSL_CERT: "/var/airflow/secrets/airflow-cluster1-cert/tls.crt"
      #AIRFLOW__WEBSERVER__WEB_SERVER_SSL_KEY: "/var/airflow/secrets/airflow-cluster1-cert/tls.key"

      ## DAGS
      AIRFLOW__SCHEDULER__DAG_DIR_LIST_INTERVAL: "30"

      ## GCP Remote Logging
      AIRFLOW__CORE__REMOTE_LOGGING: "True"
      AIRFLOW__CORE__REMOTE_BASE_LOG_FOLDER: "gs://${airflow_gcs_bucket}/airflow/logs"
      AIRFLOW__CORE__REMOTE_LOG_CONN_ID: "google_cloud_airflow"

      ## Email (SMTP)
      AIRFLOW__EMAIL__EMAIL_BACKEND: "airflow.utils.email.send_email_smtp"
      AIRFLOW__SMTP__SMTP_HOST: "smtpmail.example.com"
      AIRFLOW__SMTP__SMTP_STARTTLS: "False"
      AIRFLOW__SMTP__SMTP_SSL: "False"
      AIRFLOW__SMTP__SMTP_PORT: "25"
      AIRFLOW__SMTP__SMTP_MAIL_FROM: "admin@airflow-cluster1.example.com"

      ## Disable noisy "Handling signal: ttou" Gunicorn log messages
      GUNICORN_CMD_ARGS: "--log-level WARNING"

  ## extra environment variables for the web/scheduler/worker (AND flower) Pods
  ##
  extraEnv:
    - name: AIRFLOW__CORE__FERNET_KEY
      valueFrom:
        secretKeyRef:
          name: airflow-cluster1-fernet-key
          key: value

  ## extra configMap volumeMounts for the web/scheduler/worker Pods
  ##
  extraConfigmapMounts:
    - name: airflow-cluster1-webserver-config
      mountPath: /opt/airflow/webserver_config.py
      configMap: airflow-cluster1-webserver-config
      readOnly: true
      subPath: webserver_config.py

###################################
# Airflow - Scheduler Configs
###################################
scheduler:
  ## resource requests/limits for the scheduler Pod
  ##
  resources:
    requests:
      cpu: "1000m"
      memory: "1Gi"

  ## custom airflow connections for the airflow scheduler
  ##
  connections:
    - id: google_cloud_airflow
      type: google_cloud_platform
      extra: '{"extra__google_cloud_platform__num_retries": "5"}'

  ## custom airflow variables for the airflow scheduler
  ##
  variables: |
    { "environment": "prod" }

  ## custom airflow pools for the airflow scheduler
  ##
  pools: |
    {
      "example": {
        "description": "This is an example pool with 2 slots.",
        "slots": 2
      }
    }

###################################
# Airflow - WebUI Configs
###################################
web:
  ## resource requests/limits for the airflow web Pods
  ##
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"

  ## the number of web Pods to run
  ##
  replicas: 1

  ## configs for the Service of the web Pods
  ##
  service:
    annotations:
      cloud.google.com/neg: '{"ingress": true}' 
    type: ClusterIP
    externalPort: 80
    loadBalancerIP: ${airflow_external_ip}
    loadBalancerSourceRanges: []

  ## sets `AIRFLOW__WEBSERVER__BASE_URL`
  ##
  baseUrl: "https://${airflow_external_url}/"

  ## extra pip packages to install in the web container
  ##
  extraPipPackages: []

  ## configs for the web Service liveness probe
  ##
  livenessProbe:
    ## the scheme used in the liveness probe: {HTTP,HTTPS}
    ##
    scheme: HTTP

    ## the number of seconds to wait before checking pod health
    ##
    ## NOTE:
    ## - make larger if you are installing many packages with:
    ##   `airflow.extraPipPackages`, `web.extraPipPackages`, or `dags.installRequirements`
    ##
    initialDelaySeconds: 300
  
  readinessProbe:
    scheme: HTTP

  ## the directory in which to mount secrets on web containers
  ##
  secretsDir: /var/airflow/secrets

  ## secret names which will be mounted as a file at `{web.secretsDir}/<secret_name>`
  ##
  secrets:
    - airflow-cluster1-cert

###################################
# Airflow - Worker Configs
###################################
workers:
  ## if the airflow workers StatefulSet should be deployed
  ##
  enabled: false

  ## resource requests/limits for the airflow worker Pods
  ##
  resources:
    requests:
      cpu: "1000m"
      memory: "2Gi"

  ## the number of workers Pods to run
  ##
  replicas: 2

  ## configs for the PodDisruptionBudget of the worker StatefulSet
  ##
  podDisruptionBudget:
    ## if a PodDisruptionBudget resource is created for the worker StatefulSet
    ##
    enabled: true

    ## the maximum unavailable pods/percentage for the worker StatefulSet
    ##
    ## NOTE:
    ## - prevents loosing more than 20% of current worker task slots in a voluntary
    ##   disruption
    ##
    maxUnavailable: "20%"

  ## configs for the HorizontalPodAutoscaler of the worker Pods
  ##
  autoscaling:
    enabled: true
    maxReplicas: 8
    metrics:
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80

  ## configs for the celery worker Pods
  ##
  celery:
    ## the number of tasks each celery worker can run at a time
    ##
    ## NOTE:
    ## - sets AIRFLOW__CELERY__WORKER_CONCURRENCY
    ##
    instances: 10

    ## if we should wait for tasks to finish before SIGTERM of the celery worker
    ##
    gracefullTermination: true

    ## how many seconds to wait for tasks to finish before SIGTERM of the celery worker
    ##
    ## WARNING:
    ## - GKE cluster-autoscaler will not respect graceful termination period over 10min
    ## NOTE:
    ## - this gives any running tasks AT MOST 9min to complete
    ##
    gracefullTerminationPeriod: 540

  ## how many seconds to wait after SIGTERM before SIGKILL of the celery worker
  ##
  terminationPeriod: 60

  ## directory in which to mount secrets on worker containers
  ##
  secretsDir: /var/airflow/secrets

  ## secret names which will be mounted as a file at `{workers.secretsDir}/<secret_name>`
  ##
  secrets: []

###################################
# Airflow - Flower Configs
###################################
flower:
  ## if the Flower UI should be deployed
  ##
  enabled: false

  ## resource requests/limits for the flower Pods
  ##
  resources:
    requests:
      cpu: "100m"
      memory: "126Mi"

  ## configs for the Service of the flower Pods
  ##
  service:
    annotations: {}
    type: ClusterIP
    externalPort: 5555
    loadBalancerIP: ""
    loadBalancerSourceRanges: []

###################################
# Airflow - Logs Configs
###################################
logs:
  ## configs for the logs PVC
  ##
  persistence:
    ## if a persistent volume is mounted at `logs.path`
    ##
    enabled: false

###################################
# Airflow - DAGs Configs
###################################
dags:
  ## configs for the DAG git repository & sync container
  ##
  gitSync:
    ## enable the git-sync sidecar container
    ##
    enabled: true

    ## the git sync interval in seconds
    ##
    syncWait: 60

    ## url of the git repository
    ##
    repo: "${airflow_dags_git_repo}"

    ## the branch/tag/sha1 which we clone
    ##
    branch: main

    ## the name of a pre-created secret containing files for ~/.ssh/
    ##
    ## NOTE:
    ## - this is ONLY RELEVANT for SSH git repos
    ## - the secret commonly includes files: id_rsa, id_rsa.pub, known_hosts
    ## - known_hosts is NOT NEEDED if `git.sshKeyscan` is true
    ##
    sshSecret: airflow-cluster1-git-keys

    ## the name of the private key file in your `git.secret`
    ##
    ## NOTE:
    ## - this is ONLY RELEVANT for PRIVATE SSH git repos
    ##
    sshSecretKey: id_rsa

    sshKnownHosts: ""


###################################
# Kubernetes - RBAC
###################################
rbac:
  ## if Kubernetes RBAC resources are created
  ##
  create: true

###################################
# Kubernetes - Service Account
###################################
serviceAccount:
  ## if a Kubernetes ServiceAccount is created
  ##
  create: true

  ## the name of the ServiceAccount
  ##
  name: "airflow"

  ## annotations for the ServiceAccount
  ##
  annotations:
    iam.gke.io/gcp-service-account: ${airflow_sa}

###################################
# Database - PostgreSQL Chart
###################################
postgresql:
  ## if the `stable/postgresql` chart is used
  ##
  enabled: false

###################################
# Database - External Database
###################################
externalDatabase:
  ## the type of external database: {mysql,postgres}
  ##
  type: mysql

  ## the host of the external database
  ##
  host: ${airflow_db_ip}

  ## the port of the external database
  ##
  port: 3306

  ## the database/scheme to use within the the external database
  ## TODO
  database: ${airflow_db_name}

  ## the user of the external database
  ## TODO
  user: ${airflow_db_username}

  ## the name of a pre-created secret containing the external database password
  ## TODO
  passwordSecret: airflow-cluster1-mysql-password

  ## the key within `externalDatabase.passwordSecret` containing the password string
  ##
  passwordSecretKey: mysql-password

###################################
# Database - Redis Chart
###################################
redis:
  ## if the `stable/redis` chart is used
  ##
  enabled: false

  ## the name of a pre-created secret containing the redis password
  ##
  existingSecret: "airflow-cluster1-redis-password"

  ## the key in `redis.existingSecret` containing the password string
  ##
  existingSecretPasswordKey: "redis-password"

  ## configs for redis cluster mode
  ##
  cluster:
    ## if redis runs in cluster mode
    ##
    enabled: false

    ## the number of redis slaves
    ##
    slaveCount: 1

  ## configs for the redis master
  ##
  master:
    ## resource requests/limits for the master Pod
    ##
    resources:
      requests:
        cpu: "100m"
        memory: "256Mi"

    ## configs for the PVC of the redis master
    ##
    persistence:
      ## use a PVC to persist data
      ##
      enabled: false

  ## configs for the redis slaves
  ##
  slave:
    ## resource requests/limits for the slave Pods
    ##
    resources:
      requests:
        cpu: "100m"
        memory: "256Mi"

    ## configs for the PVC of the redis slaves
    ##
    persistence:
      ## use a PVC to persist data
      ##
      enabled: false

externalRedis:
  host: ${redis_host}
  port: ${redis_port}
  databaseNumber: 1


ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.global-static-ip-name: "${static_ip_name}"
    networking.gke.io/managed-certificates: "airflow-cert"

extraManifests:
- apiVersion: v1
  kind: ConfigMap
  metadata:
    name: airflow-cluster1-webserver-config
  data:
    webserver_config.py: |
      import os
      from airflow.configuration import conf
      from flask_appbuilder.security.manager import AUTH_DB

      basedir = os.path.abspath(os.path.dirname(__file__))

      # The SQLAlchemy connection string.
      SQLALCHEMY_DATABASE_URI = conf.get("core", "SQL_ALCHEMY_CONN")

      # Flask-WTF flag for CSRF
      CSRF_ENABLED = True

      # Force users to re-auth after 15min of inactivity
      PERMANENT_SESSION_LIFETIME = 900

      # Don't allow user self registration
      AUTH_USER_REGISTRATION = False
      AUTH_USER_REGISTRATION_ROLE = "Viewer"

      # Use Database authentication
      AUTH_TYPE = AUTH_DB 
- apiVersion: v1
  kind: Secret
  metadata:
    name: airflow-cluster1-fernet-key
  stringData:
    value: "${airflow_fernet_key}"
- apiVersion: v1
  kind: Secret
  metadata:
    name: airflow-cluster1-mysql-password
  stringData:
    mysql-password: "${mysql_password}"
- apiVersion: v1
  kind: Secret
  metadata:
    name: airflow-cluster1-git-keys
  stringData:
    git_key: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      -----END OPENSSH PRIVATE KEY-----
    git_key.pub: |
      ssh-rsa XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX airflow-cluster1@gke-cluster
    known_hosts: |
      repo.example.com, ssh-rsa XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
- apiVersion: networking.gke.io/v1
  kind: ManagedCertificate
  metadata:
    name: airflow-cert
  spec:
    domains:
      - ${airflow_external_url}