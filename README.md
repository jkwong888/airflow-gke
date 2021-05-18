# airflow-gke

just playing around with airflow on gke


First run the terraform, here's my sample terraform.tfvars file:

```
shared_vpc_host_project_id = "shared-vpc-host-project"
shared_vpc_network = "shared-network"

service_project_id = "airflow-project"
registry_project_id = "my-gcr-project"

create_gke = true
gke_cluster_master_range = "10.33.2.0/28"
gke_cluster_name = "airflow-central1"

subnet_name = "airflow-central1"
subnet_region = "us-central1"
subnet_primary_range = "10.33.0.0/24"

subnet_secondary_range = {
    pods = "10.34.0.0/16"
    services = "10.33.1.0/24"
}

airflow_dags_git_repo = "https://github.com/jkwong888/airflow-dags.git"
```

This creates a GKE Autopilot cluster called `airflow-central1` on the subnet `airflow-central1` in `us-central1`, on the shared vpc `shared-network`.  We create also a small Cloud SQL and a small Redis Memorystore, and generate some [manifests](./manifests) and [values](./airflow-helm) files.

We also created an SA called airflow_sa - add permissions to this if you need to access any GCP APIs, you can use them without creating (ugh) airflow connections.


Review and apply the manifests 

```bash
kubectl apply -f manifests/
```

Then install airflow

```
helm repo add airflow-stable https://airflow-helm.github.io/charts
helm install airflow airflow-stable/airflow -f airflow-helm/airflow-values.yaml --namespace airflow --version 8.1.1
```

This installs Airflow with KubernetesExecutor.  Each DAG tasks spins up in a pod in GKE Autopilot.  Use `admin`/`admin` to login.

There's still some crap in here to clean up, will do it later.
- get rid of extra GKE SA (don't need this for autopilot)
- there's no authentication beyond the `admin` user - add support for IAP in the BackendConfig (some manual steps to get the oauth clientid)
- there's no TLS, the app is served over plain HTTP - add the TLS cert and DNS entry
- how to build custom worker images and set DAG tasks to execute there.
- git ssh keys and http keys for git sync are not parametrized - it uses public github for now

