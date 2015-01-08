#!/usr/bin/env bash

set -ex

if [ -e /usr/bin/docker ]; then
  cmd="/usr/bin/docker"
elif [ -e /usr/bin/docker.io ]
  cmd="/usr/bin/docker.io"
else
  echo "Docker binary not found"
  exit 1
fi

#CONTAINER is the name of the docker container to kill
$cmd kill $CONTAINER || echo "$CONTAINER is not running" && exit 1
$cmd rm $CONTAINER
