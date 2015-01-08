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

for port in $PORTS; do
  args="$args -p $port"
done

#IMAGE & TAG are used to identify the docker image to launch
#Run COMMAND on the new container
$cmd run --name=$NAME -d $args $IMAGE:$TAG $COMMAND
