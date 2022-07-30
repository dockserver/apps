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
## PREVIEW OF VERSION 0.XXXX || DATE UNKNOWN YET GMT
## NEXT RELEASE WILL COVER :
##    CHECK IS ENVIRONMENT FILE AVAILABLE 
##    USE ENCRYPTED OR UNENCRYPTED OPTIONS FOR TAR FILES
##    USE PLEX/EMBY/JELLYFIN HW SUPPORT INTEL AND NVIDIA SMI
##
##  NOTES :
##    BACKUP ENV AND WRITE LIVE TO JSON
##    ADD KEYGEN OPTIONS    [[ DOCKER RUN COMMANDS || ONLY GOOGLE SIDE NEEDED ]]
##    ADD CONFIG BACKUP
##    RUN JSON2ENV TO WRITE JSON FILE FROM ENVIRONMENT [[ DOCKER RUN COMMAND ]]
##
##    SOME DEV NOTES FOR NEXT PARTS 
## ------------------------------
## VERSION 0.6 || 26/07/2022 GMT
##    ADD GPU SUPPORT FOR INTEL AND NVIDIA
##
## VERSION 0.5 || 24/07/2022 GMT
##    ADD make_dir and  checkcommand function
##    ADD RESTORE OPTION
##    RESTORE FROM CLOUD AND INSTALL APPS
##    AFTER RESTORE INSTALL APP WITH COMPOSER
##    ADD Uploaderkeys options [[ EXPERIMENTAL ]]
##    FEATURE: cleanup script to use more functions
##
## VERSION 0.4 || 18/07/2022 GMT
##    ADD DOCKER RECONNECT [[ JUST STOPPED/EXITES CONTAINERS ]]
##    ADD DOCKER RECONNECT ALL CONTAINERS
##    RESTORE FROM CLOUD AND INSTALL APPS  [[ 75% ]]
##    FIX: UPLOAD FUNCTION TO CLOUD
##
## VERSION 0.3 || 17/07/2022 GMT
##    ADD UPLOAD FUNCTIONS TO CLOUD
##    ADD RCLONE DOCKER RUN COMMAND TO UPLOAD BACKUPS AFTER BACKUP FILE [[ REMAP REMOTE NOT ONLY GOOGLE ]]
##    RESTORE FROM CLOUD AND INSTALL APPS  [[ 50% ]]
##    UPLOAD SYSTEM FOLDER TO CLOUD
##    BACKUP SYSTEM FOLDER [[ AFTER BACKUPALL FINAL RUN ]]
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

### DEFINE SOME VARS
hostName="$(hostname)"
temp='/tmp/docker_backup'
pulls='/tmp/pulls'
appdata='/opt/appdata'
backup='/mnt/downloads/docker_backup'
restore='/mnt/unionfs/docker_backup'

## RCLONE PART
rcloneConf='/opt/appdata/system/'

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

function progresswarn() {
  $(which echo) && \
    $(which echo) -e "\e[0;91m[WARNING]\e[0m \e[1m$1\e[0m"
}

function make_dir() {
  if [[ ! -d "$1" ]]; then
     $(which mkdir) -p "$1" && \
     progress "Folder not exist || create now %s" "$1" && \
     $(which chown) 1000:1000 "$1"
  else
     progress "Folder exist || set now permissions on $1" && \
     $(which chown) 1000:1000 "$1"
  fi
}

function command_exists() {
  if ! [[ -x $(which "$1") ]]; then
       progress "We require ${apts} but it's not installed." && \
       progress "Now we install $1 " && \
       $(which apt) install -y "$1" &>/dev/null
  fi
  return 0
}

