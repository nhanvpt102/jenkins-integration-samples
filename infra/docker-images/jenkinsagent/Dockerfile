FROM jenkins/inbound-agent

USER root
RUN apt-get update && apt-get install -y apt-transport-https gnupg gnupg2 gnupg1
RUN apt-get update && apt-get install -y curl
RUN curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list
RUN apt-get update && apt-get install -y kubectl
USER jenkins