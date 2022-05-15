#!/bin/bash

set -e
## The ID of the GCP project to be installed into.
GOOGLE_CLOUD_PROJECT="eternal-empire-349717"
APP_NAME="Samples"

## Environment
ENV_NAME="STG"

## The name of the GCP SA to be used during installation.
SA_DEVOPS_NAME="svc-devops-${ENV_NAME,,}"
SA_DEVOPS_SECRET_FILE="${SA_DEVOPS_NAME}-keyfile.json"

## Storage
#GCS_BUCKET_NAME="${GOOGLE_CLOUD_PROJECT,,}-${APP_NAME,,}-bucket"
GCS_BUCKET_NAME="eternal-empire-349717-jenkins-cicd-bucket"

## GKE Cluster
#GKE_CLUSTER_NAME="${APP_NAME}-CLUSTER-${ENV_NAME}"
GKE_CLUSTER_NAME="jenkins-cluster"
GKE_NUM_NODES=2
GKE_ZONE="us-central1-a"
GKE_MACHINE_TYPE="n1-standard-2"
if [[ "${ENV_NAME}" == "STG" ]]; then
  GKE_CLUSTER_IPV4_CIDR="10.100.0.0/20"
else
  GKE_CLUSTER_IPV4_CIDR="10.110.0.0/20"
fi

function gcloud_auth_login(){
  ## Configure gcloud to target the configured project.
  gcloud auth login
  gcloud config set project $GOOGLE_CLOUD_PROJECT

  kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value account)
}

function enable_apis(){
    gcloud services enable compute.googleapis.com \
    container.googleapis.com \
    cloudbuild.googleapis.com \
    servicemanagement.googleapis.com \
    cloudresourcemanager.googleapis.com \
    --project ${GOOGLE_CLOUD_PROJECT}
}

function create_GCS_bucket(){
  local gcs_bucket_name=$1

  gsutil mb gs://${gcs_bucket_name}
}

function install_jenkins_plugins(){
  echo "Google Kubernetes Engine"
}

function create_kubernetes_cluster(){
    gcloud container clusters create $GKE_CLUSTER_NAME \
     --num-nodes $GKE_NUM_NODES \
     --zone $GKE_ZONE \
     --machine-type $GKE_MACHINE_TYPE \
     --scopes "https://www.googleapis.com/auth/source.read_write,cloud-platform" \
     --cluster-version latest \
     --spot \
     --cluster-ipv4-cidr $GKE_CLUSTER_IPV4_CIDR

    gcloud container clusters list
}

function kubectl_authentication_plugin_installation(){
    #gcloud components install gke-gcloud-auth-plugin
    sudo apt-get -y install google-cloud-sdk-gke-gcloud-auth-plugin
    #gke-gcloud-auth-plugin --version

    export USE_GKE_GCLOUD_AUTH_PLUGIN=True

    #gcloud components update
    sudo apt-get update && sudo apt-get -y --only-upgrade install google-cloud-sdk-anthos-auth google-cloud-sdk-spanner-emulator google-cloud-sdk-pubsub-emulator google-cloud-sdk-terraform-tools kubectl google-cloud-sdk-gke-gcloud-auth-plugin google-cloud-sdk-kpt google-cloud-sdk-cloud-run-proxy google-cloud-sdk-cbt google-cloud-sdk-datalab google-cloud-sdk-cloud-build-local google-cloud-sdk-app-engine-java google-cloud-sdk-nomos google-cloud-sdk-kubectl-oidc google-cloud-sdk-minikube google-cloud-sdk-app-engine-python-extras google-cloud-sdk-datastore-emulator google-cloud-sdk-app-engine-python google-cloud-sdk-local-extract google-cloud-sdk-app-engine-grpc google-cloud-sdk-bigtable-emulator google-cloud-sdk-skaffold google-cloud-sdk google-cloud-sdk-config-connector google-cloud-sdk-firestore-emulator google-cloud-sdk-app-engine-go

    gcloud container clusters get-credentials $GKE_CLUSTER_NAME --zone $GKE_ZONE
}

function get_kubernetes_cluster_credentials(){
    export USE_GKE_GCLOUD_AUTH_PLUGIN=True
    gcloud container clusters get-credentials $GKE_CLUSTER_NAME --zone $GKE_ZONE
}

