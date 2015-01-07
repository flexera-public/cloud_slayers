#!/usr/bin/env bash

set -e

if [ -e /usr/bin/docker ]; then
  cmd="/usr/bin/docker"
elif [ -e /usr/bin/docker.io ]
  cmd="/usr/bin/docker.io"
else
  echo "Docker binary not found"
fi

for port in $PORTS; do
  args="$args -p $port"
done

$cmd run --name=$NAME -d $args $IMAGE:$TAG $COMMAND
