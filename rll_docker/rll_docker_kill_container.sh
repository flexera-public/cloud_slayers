#!/usr/bin/env bash
# RightScript Name: Start docker container
# Description: Start a docker container on an already configured server
# Packages: puppet
# Inputs:
#   CONTAINER:
#     Input Type: single
#     Category: Uncategorized
#     Default: none
#     Description: The name of the docker container to kill
#     Required: true
#     Advanced: true

set -ex

if [ -e /usr/bin/docker ]; then
  cmd="/usr/bin/docker"
elif [ -e /usr/bin/docker.io ]
  cmd="/usr/bin/docker.io"
else
  echo "Docker binary not found"
  exit 1
fi

$cmd kill $CONTAINER || echo "$CONTAINER is not running" && exit 1
$cmd rm $CONTAINER