function create_gke_deployer(){
    gcloud iam roles create gke_deployer --project $GOOGLE_CLOUD_PROJECT --file \
    rbac/IAMrole.yaml

    kubectl create -f rbac/robot-deployer.yaml
}

function create_sa(){
    local service_account=$1
    echo "create_sa '$service_account'"

    SA_EMAIL=$(gcloud iam service-accounts list --filter="name:$service_account" --format='value(email)')
    if [[ -z "$SA_EMAIL" ]]; then
      gcloud iam service-accounts create $service_account
    else
      echo "exited: $SA_EMAIL"
    fi
}

function gke_cluster_rbac_permissions(){
    local service_account=$1

    echo "gke_cluster_rbac_permissions for '$service_account'"

    SA_EMAIL=${service_account}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com

    cat rbac/robot-deployer-bindings.yaml | sed "s/%SA_EMAIL%/$SA_EMAIL/g" | kubectl create -f -
}
 
function config_sa_deployer(){
    local service_account=$1
    SA_EMAIL=${service_account}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com

    gcloud projects add-iam-policy-binding $GOOGLE_CLOUD_PROJECT \
    --member serviceAccount:$SA_EMAIL \
    --role projects/$GOOGLE_CLOUD_PROJECT/roles/gke_deployer
}

function config_sa_roles(){
    local service_account=$1

    echo "config_serviceaccount_permissions for '$service_account'"
    SA_EMAIL=${service_account}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com

    local roles="container.admin container.developer storage.admin storage.objectAdmin containeranalysis.admin compute.instanceAdmin compute.networkAdmin iam.serviceAccountUser"
    for role in $roles; do
      echo "  add 'role/$role'"
      gcloud projects add-iam-policy-binding ${GOOGLE_CLOUD_PROJECT} \
        --member serviceAccount:${SA_EMAIL} \
        --role "roles/$role" \
        --quiet
    done
}

function config_sa_bucket_permissions(){
    local service_account=$1
    gsutil iam ch serviceAccount:${service_account}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com:objectAdmin gs://${GCS_BUCKET_NAME}/
}

function create_sa_kubernetes_secret(){
    local service_account=$1
    local service_account_file=$2

    echo "create_sa_kubernetes_secret '$service_account'"

    gcloud iam service-accounts keys create --iam-account "${service_account}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com" "${service_account_file}"
    kubectl create secret generic "$service_account" --from-file "${service_account_file}"
}

function port_forward(){
  gcloud container clusters get-credentials $GKE_CLUSTER_NAME --zone $GKE_ZONE --project ${GOOGLE_CLOUD_PROJECT}

  # export POD_NAME=$(kubectl get pods -o jsonpath="{.items[0].metadata.name}") && kubectl port-forward $POD_NAME 8081:8080 >> /dev/null &
}

function cleaning_up(){
    local service_account=$1
    local service_account_file=$2

    # Delete the Project
    gcloud projects delete $GOOGLE_CLOUD_PROJECT

    # service_account
    gsutils iam ch -d serviceAccount:${service_account}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com:objectAdmin gs://${GCS_BUCKET_NAME}/
    gcloud iam service-accounts delete "${service_account}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"

    # Kubernetes Cluster
    gcloud container clusters delete $GKE_CLUSTER_NAME --zone $GKE_ZONE

    # Storage Buckets
    gsutil rm -r gs://${GCS_BUCKET_NAME}

    # Google Container Registry Images
    list_samples_digest=$(gcloud container images list-tags gcr.io/${GOOGLE_CLOUD_PROJECT}/jenkins-integration-samples-gke --format="value(digest)")
    for digest in $list_samples_digest; do
      gcloud container images delete gcr.io/${GOOGLE_CLOUD_PROJECT}/jenkins-integration-samples-gke@sha256:$digest
    done
}

function create_firewall(){
    gcloud compute --project=$GOOGLE_CLOUD_PROJECT firewall-rules create instance-$GKE_CLUSTER_NAME \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:8080 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server,https-server
}

#create_gke_deployer
#create_sa $SA_DEVOPS_NAME
#gke_cluster_rbac_permissions $SA_DEVOPS_NAME

#create_sa_deployer $SA_DEVOPS_NAME
#config_sa_roles $SA_DEVOPS_NAME
#config_sa_bucket_permissions $SA_DEVOPS_NAME
#create_sa_kubernetes_secret $SA_DEVOPS_NAME $SA_DEVOPS_SECRET_FILE
#create_firewall
port_forward