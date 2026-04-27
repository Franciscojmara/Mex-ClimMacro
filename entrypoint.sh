#!/usr/bin/env bash
set -e

# Detect UID/GID from mounted volume
if [ -d "/home/rstudio/project/Data" ]; then
    USER_ID=$(stat -c '%u' /home/rstudio/project/Data)
    GROUP_ID=$(stat -c '%g' /home/rstudio/project/Data)
else
    USER_ID=1000
    GROUP_ID=1000
fi

groupmod -g $GROUP_ID rstudio || true
usermod -u $USER_ID -g $GROUP_ID rstudio || true

chown -R rstudio:rstudio /home/rstudio/project/Data 2>/dev/null || true
chown -R rstudio:rstudio /home/rstudio/project/Results 2>/dev/null || true

exec /init