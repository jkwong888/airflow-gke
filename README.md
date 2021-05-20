# airflow-gke-autopilot

just playing around with airflow on gke autopilot


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

airflow_external_url = "airflow.gcp.jkwong.info"
airflow_namespace = "default"
airflow_dags_git_repo = "https://github.com/jkwong888/airflow-dags.git"
```

Create this file in the `terraform` directory, and run the following commands.  the running user should be a project owner on the service project, and you probably need to pre-create the subnet and grant permission to use it (the terraform attempts to add the roles but not everyone has such permissions over two projects).)

```
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

This creates a GKE Autopilot cluster called `airflow-central1` on the subnet `airflow-central1` in `us-central1`, on the shared vpc `shared-network`.  
We create also a small Cloud SQL and a small Redis Memorystore, and generate the helm [values](./airflow-helm) files for installation into the cluster.

We also created an Google service account as output by the terraform under `airflow_service_account` - add roles/permissions to this if you need to access any GCP APIs from DAGs, you can use them without creating (ugh) airflow connections.  E.g. if you want to give access to DAGs to read/write to/from storage buckets or BQ datasets.

Before we continue with helm installation, we created a Cloud Source Repository and Cloud Build Trigger to build a custom worker image in the project in GCR called `airflow-worker`.  This is already rigged in the helm chart so Airflow won't start unless the image exists.  I have an example git repo of a worker image at [https://github.com/jkwong888/airflow-worker-image](https://github.com/jkwong888/airflow-worker-image).  You can mirror this into the cloud source repo using the instructions you find in them empty source repo, which looks like this:

```
git clone https://github.com/jkwong888/airflow-worker-image
cd airflow-worker-image
git remote add google ssh://<username>@source.developers.google.com:2022/p/<service_project_id>/r/airflow-worker-repo
git push --all google
```

This should trigger the cloud build to build and push the worker image into GCR.  You can manage what appears in this image by editing the dockerfile and adding more python requirements and committing the repo, which should trigger Cloud Build to rebuild it.

Review the generated values file in [airflow-helm](./airflow-helm), then install airflow
```
helm repo add airflow-stable https://airflow-helm.github.io/charts
helm install airflow airflow-stable/airflow -f airflow-helm/airflow-values.yaml --version 8.1.1
```

This installs Airflow into the cluster with KubernetesExecutor.  The scheduler is rigged to watch a git repo full of DAGs, in my example I have a really stupid DAG at [https://github.com/jkwong888/airflow-dags](https://github.com/jkwong888/airflow-dags).  Once the DAG is enabled, each DAG task spins up in a pod in GKE Autopilot and goes away when the tasks is finished.  

The web ui exposed by the cluster will try to create a certificate over TLS, but you need to create an A record in DNS that maps the `airflow_external_url` to the IP that terraform spits out for `airflow_ip`.  Once you do this, and the DNS validation succeeds, you can connect to airflow using the name in `airflow_external_url` with sweet encryption.  In the meantime you can hit the IP on port 80 to get an unencrypted connection to the airflow web UI.

Use `admin`/`admin` to login.

There's still some crap in here to clean up, will do it later:
- there's no authentication beyond the `admin` user - add support for IAP in the BackendConfig (some manual steps to get the oauth clientid)
- git ssh keys and http keys for git sync are not parametrized - it uses public github to sync dags for now.  This process is pretty straightforward, just annoying to parametrize into terraform variables.