## FROM YABS COPIED ##
function format_size() {
   RAW=$1 # mem size in KiB
   RESULT=$RAW
   local DENOM=1
   local UNIT="KiB"
   # ensure the raw value is a number, otherwise return blank
   re='^[0-9]+$'
   if ! [[ $RAW =~ $re ]] ; then
      echo "" && return 0
   fi
   if [ "$RAW" -ge 1073741824 ]; then
      DENOM=1073741824
      UNIT="TB"
   elif [ "$RAW" -ge 1048576 ]; then
        DENOM=1048576
        UNIT="GB"
   elif [ "$RAW" -ge 1024 ]; then
        DENOM=1024
        UNIT="MB"
   fi
   RESULT=$(awk -v a="$RESULT" -v b="$DENOM" 'BEGIN { print a / b }')
   RESULT=$(echo $RESULT | awk -F. '{ printf "%0.1f",$1"."substr($2,1,2) }')
   RESULT="$RESULT $UNIT"
   echo $RESULT
}

## FROM YABS COPIED AND EXTENDED ##
function showsystem() {
# gather basic system information (inc. CPU, AES-NI/virt status, RAM + swap + disk size)
echo -e "---------------------------------"
echo -e "   Basic System Information:"
echo -e "---------------------------------"
UPTIME=$(uptime | awk -F'( |,|:)+' '{d=h=m=0; if ($7=="min") m=$6; else {if ($7~/^day/) {d=$6;h=$8;m=$9} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hours,",m+0,"minutes"}')
echo -e "Uptime     : $UPTIME"
if [[ $ARCH = *aarch64* || $ARCH = *arm* ]]; then
   CPU_PROC=$(lscpu | grep "Model name" | sed 's/Model name: *//g')
else
   CPU_PROC=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
fi
echo -e "Processor  : $CPU_PROC"
if [[ $ARCH = *aarch64* || $ARCH = *arm* ]]; then
   CPU_CORES=$(lscpu | grep "^[[:blank:]]*CPU(s):" | sed 's/CPU(s): *//g')
   CPU_FREQ=$(lscpu | grep "CPU max MHz" | sed 's/CPU max MHz: *//g')
   [[ -z "$CPU_FREQ" ]] && CPU_FREQ="???"
   CPU_FREQ="${CPU_FREQ} MHz"
else
   CPU_CORES=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
   CPU_FREQ=$(awk -F: ' /cpu MHz/ {freq=$2} END {print freq " MHz"}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
fi
echo -e "CPU cores  : $CPU_CORES @ $CPU_FREQ"
CPU_AES=$(cat /proc/cpuinfo | grep aes)
[[ -z "$CPU_AES" ]] && CPU_AES="\xE2\x9D\x8C Disabled" || CPU_AES="\xE2\x9C\x94 Enabled"
echo -e "AES-NI     : $CPU_AES"
CPU_VIRT=$(cat /proc/cpuinfo | grep 'vmx\|svm')
[[ -z "$CPU_VIRT" ]] && CPU_VIRT="\xE2\x9D\x8C Disabled" || CPU_VIRT="\xE2\x9C\x94 Enabled"
echo -e "VM-x/AMD-V : $CPU_VIRT"
TOTAL_RAM=$(format_size $(free | awk 'NR==2 {print $2}'))
echo -e "RAM        : $TOTAL_RAM"
TOTAL_SWAP=$(format_size $(free | grep Swap | awk '{ print $2 }'))
echo -e "Swap       : $TOTAL_SWAP"
# total disk size is calculated by adding all partitions of the types listed below (after the -t flags)
TOTAL_DISK=$(format_size $(df -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t ntfs -t swap --total 2>/dev/null | grep total | awk '{ print $2 }'))
echo -e "Disk       : $TOTAL_DISK"
DISTRO=$(grep 'PRETTY_NAME' /etc/os-release | cut -d '"' -f 2 )
echo -e "Distro     : $DISTRO"
KERNEL=$(uname -r)
echo -e "Kernel     : $KERNEL"
if [ -d "/dev/dri" ]; then
   for i in Intel NVIDIA;do
       lspci | grep -i --color 'vga\|display\|3d\|2d' | grep -E $i | while read -r -a $i; do
       echo -e "$i      : is activated"
       done
   done       
   echo -e "/dev/dri   : is active"
fi
echo -e "---------------------------------"
echo -e "   Docker Compose Part:"
echo -e "---------------------------------"
DCLOAL="$(docker compose version | awk 'NR==1 { print $4 }')"
DCOMRENOTE="$($(which curl) -sX GET https://api.github.com/repos/docker/compose/releases/latest | jq --raw-output '.tag_name')"
echo -e "LOCAL      : $DCLOAL"
echo -e "REMOTE     : $DCOMRENOTE"
echo -e "---------------------------------"
echo -e "   Docker Container Part:"
echo -e "---------------------------------"
for id in `docker ps -q -f 'status=running' | cut -f2 -d\/ | sort -u`;do
    for app in `docker inspect --format='{{.Name}}' $id| cut -f2 -d\/`;do
        echo -e "Docker     : $app is running"
    done
done
unset id
for iddead in `docker ps -q -f 'status=exited' -f 'status=dead' -f 'status=paused' | cut -f2 -d\/ | sort -u`;do
    for app in `docker inspect --format='{{.Name}}' $iddead| cut -f2 -d\/`;do
        echo -e "Docker     : $app is not running"
    done
done
unset iddead
echo -e "---------------------------------"
exit 0 
}

function curlapp() {
  app=${app}
  STATUSCODE=$($(which curl) --silent --output /dev/null --write-out "%{http_code}" ${source}/"$app"/docker-compose.yml)
  if test $STATUSCODE -ne 200; then
     progressfail "we could not found the DOCKER-COMPOSE for $app"
  else
     make_dir "${pulls}"/"$app" && \
     $(which curl) --silent --output "${pulls}"/"$app"/docker-compose.yml ${source}/"$app"/docker-compose.yml
  fi
}

function curlgpu() {
app=${app}
for i in Intel NVIDIA;do
   lspci | grep -i --color 'vga\|display\|3d\|2d' | grep -E $i |while IFS= read -ra $i; do
      if [[ $i == Intel ]] ; then
         STATUSCODE=$($(which curl) --silent --output /dev/null --write-out "%{http_code}" ${source}/"$app"/docker-compose.intel.yml)
         if test $STATUSCODE == 200; then
            $(which curl) --silent --output "${pulls}"/"$app"/docker-compose.override.yml ${source}/"$app"/docker-compose.intel.yml
         fi
      fi
      if [[ $i == NVIDIA ]] ; then
         STATUSCODE=$($(which curl) --silent --output /dev/null --write-out "%{http_code}" ${source}/"$app"/docker-compose.nvidia.yml)
         if test $STATUSCODE == 200; then
            $(which curl) --silent --output "${pulls}"/"$app"/docker-compose.override.yml ${source}/"$app"/docker-compose.nvidia.yml
         fi
      fi
   done
done
}

function backupSystem() {
  app=system
  backup
}

function backupall() {
  for app in `$(which docker) inspect --format='{{.Name}}' $($(which docker) ps -q) | cut -f2 -d\/ | sort -u`;do backup ; done
  backupSystem
}

function backupsome() {
  app=${app}
  for app in ${app[@]} ; do backup ; done
  backupSystem
}

function backup() {
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
     [[ -f "${rcloneConf}rclone.conf" ]] && \
        rcloneSetRemote && \
        rcloneUpload
  else
     progress "skipping ${app} is excluded or under ${appdata} the folder not exists ..."
  fi
}

#### USE OFFICIAL IMAGE || NO CUSTOM IMAGE ####
function rcloneSetRemote() {
  $(which docker) pull rclone/rclone &>/dev/null
  [[ -f "/tmp/listremotes" ]] && \
     $(which rm) -rf /tmp/listremotes
  $(which docker) run --rm -v "${rcloneConf}:/config/rclone" --user 1000:1000 rclone/rclone listremotes >> /tmp/listremotes
  checkcrypt=$($(which cat) /tmp/listremotes | grep crypt | awk 'NR==1 {print $1}')
  if [[ ${checkcrypt} != "" ]];then
     remote=$($(which cat) /tmp/listremotes | grep crypt | awk 'NR==1 {print $1}')
  else
     remote=$($(which cat) /tmp/listremotes | awk 'NR==1 {print $1}')
  fi
}

function rcloneUpload() {
  for apprcup in copyto moveto; do
      backupfolder=backup
      if [[ $apprcup == move ]]; then backupfolder="${hostName}/backup" ; fi
      progress "Uploading now ${app}.tar.gz to ${remote}/${backupfolder} ..." && \
      $(which docker) run --rm \
         -v "${rcloneConf}:/config/rclone" \
         -v "${backup}:/data:shared" \
         --user 1000:1000 rclone/rclone \
         $apprcup /data/${app}.tar.gz ${remote}/${backupfolder}/${app}.tar.gz -vP --stats=1s && \
      progressdone "Uploading of ${app}.tar.gz is done"
  done
}

function rcloneDownload() {
  rcloneSetRemote
  backupfolder=backup
  progress "Downloading now ${app}.tar.gz from ${remote}/${backupfolder} ..." && \
       $(which docker) pull rclone/rclone &>/dev/null
       $(which docker) run --rm \
          -v "${rcloneConf}:/config/rclone" \
          -v "${backup}:/data:shared" \
          --user 1000:1000 rclone/rclone \
          copyto ${remote}/${backupfolder}/${app}.tar.gz /data/${app}.tar.gz -vP --stats=1s
      [[ -f "${backup}/${app}.tar.gz" ]] && \
          progressdone "downloading of ${app}.tar.gz is done" && \
          make_dir "${appdata}/${app}" && \
          $(which unpigz) -dcqp 8 ${backup}/${app}.tar.gz | $(which pv) -pterb | $(which tar) pxf - -C "${appdata}/${app}" --strip-components=1
          install
          $(which rm) -rf ${backup}/${app}.tar.gz
      [[ ! -f "${backup}/${app}.tar.gz" ]] && \
          progressfail "downloading of ${app}.tar.gz is failed" && \
          sleep 90 && exit 0
}

#### USE OFFICIAL IMAGE || NO CUSTOM IMAGE ####

function restoreon() {
  app=${app}
  for app in ${app[@]} ; do rcloneDownload ; done
}

function mountdrop() {
  for fod in /mnt/* ;do
      basename "$fod" >/dev/null
      FOLDER="$(basename -- $fod)"
      IFS=- read -r <<< "$ACT"
      if ! ls -1p "$fod/" >/dev/null ; then
         progress "drop /mnt/$FOLDER/ .... "
         $(which fusermount) -uzq /mnt/$FOLDER
      else
         progress "no drop needed /mnt/$FOLDER/"
      fi
  done
}

function uploaderkeys() {

make_dir "${appdata}/system/servicekeys"
make_dir "${appdata}/system/gcloud"

RUNCOMMAND="docker run -it -v "${appdata}/system/:/system" -v "${appdata}/system/gcloud:/root/.config/gcloud""
ENV_VARS=("ACCOUNT" "PROJECT" "SANAME" "NUMGDSAS" "PROGNAME" "TEAMDRIVEID" "ENCRYPT" "PASSWORD" "SALT")
for ENV_VAR in "${ENV_VARS[@]}"; do unset ${ENV_VAR} ; done
for ENV_VAR in "${ENV_VARS[@]}"; do
    if [[ -z ${!ENV_VAR} ]];then
       read -erp "set now ${ENV_VAR} " typed </dev/tty
       if [[ $typed == z ]] || [[ $typed == Z ]] || [[ $typed == EXIT ]] || [[ $typed == exit ]]; then
          $(which echo) "exit now || you can rerun it ;)"
       elif [[ $typed != "" ]];then
          RUNCOMMAND+=" --env ${ENV_VAR}=$typed "
       else
          $(which echo) "${ENV_VAR} is not set"
       fi
    fi
done

RUNCOMMAND+=" ghcr.io/dockserver/docker-gdsa"
RUNCOMMAND+=" /bin/bash"

read -p "Type Y to continue " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
   ${RUNCOMMAND}
else
   exit 1
fi

}

function reconnect() {
  for id in `docker ps -q -f 'status=exited' -f 'status=dead' -f 'exited=0') | cut -f2 -d\/ | sort -u`;do
      for app in `docker inspect --format='{{.Name}}' $id| cut -f2 -d\/`;do
          progress "stopping now $app...." && \
          $(which docker) stop $app &>/dev/null
          if [[ $app == "mount" ]]; then mountdrop ; fi
          progress "drop $app from proxy network...." && \
             $(which docker) network disconnect proxy $app &>/dev/null
          progress "reconnect $app to proxy network...." && \
             $(which docker) network connect proxy $app &>/dev/null
          progress "docker start $app ...." && \
             $(which docker) start $app &>/dev/null
      done
  done
}

function reconnectall() {
  for app in `$(which docker) inspect --format='{{.Name}}' $($(which docker) ps -q) | cut -f2 -d\/ | sort -u`;do
      progress "stopping now $app...." && \
      $(which docker) stop $app &>/dev/null
      if [[ $app == "mount" ]]; then
         mountdrop
      fi
      progress "drop $app from proxy network...." && \
        $(which docker) network disconnect proxy $app &>/dev/null
      progress "reconnect $app to proxy network...." && \
        $(which docker) network connect proxy $app &>/dev/null
      progress "docker start $app ...." && \
        $(which docker) start $app &>/dev/null
  done
}

function updatecompose() {
  export DOCKER_CONFIG=${DOCKER_CONFIG:-/opt/appdata/.docker}
  VERSION="$($(which curl) -sX GET https://api.github.com/repos/docker/compose/releases/latest | jq --raw-output '.tag_name')"
  ARCH=$(uname -m)
  progress "installing now docker composer $VERSION on $ARCH ...." && \
  make_dir $DOCKER_CONFIG/cli-plugins && \
  $(which curl) -fsSL "https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-linux-${ARCH}" -o $DOCKER_CONFIG/cli-plugins/docker-compose
  if test -f $DOCKER_CONFIG/cli-plugins/docker-compose;then
     $(which chmod) +x $DOCKER_CONFIG/cli-plugins/docker-compose && \
     $(which rm) -f /usr/bin/docker-compose /usr/local/bin/docker-compose && \
     $(which cp) -r $DOCKER_CONFIG/cli-plugins/docker-compose /usr/bin/docker-compose && \
     $(which cp) -r $DOCKER_CONFIG/cli-plugins/docker-compose /usr/local/bin/docker-compose
  else
     sleep 5 ## wait time before next pull
     make_dir $DOCKER_CONFIG/cli-plugins && \
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
  for app in `$(which docker) inspect --format='{{.Name}}' $($(which docker) ps -q) | cut -f2 -d\/ | sort -u`;do install ; done
  exit
}

function remove() {
  app=${app}
    progresswarn " This will permanently remove the data and the ${app} ! Are you sure?"
    read -erp "Continue (y/n)?" choice </dev/tty
    case "$choice" in
      y|Y|yes|YES )
        curlapp
        if [[ -f "${pulls}/"$app"/docker-compose.yml" ]]; then
           progress "remove $app ....."
           $DOCKER_COMPOSE -f "${pulls}"/"$app"/docker-compose.yml --env-file="$ENV" --ansi=auto down
           if [[ $app == "mount" ]]; then mountdrop ; fi
           $DOCKER_COMPOSE -f "${pulls}"/"$app"/docker-compose.yml --env-file="$ENV" --ansi=auto rm -fv && \
           [[ -d "${appdata}/${app}" ]] && \
              progress "We build a backup before removing the data from the host for ${app}" && \
              backup && \
              $(which rm) -rf "${appdata}/${app}"
           [[ -d "${pulls}/${app}" ]] && $(which rm) -rf "${pulls}"/"$app"
        else
           progressfail "no DOCKER-COMPOSE found on Remote repository || exit ...."
        fi
        echo "remove performed and done for ${app}"
        ;;
      n|N|NO|no|exit ) echo "remove aborted" && exit 0 ;;
      * ) echo "Invalid option supplied. Aborted remove." && exit 0 ;;
    esac
}

function install() {
  app=${app}
  export ENV="/opt/appdata/compose/.env"
  if [[ ! "$(docker compose version)" ]]; then updatecompose ; fi
  for app in ${app[@]} ; do
      curlapp
      if [ -d "/dev/dri" ]; then curlgpu ; fi
      if [[ -f "${pulls}/"$app"/docker-compose.yml" ]]; then
         progress "install $app ....." 
         $DOCKER_COMPOSE -f "${pulls}"/"$app"/docker-compose.yml --env-file="$ENV" --ansi=auto down && \
         if [[ $app == "mount" ]]; then mountdrop ; fi
         $DOCKER_COMPOSE -f "${pulls}"/"$app"/docker-compose.yml --env-file="$ENV" --ansi=auto pull
         if [[ -f "${pulls}/"$app"/docker-compose.override.yml" ]]; then
            progress "install $app with override composer ....." && \
            $DOCKER_COMPOSE -f "${pulls}"/"$app"/docker-compose.yml --env-file="$ENV" --ansi=auto pull && \
            $DOCKER_COMPOSE -f "${pulls}"/"$app"/docker-compose.yml -f "${pulls}"/"$app"/docker-compose.override.yml --env-file="$ENV" --ansi=auto up -d --force-recreate
         else
            progress "install $app ....." && \
            $DOCKER_COMPOSE -f "${pulls}"/"$app"/docker-compose.yml --env-file="$ENV" --ansi=auto pull && \
            $DOCKER_COMPOSE -f "${pulls}"/"$app"/docker-compose.yml --env-file="$ENV" --ansi=auto up -d --force-recreate
         fi
         $(which rm) -rf "${pulls}"/"$app"
         progressdone " install ${app} .... successfully"
      else
         progressfail "no DOCKER-COMPOSE found on Remote repository || exit ...."
      fi
  done
  exit
}

function usage() {
$(which cat) <<- EOF
  ##### OPTIONS       | WHAT IT DOES
  ##
  ## usage            | shows the options / how to use
  ## showsystem       | shows system status
  ## changes          | shows the changes on this file
  ## install          | to install one or more apps in loop
  ## remove           | to remove the app and the folder
  ## backup           | to backup one app
  ## backupsome       | backup more as one app in loop
  ## backupall        | to backup all running dockers
  ## uploaderkeys     | to generate google_service_keys
  ## restoreon        | restore one app from cloud and install it
  ## reconnect        | reconnect all exited \ stopped apps
  ## reconnectall     | reconnect all apps to proxy network
  ## updatecompose    | to update the local installed composer version
  ## updatecontainer  | to update all running dockers
  #####
EOF
}

#### FUNCTIONS END ####
if [ $1 != usage ] && [ $1 != changes ]; then 
   for folder in ${temp} ${backup} ${appdata} ${restore} ${pulls}; do
       make_dir "$folder"
   done
   unset folder
   for apts in tar curl wget pigz rsync pv; do
       command_exists ${apts}
   done
   unset apts
fi
### SET COMPOSER PART IF USED OLD NEW VERSIONS ###
DOCKER_COMPOSE="docker compose"
if ! $DOCKER_COMPOSE > /dev/null 2>&1; then
   DOCKER_COMPOSE="docker-compose"
fi
### COMMANDS ###

command=$1
app=${@:2}
case "$command" in
   "" ) exit ;;
   "usage" ) usage ;;
   "changes" ) changes ;;
   "install" ) install ;;
   "remove" ) remove ;;
   "updatecontainer" ) updatecontainer ;;
   "updatecompose" ) updatecompose ;;
   "uploaderkeys" ) uploaderkeys ;;
   "backup" ) backup ;;
   "backupsome" ) backupsome ;;
   "backupall" ) backupall ;;
   "restoreon" ) restoreon ;;
   "reconnect" ) reconnect ;;
   "reconnectall") reconnectall ;;
   "showsystem") showsystem ;;
esac

#/\E_O_F/\#
