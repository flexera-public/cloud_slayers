#!/usr/bin/env bash
# RightScript Name: Start docker container
# Description: Start a docker container on an already configured server
# Packages: puppet
# Inputs:
#   IMAGE:
#     Input Type: single
#     Category: Uncategorized
#     Default: none
#     Description: Image name for new container
#     Required: true
#     Advanced: true
#   NAME:
#     Input Type: single
#     Category: Uncategorized
#     Default: none
#     Description: Name to assign to container
#     Required: true
#     Advanced: true
#   PORTS:
#     Input Type: single
#     Category: Uncategorized
#     Default: none
#     Description: Space separated list of ports to be published. 
#       format: ip:hostPort:containerPort | ip::containerPort | 
#       hostPort:containerPort | containerPort
#     Required: true
#     Advanced: true
#   COMMAND:
#     Input Type: single
#     Category: Uncategorized
#     Default: none
#     Description: Command to run in Docker container
#     Required: true
#     Advanced: true
#   TAG:
#     Input Type: single
#     Category: Uncategorized
#     Default: text:latest
#     Description: Image tag for new container
#     Required: true
#     Advanced: true

set -ex

if [ -e /usr/bin/docker ]; then
  cmd="/usr/bin/docker"
elif [ -e /usr/bin/docker.io ]; then
  cmd="/usr/bin/docker.io"
else
  echo "Docker binary not found"
  exit 1
fi

for port in $PORTS; do
  args="$args -p $port"
done

$cmd run --name=$NAME -d $args $IMAGE:$TAG $COMMAND
