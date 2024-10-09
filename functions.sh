#!/bin/bash

function log_message() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $@"
}

function countdown_seconds() {
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

function wait_for_docker_builds() {
  local PROVISION_INFO_FILE="../metadata-provision"
  while ! grep -q "DOCKER_BUILD_FINISHED=" "$PROVISION_INFO_FILE"; do
    log_message "Waiting for docker builds to finish..."
    countdown_seconds 10
  done
  log_message "Docker build finished"
}

function wait_for_upload_complete() {
  local UPLOAD_INFO_FILE="../metadata-upload"
  while ! grep -q "FINISHED=" "$UPLOAD_INFO_FILE"; do
    log_message "Waiting for upload to finish..."
    countdown_seconds 10
  done
  log_message "Upload finished"
}

exec_remote() {
  local exit_code=$?
  echo "exec_remote: $@"
  ssh "$TUSER@$THOST" -p "$TPORT" "$@"
  if [ $exit_code -ne 0 ]; then
    echo "ERROR: exec_remote: $@ failed with exit code $exit_code"
    exit $exit_code
  fi
}

function check_required_vars() {
  # Required variables
  local required_vars=("THOST" "TPORT" "TUSER")

  # Check if required variables are set
  for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
      echo "$var is not set"
      exit 1
    fi
  done
}

function wait_for_provision() {
  local PROVISION_INFO_FILE="../metadata-provision"
  while ! grep -q "FINISHED=" "$PROVISION_INFO_FILE"; do
    log_message "Waiting for provision to finish..."
    countdown_seconds 10
  done
  log_message "Provision finished, continuing..."
}
