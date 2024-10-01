#!/bin/bash
set -xe

SOURCE=${1:-"input/video1.mp4"}


# get number of frames
FRAMES_COUNT=$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 "$SOURCE")
echo "FRAMES_COUNT=$FRAMES_COUNT"

# decompose video to frames
ffmpeg -i "$SOURCE" -q:v 0 -c:v png "input/frame_%10d.png"

# set starting and ending frame
#FRAME_FIRST=1000 FRAME_LAST=1100 ffmpeg -i input/video.mp4 -start_number $FRAME_FIRST -vf trim=start_frame=$FRAME_FIRST:end_frame=$FRAME_LAST -q:v 0 -vsync vfr -c:v png "input/frame_%10d.png"