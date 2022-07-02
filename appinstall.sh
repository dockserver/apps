#!/usr/bin/env bash

## SOME IDEAS FROM THEORANGEONE

function progress() {
  $(which echo) && \
    $(which echo) -e "\e[1;31m[RUN UPDATE]\e[0m \e[1m$1\e[0m"
}
function progressfail() {
  $(which echo) && \
    $(which echo) -e "\e[0;91m[FAILED TO UPDATE]\e[0m \e[1m$1\e[0m"
}

function updatecontainer() {
set -e
for app in /opt/apps/**/docker-compose.yml; do
  if [[ $($(which docker-compose) -f "$app" ps -q) ]]; then
     progress "--> Updating $app <--" && \
       $(which docker-compose) -f "$app" --env-file=/opt/appdata/compose/.env down && \
         $(which docker-compose) -f "$app" --env-file=/opt/appdata/compose/.env pull && \
           $(which docker-compose) -f "$app" --env-file=/opt/appdata/compose/.env up -d --force-recreate 
  else
     progressfail "--> Skipping $app as it's not running <--"
  fi
done
exit
}

function install() {
APP=$2
if [[ -d "/opt/apps/$APP" ]];then
   progress "--> install $APP <--" && \
     $(which docker-compose) -f /opt/apps/"$APP"/docker-compose.yml --env-file=/opt/appdata/compose/.env pull && \
       $(which docker-compose) -f /opt/apps/"$APP"/docker-compose.yml --env-file=/opt/appdata/compose/.env up -d --force-recreate 
else
   progressfail "--> NO $APP FOUND || SKIPPING <--"
fi
exit
}

COMMAND=$1
APP=$2
case "$COMMAND" in
   "" ) exit ;;
   "install" ) install ;;
   "updatecontainer" ) updatecontainer ;;
esac
