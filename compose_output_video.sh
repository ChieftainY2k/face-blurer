#!/bin/bash
# shellcheck disable=SC2129,SC2086
set -e

. ./functions.sh

set_sceen_name "Composing(wait)"

INFO_FILE_DECOMPOSE="./input/metadata-decompose"
INFO_FILE_RUN="./output/metadata-run-pass1"
RESOLUTION=$(grep 'RESOLUTION=' $INFO_FILE_DECOMPOSE | cut -d '=' -f 2)
FPS=$(grep 'FPS=' $INFO_FILE_DECOMPOSE | cut -d '=' -f 2)
MD5_HASH=$(grep 'MD5_HASH=' $INFO_FILE_DECOMPOSE | cut -d '=' -f 2)
DEBUG=$(grep 'DEBUG=' $INFO_FILE_RUN | cut -d '=' -f 2)
THRESHOLD=$(grep 'THRESHOLD=' $INFO_FILE_RUN | cut -d '=' -f 2)
BLUR_EXTRA=$(grep 'BLUR_EXTRA=' $INFO_FILE_RUN | cut -d '=' -f 2)
BLUR_AHEAD=$(grep 'BLUR_AHEAD=' $INFO_FILE_RUN | cut -d '=' -f 2)
BLUR_BACK=$(grep 'BLUR_BACK=' $INFO_FILE_RUN | cut -d '=' -f 2)

log_message "Input video metadata:"
# show both files
cat $INFO_FILE_DECOMPOSE
log_message "AI run metadata:"
cat $INFO_FILE_RUN

FILE_MARKER="blurred"
if [ "$DEBUG" == "1" ]; then
  FILE_MARKER="debug"
fi

mkdir -p "output/video"

#COMMAND="ffmpeg -y -r \"$FPS\" -hwaccel \"cuda\" -f image2 -s \"$RESOLUTION\" -i \"output/frame_%10d.png.${FILE_MARKER}.png\" -c:v h264_nvenc -preset slow -cq 20  \"output/video/video-${MD5_HASH}-${RESOLUTION}-${FPS}fps-${FILE_MARKER}-th${THRESHOLD}-be${BLUR_EXTRA}-ba${BLUR_AHEAD}-bb${BLUR_BACK}.mp4\" "

# use this command to add audio to the video
#COMMAND="ffmpeg -y -r \"$FPS\" -hwaccel \"cuda\" -f image2 -s \"$RESOLUTION\" -i \"output/frame_%10d.png.${FILE_MARKER}.png\" -i input/video1.mp4 -map 0:v -map 1:a? -c:v h264_nvenc -preset slow -crf 18 -shortest \"output/video/video-${MD5_HASH}-${RESOLUTION}-${FPS}fps-${FILE_MARKER}-th${THRESHOLD}-be${BLUR_EXTRA}-ba${BLUR_AHEAD}-bb${BLUR_BACK}.mp4\""
COMMAND="ffmpeg -y -thread_queue_size 32 -r \"$FPS\" -hwaccel \"cuda\" -f image2 -s \"$RESOLUTION\" -i \"output/frame_%10d.png.${FILE_MARKER}.png\" -i input/video1.mp4 -map 0:v -map 1:a? -c:v h264_nvenc -preset slow -cq 20 -shortest \"output/video/video-${MD5_HASH}-${RESOLUTION}-${FPS}fps-${FILE_MARKER}-th${THRESHOLD}-be${BLUR_EXTRA}-ba${BLUR_AHEAD}-bb${BLUR_BACK}.mp4\""
# ffmpeg -y -r 30.00000000000000000000 -hwaccel cuda -f image2 -s 1920x1080 -i "output/frame_%10d.png.blurred.png" -i input/video1.mp4 -map 0:v -map 1:a? -c:v h264_nvenc -preset slow -cq 20 -shortest "output/video/video-2eb3b8795e6d96c8985d0b4506e2ea85-1920x1080-30fps-blurred-th0.3-be-ba-bb-audio.mp4"

# show command , wait for ENTER
log_message "About to exec the command: $COMMAND"
#log_message "Press [Enter] key to continue..."
#read
countdown_seconds 5

set_sceen_name "Composing(working)"
eval $COMMAND
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  set_sceen_name "Composing(ERROR)"
  log_message "ERROR: exit code $EXIT_CODE"
  log_message "Press ENTER to continue"
  exit $EXIT_CODE
else
  set_sceen_name "Composing(DONE)"
fi
