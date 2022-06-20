#!/bin/bash

docker build -t gcr.io/eternal-empire-349717/builder:latest .
docker push gcr.io/eternal-empire-349717/builder:latest

RUN apt update
RUN apt install docker.io -y