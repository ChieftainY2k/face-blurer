#!/bin/bash
# shellcheck disable=SC2086

set -e

SOURCE=${1:-"input/video1.mp4"}
docker run --gpus all -v $(pwd):/data linuxserver/ffmpeg -i "/data/$SOURCE" -fps_mode passthrough -q:v 0 -c:v png "/data/input/frame_%10d.png"