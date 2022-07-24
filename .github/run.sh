#!/bin/bash
####################################
# All rights reserved.              #
# started from Zero                 #
# Docker owned dockserver           #
# Docker Maintainer dockserver      #
#####################################
#####################################
# THIS DOCKER IS UNDER LICENSE      #
# NO CUSTOMIZING IS ALLOWED         #
# NO REBRANDING IS ALLOWED          #
# NO CODE MIRRORING IS ALLOWED      #
#####################################
# shellcheck disable=SC2086
# shellcheck disable=SC2046

export username=${username}
export token=${token}

bash "./appinstall.sh" usage > ./USAGE
bash "./appinstall.sh" changes > ./CHANGELOG


if [[ -n $(git status --porcelain) ]]; then
   git config --global user.name 'dockserver-bot[bot]'
   git config --global user.email 'dockserver-bot[bot]@dockserver.io'
   git add -A
   git commit -sam "[Auto Generation] Changes" || exit 0
   git push --force
fi

exit 0
