#!/bin/bash
set -e

SOURCE=${1:-"input/video1.mp4"}
#docker run --gpus all -v $(pwd):/data linuxserver/ffmpeg -i "/data/$SOURCE" -fps_mode passthrough -q:v 0 -c:v png "/data/input/frame_%10d.png"
ffmpeg -i "$SOURCE" -q:v 0 -c:v png "input/frame_%10d.png"

# get number of frames
#ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 ./input/video-input-krakow-guide-1080p-30fps-1min.mp4

# set starting and ending frame
#FRAME_FIRST=1000
#FRAME_LAST=1100
#ffmpeg -i input/video.mp4 -start_number $FRAME_FIRST -vf trim=start_frame=$FRAME_FIRST:end_frame=$FRAME_LAST -q:v 0 -vsync vfr -c:v png "input/frame_%10d.png"