#!/bin/bash
# shellcheck disable=SC2016

. ./functions.sh

# change window title
set_sceen_name "INFO"

watch -c -n 3 'uptime; free; pydf; nvidia-smi; for file in output/metadata-*; do echo "$file : $(tail -n 1 "$file")"; done; ls output/*.lock; '