#!/usr/bin/env bash

set -e

if [ -e /usr/bin/docker ]; then
  cmd="/usr/bin/docker"
elif [ -e /usr/bin/docker.io ]
  cmd="/usr/bin/docker.io"
else
  echo "Docker binary not found"
fi

$cmd kill $CONTAINER || echo "$CONTAINER is not running"
$cmd rm $CONTAINER
