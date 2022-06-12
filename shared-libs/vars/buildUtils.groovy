#!/usr/bin/env groovy

def call() {
  stage("Build") {
      agent {
          kubernetes {
            cloud 'kubernetes'
            label 'maven-pod'
            yamlFile 'gke/jenkins/maven-pod.yaml'
          }
      }
      environment {
          PROJECT_ZONE = "${JENK_INT_IT_ZONE}"
          PROJECT_ID = "${JENK_INT_IT_PROJECT_ID}"
          STAGING_CLUSTER = "${JENK_INT_IT_STAGING}"
          PROD_CLUSTER = "${JENK_INT_IT_PROD}"
          BUILD_CONTEXT_BUCKET = "${JENK_INT_IT_BUCKET}"
          BUILD_CONTEXT = "build-context-${BUILD_ID}.tar.gz"
          APP_NAME = "jenkins-integration-samples-gke"
          GCR_IMAGE = "gcr.io/${PROJECT_ID}/${APP_NAME}:${BUILD_ID}"
          APP_JAR = "${APP_NAME}.jar"

          JENKINSAGENT = "jenkinsagent"
          JENKINSAGENT_IMAGE = "gcr.io/${PROJECT_ID}/${JENKINSAGENT}:latest"
          JENKINSAGENT_JAR = "${JENKINSAGENT}.jar"
      }

      steps {
          script {
              log.info 'Starting'
              log.warning 'Nothing to do!'
              checkout([$class: 'GitSCM', branches: [[name: '*/devops-world-eu']], extensions: [[$class: 'CleanBeforeCheckout', deleteUntrackedNestedRepositories: true]], userRemoteConfigs: [[credentialsId: 'github-ssh-key', url: 'git@github.com:nhanvpt102/jenkins-integration-samples.git']]])
          }

          container('maven') {
              dir("gke") {
                // build
                  sh "mvn clean package"

                // run tests
                  sh "mvn verify"

                // bundle the generated artifact    
                  sh "cp target/${APP_NAME}-*.jar $APP_JAR"

                // archive the build context for kaniko
                  sh "tar --exclude='./.git' -zcvf /tmp/$BUILD_CONTEXT ."
                  sh "mv /tmp/$BUILD_CONTEXT ."
                  step([$class: 'ClassicUploadStep', credentialsId: env.JENK_INT_IT_CRED_ID, bucket: "gs://${BUILD_CONTEXT_BUCKET}", pattern: env.BUILD_CONTEXT])
             }
         }
      }
  }
}