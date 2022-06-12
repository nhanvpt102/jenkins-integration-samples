#!/usr/bin/env groovy

def call() {
  def mavenPod = libraryResource('gke/jenkins/maven-pod.yaml');
  return mavenPod;
}