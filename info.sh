#!/bin/bash

. ./functions.sh

# change window title
set_sceen_name "INFO"

watch -c -n 3 "uptime; free; pydf; nvidia-smi; ls output/*.lock"
