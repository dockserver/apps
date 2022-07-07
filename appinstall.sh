#!/usr/bin/env bash

## SOME IDEAS FROM THEORANGEONE

function progress() {
  $(which echo) && \
    $(which echo) -e "\e[1;31m[RUN : ]\e[0m \e[1m$1\e[0m"
}
function progressfail() {
  $(which echo) && \
    $(which echo) -e "\e[0;91m[FAILED : ]\e[0m \e[1m$1\e[0m"
}

function curlapp() {
APP=$APP
STATUSCODE=$($(which curl) --silent --output /dev/null --write-out "%{http_code}" https://raw.githubusercontent.com/dockserver/apps/master/"$APP"/docker-compose.yml)
  if test $STATUSCODE -ne 200; then
     progressfail "we could not found the $APP"
  else
     $(which mkdir) -p /tmp/pulls/"$APP" && \
     $(which curl) --silent --output /tmp/pulls/"$APP"/docker-compose.yml https://raw.githubusercontent.com/dockserver/apps/master/"$APP"/docker-compose.yml
  fi
}

function mountdrop() {
  for fod in /mnt/* ;do
     basename "$fod" >/dev/null
     FOLDER="$(basename -- $fod)"
     IFS=- read -r <<< "$ACT"
     if ! ls -1p "$fod/" >/dev/null ; then
        echo "drop /mnt/$FOLDER/"
        $(which fusermount) -uzq /mnt/$FOLDER
     else
        echo "no drop needed /mnt/$FOLDER/"
     fi
  done
}

function updatecompose() {
  export DOCKER_CONFIG=${DOCKER_CONFIG:-/opt/appdata/.docker}
  VERSION="$($(which curl) -sX GET https://api.github.com/repos/docker/compose/releases/latest | jq --raw-output '.tag_name')"
  ARCH=$(uname -m)
  progress "**** installing now docker composer $VERSION on $ARCH ****" && \
  $(which mkdir) -p $DOCKER_CONFIG/cli-plugins && \
  $(which curl) -fsSL "https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-linux-${ARCH}" -o $DOCKER_CONFIG/cli-plugins/docker-compose
  if test -f $DOCKER_CONFIG/cli-plugins/docker-compose;then
     $(which chmod) +x $DOCKER_CONFIG/cli-plugins/docker-compose && \
     $(which rm) -f /usr/bin/docker-compose /usr/local/bin/docker-compose && \
     $(which cp) -r $DOCKER_CONFIG/cli-plugins/docker-compose /usr/bin/docker-compose && \
     $(which cp) -r $DOCKER_CONFIG/cli-plugins/docker-compose /usr/local/bin/docker-compose
  else
     sleep 5 ## wait time before next pull
     $(which mkdir) -p $DOCKER_CONFIG/cli-plugins && \
     $(which curl) -fsSL https://github.com/docker/compose/releases/download/$VERSION/docker-compose-linux-`$(uname -m)` -o $DOCKER_CONFIG/cli-plugins/docker-compose && \
     $(which rm) -f /usr/bin/docker-compose /usr/local/bin/docker-compose && \
     $(which chmod) +x $DOCKER_CONFIG/cli-plugins/docker-compose && \
     $(which cp) -r $DOCKER_CONFIG/cli-plugins/docker-compose /usr/bin/docker-compose && \
     $(which cp) -r $DOCKER_CONFIG/cli-plugins/docker-compose /usr/local/bin/docker-compose
  fi
}

function updatecontainer() {
export ENV="/opt/appdata/compose/.env"
if [[ ! "$(docker compose version)" ]]; then updatecompose ; fi
   mapfile -t dockers < <(eval docker ps -aq --format='{{.Names}}' | sort -u)
   for APP in ${dockers[@]}; do
     curlapp && progress "--> Updating $APP <--"
     if [[ $APP == "mount" ]]; then
        docker compose -f /tmp/pulls/"$APP"/docker-compose.yml --env-file="$ENV" --ansi=auto down && mountdrop
     fi
     docker compose -f /tmp/pulls/"$APP"/docker-compose.yml --env-file="$ENV" --ansi=auto down && \
     docker compose -f /tmp/pulls/"$APP"/docker-compose.yml --env-file="$ENV" --ansi=auto pull && \
     docker compose -f /tmp/pulls/"$APP"/docker-compose.yml --env-file="$ENV" --ansi=auto up -d --force-recreate
     $(which rm) -rf /tmp/pulls/"$APP"
   done
exit
}

function install() {
APP=${INSTAPP}
export ENV="/opt/appdata/compose/.env"
if [[ ! "$(docker compose version)" ]]; then updatecompose ; fi
if [[ ! -d "/tmp/pulls" ]];then $(which mkdir) -p /tmp/pulls;fi
if [[ -d "/tmp/pulls" ]]; then
   for i in ${APP[@]} ; do
      APP=$i
      curlapp
      if [[ -f "/tmp/pulls/"$i"/docker-compose.yml" ]]; then
         progress "--> install $i <--" && \
         docker compose -f /tmp/pulls/"$i"/docker-compose.yml --env-file="$ENV" --ansi=auto down && \
         docker compose -f /tmp/pulls/"$i"/docker-compose.yml --env-file="$ENV" --ansi=auto pull && \
         docker compose -f /tmp/pulls/"$i"/docker-compose.yml --env-file="$ENV" --ansi=auto up -d --force-recreate && \
         $(which rm) -rf /tmp/pulls/"$i"
      else
         progressfail "--> NO DOCKER-COMPOSE FOUND || EXIT <--"
      fi
   done
else
   progressfail "--> NO $APP FOUND || SKIPPING <--"
fi
exit
}

COMMAND=$1
INSTAPP=${@:2}
case "$COMMAND" in
   "" ) exit ;;
   "install" ) install ;;
   "updatecontainer" ) updatecontainer ;;
   "updatecompose" ) updatecompose ;;
esac
