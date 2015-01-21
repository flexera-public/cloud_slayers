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

$cmd kill $CONTAINER || echo "$CONTAINER is not running"
$cmd rm $CONTAINER
