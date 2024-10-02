#!/bin/bash
# shellcheck disable=SC2129
set -e

log_message() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message"
}

SOURCE=${1:-"input/video1.mp4"}

log_message "Getting info on $SOURCE ..."
FRAMES_COUNT=$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 "$SOURCE")
RESOLUTION=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$SOURCE")
FPS_FFPROBE=$(ffprobe -v 0 -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$SOURCE")
FPS=$(ffprobe -v 0 -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$SOURCE"| bc -l)

log_message "SOURCE = $SOURCE , RESOLUTION = $RESOLUTION , FPS = $FPS , FPS_FFPROBE = $FPS_FFPROBE , FRAMES_COUNT = $FRAMES_COUNT"
log_message "Press [Enter] key to continue..."
read


INFO_FILE="./input/metadata"
# save vars to local file
echo "SOURCE=$SOURCE" > $INFO_FILE
echo "RESOLUTION=$RESOLUTION" >> $INFO_FILE
echo "FRAMES_COUNT=$FRAMES_COUNT" >> $INFO_FILE
echo "FPS=$FPS" >> $INFO_FILE
echo "FPS_FFPROBE=$FPS_FFPROBE" >> $INFO_FILE

# decompose video to frames
log_message "Decomposing video $SOURCE ..."
ffmpeg -i "$SOURCE" -q:v 0 -c:v png -n "input/frame_%10d.png"
#docker run --gpus all -v $(pwd):/data linuxserver/ffmpeg -i "/data/$SOURCE" -q:v 0 -c:v png -n "/data/input/frame_%10d.png"

# set starting and ending frame
#FRAME_FIRST=1000 FRAME_LAST=1100 ffmpeg -i input/video.mp4 -start_number $FRAME_FIRST -vf trim=start_frame=$FRAME_FIRST:end_frame=$FRAME_LAST -q:v 0 -vsync vfr -c:v png "input/frame_%10d.png"

log_message "SOURCE = $SOURCE , RESOLUTION = $RESOLUTION , FPS = $FPS , FPS_FFPROBE = $FPS_FFPROBE , FRAMES_COUNT = $FRAMES_COUNT"
log_message "Finished decomposing video $SOURCE"
