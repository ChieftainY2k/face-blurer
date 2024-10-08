#!/bin/bash
# shellcheck disable=SC2016

. ./functions.sh

# change window title
set_sceen_name "INFO"

watch -c -n 3 'uptime; free; pydf; nvidia-smi; ls output/*.lock; for file in output/meta*; do echo "$file : $(tail -n 1 "$file")"; done'