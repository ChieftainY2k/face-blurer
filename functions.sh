#!/bin/bash

function log_message() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $@"
}

function countdown_seconds()
{
  local count=$1
  while [ $count -gt 0 ]; do
    echo -ne " $count"
    sleep 1
    count=$((count - 1))
  done
  echo ""
}

function check_error() {
  local EXIT_CODE=$?
  local MESSAGE=${1:-"An error occurred"}
  if [ $EXIT_CODE -ne 0 ]; then
    log_message "ERROR: exit code $? $MESSAGE"
    log_message "Press ENTER to continue"
    read
    exit 1
  fi
}

function set_sceen_name() {
  local SCREEN_NAME=$1
  # check if inside screen, then set the title
  if [ -n "$STY" ]; then
    echo -ne "\033k$SCREEN_NAME\033\\"
  fi
}
