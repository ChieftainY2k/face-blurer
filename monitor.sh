#!/bin/bash

# change window title
echo -ne "\033kINFO\033\\"

watch -c -n 3 "uptime; free; pydf; nvidia-smi; ls output/*.lock"
