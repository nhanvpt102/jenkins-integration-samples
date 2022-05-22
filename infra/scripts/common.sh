#!/bin/bash

set -e
## The ID of the GCP project to be installed into.
GOOGLE_CLOUD_PROJECT="eternal-empire-349717"
APP_NAME="Samples"
DOMAIN_NAME="ninja-uat.tk"
ADDRESS_NAME="ninjamart-fe-pub-ip"

## Environment
ENV_NAME="STG"

## The name of the GCP SA to be used during installation.
SA_DEVOPS_NAME="svc-devops-${ENV_NAME,,}"
SA_DEVOPS_SECRET_FILE="/tmp/${SA_DEVOPS_NAME}-keyfile.json"

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

function docker_login(){
  gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin https://gcr.io
}

function enable_apis(){
    gcloud services enable compute.googleapis.com \
    container.googleapis.com \
    cloudbuild.googleapis.com \
    servicemanagement.googleapis.com \
    cloudresourcemanager.googleapis.com \
    --project ${GOOGLE_CLOUD_PROJECT}

    gcloud services enable container.googleapis.com containerregistry.googleapis.com --project ${GOOGLE_CLOUD_PROJECT}
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
    --enable-autorepair \
    --enable-autoupgrade \
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
    POD_NAME=$(kubectl get pods -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward $POD_NAME 8081:8080 >> /dev/null &
}

function gke_cluster_config_services(){
    local service_name=$1
    cat k8s/services/$service_name.yaml|kubectl apply -f -
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


function install_jhipster(){
    if [[ ! -d "java-microservices-examples/jhipster-k8s/gateway" ]]; then
      echo "clone java-microservices-examples.git"
      git clone https://github.com/oktadeveloper/java-microservices-examples.git
    fi
    pushd java-microservices-examples/reactive-jhipster

    npm i -g generator-jhipster@7

    mkdir k8s
    cd k8s
    jhipster k8s
    
    #To generate the missing Docker image(s), please run:
    cd /home/nhanvo/GCP/java-microservices-examples/jhipster-k8s/gateway
    ./gradlew bootJar -Pprod jibDockerBuild


    GOOGLE_CLOUD_PROJECT=eternal-empire-349717
    # You will need to push your image to a registry. If you have not done so, use the following commands to tag and push the images:
    docker image tag gateway gcr.io/$GOOGLE_CLOUD_PROJECT/gateway
    docker push gcr.io/$GOOGLE_CLOUD_PROJECT/gateway

    #you can use Jib to build and push image directly to a remote registry:
    ./gradlew bootJar -Pprod jib -Djib.to.image=gcr.io/$GOOGLE_CLOUD_PROJECT/gateway

    #You can deploy all your apps by running the following kubectl command:
    bash kubectl-apply.sh -f

    #If you want to use kustomize configuration, then run the following command:
    #bash kubectl-apply.sh -k

    #Use these commands to find your application's IP addresses:
    #kubectl get svc gateway -n infra
    
    popd
}

function build_api_gateway(){
    pushd java-microservices-examples/jhipster-k8s/gateway
        echo "  Build jhipster-k8s/gateway"
        ./gradlew bootJar -Pprod jibDockerBuild

        #echo "  push gcr.io/$GOOGLE_CLOUD_PROJECT/gateway"
        #docker image tag gateway gcr.io/$GOOGLE_CLOUD_PROJECT/gateway
        #docker push gcr.io/$GOOGLE_CLOUD_PROJECT/gateway

        echo "  use Jib to build and push image directly to a remote registry"
        ./gradlew bootJar -Pprod jib -Djib.to.image=gcr.io/$GOOGLE_CLOUD_PROJECT/gateway

    popd
}

function build_docker_image(){
    local folder=$1
    local docker_image=$2

    echo "  Copy ./docker-images/ninjamart-fe/Dockerfile . $folder/"
    cp ../docker-images/ninjamart-fe/Dockerfile $folder -f

    pushd "$folder"

        echo "  Build $docker_image"
        docker build . -f Dockerfile -t gcr.io/$GOOGLE_CLOUD_PROJECT/$docker_image
        #docker image tag $docker_image gcr.io/$GOOGLE_CLOUD_PROJECT/$docker_image
        docker push gcr.io/$GOOGLE_CLOUD_PROJECT/$docker_image
    popd
}

function get_docker_register(){
    local service_account=$1
	local service_account_file=$2
		
    SA_EMAIL=${service_account}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com
	gcloud auth activate-service-account $SA_EMAIL --key-file="${service_account_file}"
	gcloud auth configure-docker
	#~/.docker/config.json
}

function create_addresses(){
    local address_name=$1
		
    gcloud compute addresses create $address_name --global
	  gcloud compute addresses describe $address_name --global
}

function create_managed_certificate(){
    local domain_name=$1
	
    local template_file="../gke/cert/managed-cert-template.yaml"
	  local managed_cert_file="/tmp/managed-cert.yaml"
	
	  sed "s/%DOMAIN_NAME1%/${domain_name}/g" $template_file > $managed_cert_file
	  cat $managed_cert_file
	  kubectl apply -f $managed_cert_file
  
  
  gcloud compute ssl-certificates create "managed-cert" \
    --description="managed-cert" \
    --domains="ninja-uat.tk" \
    --global
    
    gcloud compute ssl-certificates describe "managed-cert" \
   --global \
   --format="get(name,managed.status, managed.domainStatus)"
   
   gcloud compute target-https-proxies update TARGET_PROXY_NAME \
    --ssl-certificates SSL_CERTIFICATE_LIST \
    --global-ssl-certificates \
    --global
}

function apply_kubectl_service(){
  local service_name=$1
	local namespace_name=$2
	
  local template_file="../gke/services/${service_name}-template.yaml"
	local service_file="/tmp/${service_name}-service.yaml"
	
	sed "s/%SERVICE_NAME%/${service_name}/g" $template_file > $service_file
	sed "s/%NAMESPACE_NAME%/${namespace_name}/g" -i $service_file
	cat $service_file
	kubectl apply -f $service_file
}

function apply_kubectl_ingress(){
  local service_name=$1
	local namespace_name=$2
	local address_name=$3
  local domain_name=$4
    
  local template_file="../gke/ingress/${service_name}-template.yaml"
	local service_file="/tmp/${service_name}-ingress.yaml"
	
	sed "s/%SERVICE_NAME%/${service_name}/g" $template_file > $service_file
	sed "s/%NAMESPACE_NAME%/${namespace_name}/g" -i $service_file
	sed "s/%ADDRESS_NAME%/${address_name}/g" -i $service_file
  sed "s/%DOMAIN_NAME%/${domain_name}/g" -i $service_file
	cat $service_file
	kubectl apply -f $service_file
	
	#kubectl describe managedcertificate managed-cert
	# may wait for 60 min
}

function check_ingress(){
  local domain_name=$1
  
	# may wait for 60 min
  gcloud compute ssl-certificates list
	kubectl describe managedcertificate managed-cert
  curl -v https://${domain_name}
}

function create_cert(){
  local cert_name=$1
  local domain_name=$2
      
    openssl genrsa -out $cert_name.key 2048
    openssl req -new -key $cert_name.key -out $cert_name.csr -subj "/CN=${domain_name}"
    
    openssl x509 -req -days 365 -in $cert_name.csr -signkey $cert_name.key -out $cert_name.crt
}
function create_cert_secret(){
  local cert_name=$1
  local namespace_name=$2
  
    kubectl create secret tls $cert_name \
      --cert $cert_name.crt \
      --key $cert_name.key \
      -n $namespace_name
    
    gcloud compute ssl-certificates create $cert_name \
      --certificate $cert_name.crt \
      --private-key $cert_name.key
}

#kubectl_authentication_plugin_installation
#docker_login
#get_kubernetes_cluster_credentials

#create_gke_deployer
#create_sa $SA_DEVOPS_NAME
#gke_cluster_rbac_permissions $SA_DEVOPS_NAME

#create_sa_deployer $SA_DEVOPS_NAME
#config_sa_roles $SA_DEVOPS_NAME
#config_sa_bucket_permissions $SA_DEVOPS_NAME
#create_sa_kubernetes_secret $SA_DEVOPS_NAME $SA_DEVOPS_SECRET_FILE
#create_firewall
#port_forward
#gke_cluster_config_services frontend

#uild_api_gateway

#build_docker_image "/home/nhanvo/sdb1/GCP/repo/NJV/ninjamart-fe" "ninjamart-fe"

#get_docker_register $SA_DEVOPS_NAME $SA_DEVOPS_SECRET_FILE

#create_addresses $ADDRESS_NAME

#create_managed_certificate "${DOMAIN_NAME}"


#echo -n 'admin' | base64
#echo -n 'admin123' | base64

#apply_kubectl_service "ninjamart-fe" "uat"
#apply_kubectl_ingress "ninjamart-fe" "uat" "$ADDRESS_NAME" "${DOMAIN_NAME}"

# create_cert "ninjamart-fe" "${DOMAIN_NAME}"
# create_cert_secret "ninjamart-fe" "uat"
check_ingress "34.102.149.137" 