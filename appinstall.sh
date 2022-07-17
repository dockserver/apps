#!/usr/bin/env bash
####################################
# All rights reserved.              #
# started from Zero                 #
# Docker owned dockserver           #
# Docker Maintainer dockserver      #
#####################################
#####################################
# NO CUSTOMIZING IS ALLOWED         #
# NO REBRANDING IS ALLOWED          #
# NO CODE MIRRORING IS ALLOWED      #
#####################################
# shellcheck disable=SC2086
# shellcheck disable=SC2046

function changes() {

$(which cat) <<- EOF
## CHANGELOG ##
## PREVIEW OF VERSION 0.4 || DATE UNKNOWN YET GMT
## NEXT RELEASE WILL COVER : 
##    ADD RESTORE OPTION
##    RESTORE FROM CLOUD AND INSTALL APPS
##    AFTER RESTORE INSTALL APP WITH COMPOSER
##    CHECK IS ENVIRONMENT FILE AVAILABLE 
##    USE ENCRYPTED OR UNENCRYPTED OPTIONS FOR TAR FILES
##    USE PLEX/EMBY/JELLYFIN HW SUPPORT INTEL AND NVIDIA SMI
##
##  NOTES : 
##    BACKUP ENV AND WRITE LIVE TO JSON
##    ADD KEYGEN OPTIONS    [[ DOCKER RUN COMMANDS  || ONLY GOOGLE SIDE NEEDED ]]
##    ADD CONFIG BACKUP
##    RUN JSON2ENV TO WRITE JSON FILE FROM ENVIRONMENT [[ DOCKER RUN COMMAND ]]
##
##    SOME DEV NOTES FOR NEXT PARTS
## ------------------------------
## VERSION 0.3 || 17/07/2022 GMT
##    ADD UPLOAD FUNCTIONS TO CLOUD
##    ADD RCLONE DOCKER RUN COMMAND TO UPLOAD BACKUPS AFTER BACKUP FILE [[ REMAP REMOTE NOT ONLY GOOGLE ]]
##    RESTORE FROM CLOUD AND INSTALL APPS  [[ 50% ]]
##    UPLOAD SYSTEM FOLDER TO CLOUD
##    BACKUP SYSTEM FOLDER [[ AFTET BACKUPALL FINAL RUN ]]
##
## VERSION 0.2 || 15/07/2022 GMT
##    ADD BACKUP AND BACKUPALL FOR CONTAINER 
##    DEFINE VALUES TO USE SIMPLE AS POSSIBLE
##
## VERSION 0.1 || 07/07/2022 GMT
##    ADD INSTALL AND COMPOSERUPDATE FROM REMOTE REPOSITORY 
##
### END OF CHANGELOG 
EOF
}
set -eo pipefail

IFS=$'\n\t'

### DEFINE SOME VARS
hostName="$(hostname)"
temp='/tmp/docker_backup'
pulls='/tmp/pulls'
appdata='/opt/appdata'
backup='/mnt/downloads/docker_backup'
restore='/mnt/unionfs/docker_backup'
rcloneConf='/opt/appdata/system/'
rcloneCommand='$(which docker) run --rm --name=rclone-${app} -v ${rcloneConf}:/config/rclone -v ${backup}:/data:shared --user $(id -u):$(id -g) rclone/rclone'
rcloneOpts='--checksum --stats-one-line --stats 1s --progress'
source='https://raw.githubusercontent.com/dockserver/apps/master'
# Exclude containers, IE:
# ("plex" "sonarr" "radarr" "lidarr")
exclude=("")

## SOME IDEAS FROM THEORANGEONE

function progress() {
  $(which echo) && \
    $(which echo) -e "\e[1;31m[RUN]\e[0m \e[1m$1\e[0m"
}

function progressdone() {
  $(which echo) && \
    $(which echo) -e "\e[1;31m[DONE]\e[0m \e[1m$1\e[0m"
}

function progressfail() {
  $(which echo) && \
    $(which echo) -e "\e[0;91m[FAILED]\e[0m \e[1m$1\e[0m"
}

  #### LOOPING FOLDERS ####
  for folder in ${temp} ${backup} ${appdata} ${restore} ${pulls}; do
    [[ ! -d "$folder" ]] && \
      progress "create now $folder" && \
      $(which mkdir) -p "$folder" && \
      $(which chown) 1000:1000 "$folder"
  done
  unset folder
  for apts in tar curl wget pigz rsync; do
      command -v ${apts} >/dev/null 2>&1 || { echo >&2 "We require ${apts} but it's not installed. Now we install ${apts}."; $(which apt) install -y ${apts}; }
  done
  unset apts

function curlapp() {
  app=${app}
  STATUSCODE=$($(which curl) --silent --output /dev/null --write-out "%{http_code}" ${source}/"$app"/docker-compose.yml)
  if test $STATUSCODE -ne 200; then
     progressfail "we could not found the DOCKER-COMPOSE for $app"
  else
     $(which mkdir) -p "${pulls}"/"$app" && \
     $(which curl) --silent --output "${pulls}"/"$app"/docker-compose.yml ${source}/"$app"/docker-compose.yml
  fi
}

function backupSystem() {
  app=system
  backup
}

function backupall() {
  for app in `$(which docker) inspect --format='{{.Name}}' $($(which docker) ps -q) | cut -f2 -d\/ | sort -u`;do
      backup
  done
  backupSystem
}

