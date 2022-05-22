#!/bin/bash

# sudo visudo
# $USER ALL=(ALL) NOPASSWD: ALL
# nhanvo ALL=(ALL) NOPASSWD: ALL
# Where is your username on your system. Save and close the sudoers file

#sudo nano /etc/rc.local
#  #!/bin/sh
#  sudo -i -u nhanvo /home/nhanvo/myagent/run.sh
#sudo chmod a+x /etc/rc.local

sudo apt update
sudo apt install net-tools -y
sudo apt install jq -y
sudo apt install openssh-server -y

sudo ifconfig

# Install dotnet sdk 3.1
wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

sudo apt-get update; \
  sudo apt-get install -y apt-transport-https && \
  sudo apt-get update && \
  sudo apt-get install -y dotnet-sdk-3.1

sudo apt-get install -y dotnet-runtime-3.1

# Install Az Cli
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install unix2dos
sudo apt-get install -y dos2unix

# Install jsonlint
sudo apt-get install -y jsonlint python3-demjson

# Install xmllint
sudo apt install -y libxml2-utils

# Install git
sudo add-apt-repository ppa:git-core/ppa
sudo apt list --upgradable
sudo apt update
sudo apt install git -y

git config --global init.defaultBranch master
git config --global advice.detachedHead false

# Install zip
sudo apt install -y zip unzip

# Install cifs utils
sudo apt install -y cifs-utils 

#Gcloud
sudo apt-get install curl apt-transport-https ca-certificates gnupg -y 
echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-get update && sudo apt-get install google-cloud-cli

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

sudo apt install -y npm
npm install yarn

sudo apt update
curl -sL https://deb.nodesource.com/setup_14.x | sudo bash -
cat /etc/apt/sources.list.d/nodesource.list
sudo apt -y install nodejs
node  -v
sudo apt -y install gcc g++ make
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update && sudo apt install yarn
yarn -V

sudo apt install docker.io
sudo usermod -a -G docker nhanvo

sudo apt-get -y install google-cloud-sdk-gke-gcloud-auth-plugin
#gke-gcloud-auth-plugin --version

export USE_GKE_GCLOUD_AUTH_PLUGIN=True

#gcloud components update
sudo apt-get update && sudo apt-get -y --only-upgrade install google-cloud-sdk-anthos-auth google-cloud-sdk-spanner-emulator google-cloud-sdk-pubsub-emulator google-cloud-sdk-terraform-tools kubectl google-cloud-sdk-gke-gcloud-auth-plugin google-cloud-sdk-kpt google-cloud-sdk-cloud-run-proxy google-cloud-sdk-cbt google-cloud-sdk-datalab google-cloud-sdk-cloud-build-local google-cloud-sdk-app-engine-java google-cloud-sdk-nomos google-cloud-sdk-kubectl-oidc google-cloud-sdk-minikube google-cloud-sdk-app-engine-python-extras google-cloud-sdk-datastore-emulator google-cloud-sdk-app-engine-python google-cloud-sdk-local-extract google-cloud-sdk-app-engine-grpc google-cloud-sdk-bigtable-emulator google-cloud-sdk-skaffold google-cloud-sdk google-cloud-sdk-config-connector google-cloud-sdk-firestore-emulator google-cloud-sdk-app-engine-go

npm install -g generator-jhipster
yarn global add generator-jhipster

sudo apt-get update && sudo apt-get install openjdk-8-jdk && java -version
sudo update-alternatives --set java /usr/lib/jvm/jdk1.8.0_version/bin/java && java -version