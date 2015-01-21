#!/usr/bin/env bash
#!/usr/bin/env bash
# RightScript Name: Start docker container
# Description: Start a docker container on an already configured server
# Packages: 
# Inputs:
#   IMAGE:
#     Input Type: single
#     Category: Uncategorized
#     Default: none
#     Description: Image name for new container
#     Required: true
#     Advanced: no
#   NAME:
#     Input Type: single
#     Category: Uncategorized
#     Default: none
#     Description: Name to assign to container
#     Required: true
#     Advanced: no
#   PORTS:
#     Input Type: single
#     Category: Uncategorized
#     Default: none
#     Description: Space separated list of ports to be published. 
#       format: ip:hostPort:containerPort | ip::containerPort | 
#       hostPort:containerPort | containerPort
#     Required: no
#     Advanced: no
#   COMMAND:
#     Input Type: single
#     Category: Uncategorized
#     Default: none
#     Description: Command to run in Docker container
#     Required: true
#     Advanced: no
#   TAG:
#     Input Type: single
#     Category: Uncategorized
#     Default: text:latest
#     Description: Image tag for new container
#     Required: true
#     Advanced: no

set -ex

if which docker; then
  cmd=`which docker`
elif which docker.io; then
  cmd=`which docker.io`
else
  echo "Docker binary not found"
  exit 1
fi

for port in $PORTS; do
  args="$args -p $port"
done

$cmd run --name=$NAME -d $args $IMAGE:$TAG $COMMAND