function backup() {
  app=${app}
  if [[ ! ${exclude[*]} =~ ${app} ]] && [[ -d "${appdata}/${app}" ]]; then
     progress "Backing up now ${app} ..."
     reqSpace=$($(which du) -s "${appdata}/${app}" | awk 'NR==1 {print $1}')
     availSpace=$($(which df) "${temp}" | awk 'NR==2 { print $4 }')
     OPTIONSTAR=""
     [[ -f "/opt/dockserver/apps/.backup/backup_excludes" ]] && OPTIONSTAR="--exclude-from=/opt/dockserver/apps/.backup/backup_excludes"
     if (( reqSpace < availSpace )); then
        $(which tar) "${OPTIONSTAR}" -C "${appdata}/${app}" -pcf "${temp}/${app}".tar.gz ./
        $(which rsync) -rv --chown=1000:1000 --exclude='*/' "${temp}/${app}".tar.gz "${backup}/${app}".tar.gz && \
        $(which rm) -rf "${temp}/${app}".tar.gz
     else
        $(which tar) "${OPTIONSTAR}" -C "${appdata}/${app}" -pcf "${backup}/${app}".tar.gz ./
        $(which chown) -cR 1000:1000 "${backup}/${app}".tar.gz
     fi
     [[ -f "${backup}/${app}.tar.gz" ]] && \
        tarSize=$($(which du) -sh "${backup}/${app}".tar.gz | awk 'NR==1 { print $1 }') && \
        progressdone "Backup of ${app} with ${tarSize} is done ..."
     [[ -f "${rcloneConf}/rclone.conf" ]] && \
        rcloneSetRemote && \
        rcloneUpload
  else
     progress "skipping ${app} is excluded or under ${appdata} the folder not exists ..."
  fi
}

#### USE OFFICIAL IMAGE || NO CUSTOM IMAGE ####
function rcloneSetRemote() {
  $(which docker) run --rm -v ${rcloneConf}:/config/rclone --user $(id -u):$(id -g) rclone/rclone listremotes >> /tmp/listremotes
  if [[ $($(which cat) /tmp/listremotes | grep crypt | awk 'NR==1 {print $1}') != "" ]];then
     remote=$(which cat) /tmp/listremotes | grep "crypt" | awk 'NR==1 {print $1}')
  else
     remote=$(which cat) /tmp/listremotes | awk 'NR==1 {print $1}')
  fi
}

function rcloneUpload() {
  for apprcup in copy move; do
     progress "Uploading now ${app}.tar.gz to ${remote} ..." && \
     "${rcloneCommand}" apprcup /data/${app}.tar.gz ${remote}:/backup/${app}.tar.gz "${rcloneOpts}"
  done
}

function rcloneDownload() {
  progress "Downloading now ${app}.tar.gz from ${remote} ..." && \
  "${rcloneCommand}" copy ${remote}:/backup/${app}.tar.gz /data/${app}.tar.gz "${rcloneOpts}"
}
#### USE OFFICIAL IMAGE || NO CUSTOM IMAGE ####

function mountdrop() {
  for fod in /mnt/* ;do
     basename "$fod" >/dev/null
     FOLDER="$(basename -- $fod)"
     IFS=- read -r <<< "$ACT"
     if ! ls -1p "$fod/" >/dev/null ; then
        echo "drop /mnt/$FOLDER/ .... "
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
  progress "installing now docker composer $VERSION on $ARCH ...." && \
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
     for app in `$(which docker) inspect --format='{{.Name}}' $($(which docker) ps -q) | cut -f2 -d\/ | sort -u`;do
         install
      done
  exit
}

function install() {
  app=${app}
  export ENV="/opt/appdata/compose/.env"
  if [[ ! "$(docker compose version)" ]]; then updatecompose ; fi
  if [[ -d "${pulls}" ]]; then
     for app in ${app[@]} ; do
        curlapp
        if [[ -f "${pulls}/"$app"/docker-compose.yml" ]]; then
           progress "install $app ....." 
           if [[ $app == "mount" ]]; then
              docker compose -f "${pulls}"/"$app"/docker-compose.yml --env-file="$ENV" --ansi=auto down && \
              mountdrop
           else
              docker compose -f "${pulls}"/"$app"/docker-compose.yml --env-file="$ENV" --ansi=auto down
           fi
           docker compose -f "${pulls}"/"$app"/docker-compose.yml --env-file="$ENV" --ansi=auto pull && \
           docker compose -f "${pulls}"/"$app"/docker-compose.yml --env-file="$ENV" --ansi=auto up -d --force-recreate && \
           $(which rm) -rf "${pulls}"/"$app"
        else
           progressfail "no DOCKER-COMPOSE found on Remote repository || exit ...."
        fi
     done
  else
     progressfail "no DOCKER-COMPOSE $app found on Remote repository || skipping ...."
  fi
  exit
}

function usage() {
$(which cat) <<- EOF
  ##### OPTIONS       | WHAT IT DOES
  ##
  ## usage            | shows the options / how to use
  ## changes          | shows the changes on this file
  ## install          | to install one or more apps in loop
  ## backup           | to backup one app
  ## backupall        | to backup all running dockers
  ## updatecompose    | to update the local installed composer version
  ## updatecontainer  | to update all running dockers
  #####
EOF
}

#### FUNCTIONS END ####

command=$1
app=${@:2}
case "$command" in
   "" ) exit ;;
   "usage" ) usage ;;
   "changes" ) changes ;;
   "install" ) install ;;
   "updatecontainer" ) updatecontainer ;;
   "updatecompose" ) updatecompose ;;
   "backup" ) backup ;;
   "backupall" ) backupall ;;
esac

#/\E_O_F/\#
