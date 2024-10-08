#!/bin/bash
# shellcheck disable=SC2129

. ./functions.sh

SOURCE=${1:-"input/video1.mp4"}

log_message "Getting info on $SOURCE ..."
FRAMES_COUNT=$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 "$SOURCE")
RESOLUTION=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$SOURCE")
FPS_FFPROBE=$(ffprobe -v 0 -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$SOURCE")
FPS=$(ffprobe -v 0 -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$SOURCE" | bc -l)

# if any is empty, quit
while true; do
  if [ -z "$FRAMES_COUNT" ] || [ -z "$RESOLUTION" ] || [ -z "$FPS" ] || [ -z "$FPS_FFPROBE" ]; then
    log_message "Error getting metadata, quitting..."
    countdown_seconds 10
  else
    break
  fi
done

set_sceen_name "Decomposing(wait)"
log_message "SOURCE = $SOURCE , RESOLUTION = $RESOLUTION , FPS = $FPS , FPS_FFPROBE = $FPS_FFPROBE , FRAMES_COUNT = $FRAMES_COUNT"
log_message "waiting for a while..."
countdown_seconds 15

PROVISION_INFO_FILE="../metadata-provision"
log_message "Waiting for provision to finish..."
while ! grep -q "PROVISIONING_FINISHED=" "$PROVISION_INFO_FILE"; do
  countdown_seconds 10
done
log_message "Provision finished, continuing..."

#log_message "Press [Enter] key to continue..."
#read

log_message "Collecting metadata..."
INFO_FILE="./input/metadata-decompose"
# save vars to local file
echo "SOURCE=$SOURCE" > $INFO_FILE
echo "RESOLUTION=$RESOLUTION" >> $INFO_FILE
echo "FRAMES_COUNT=$FRAMES_COUNT" >> $INFO_FILE
echo "FPS=$FPS" >> $INFO_FILE
echo "FPS_FFPROBE=$FPS_FFPROBE" >> $INFO_FILE
echo "STARTED=$(date +'%Y-%m-%d %H:%M:%S')" >> $INFO_FILE
echo "MD5_HASH=$(md5sum "$SOURCE" | awk '{ print $1 }')" >> $INFO_FILE
log_message "Metadata saved to $INFO_FILE"
cat $INFO_FILE

# decompose video to frames
log_message "Decomposing video $SOURCE ..."
set_sceen_name "Decomposing(working)"

#if [ -z "$NOCUDA" ]; then
#  log_message "Using ffmpeg with cuda"
#  ffmpeg -hwaccel cuda -i "$SOURCE" -q:v 0 -c:v png -n "input/frame_%10d.png"
#else
log_message "Using ffmpeg without cuda"
ffmpeg -i "$SOURCE" -q:v 0 -c:v png -n "input/frame_%10d.png"
#fi

#docker run --gpus all -v $(pwd):/data linuxserver/ffmpeg -i "/data/$SOURCE" -q:v 0 -c:v png -n "/data/input/frame_%10d.png"

# set starting and ending frame
#FRAME_FIRST=1000 FRAME_LAST=1100 ffmpeg -i input/video.mp4 -start_number $FRAME_FIRST -vf trim=start_frame=$FRAME_FIRST:end_frame=$FRAME_LAST -q:v 0 -vsync vfr -c:v png "input/frame_%10d.png"

echo "FINISHED=$(date +'%Y-%m-%d %H:%M:%S')" >> $INFO_FILE
log_message "SOURCE = $SOURCE , RESOLUTION = $RESOLUTION , FPS = $FPS , FPS_FFPROBE = $FPS_FFPROBE , FRAMES_COUNT = $FRAMES_COUNT"
log_message "Finished decomposing video $SOURCE"
set_sceen_name "Decomposing(DONE)"
