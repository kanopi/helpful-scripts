#!/bin/bash

set -e

RSYNC_FLAG="--quiet"
GZ_FLAG="--quiet"

if [[ "${DEBUG}" == "1" ]]; then
  set -ex
  CP_FLAG="-v"
  RSYNC_FLAG=""
  GZ_FLAG=""
fi

#### VARIABLES
# Console colors
green='\033[0;32;49m'
green_bg='\033[0;42;30m'
yellow='\033[0;33;49m'
yellow_bold='\033[1;33;49m'
yellow_bg='\033[0;43;30m'
red='\033[0;91;49m'
red_bg='\033[0;101;30m'
blue='\033[0;34;49m'
lime='\033[0;92;49m'
acqua='\033[0;96;49m'
magenta='\033[0;35;49m'
lightmagenta='\033[0;95;49m'
lightmagenta_bg='\033[0;105;30m'
NC='\033[0m'

# Prestore all varibles within an env file.
# If found load that file.
ENV_FILE=${ENV_FILE:-$HOME/.collectlogs}
if [[ -f ${ENV_FILE} ]]; then
  . ${ENV_FILE}
fi

#########
# CONFIG
#########

# Site UUID is REQUIRED: Site UUID from Dashboard URL, e.g. 12345678-1234-1234-abcd-0123456789ab
SITE_ENV=${SITE_ENV:-"live"}

# Geo IP Key To Use
GEOIP_KEY=${GEOIP_KEY:-""}

# Where is the base of everything
BASEDIR=${BASEDIR:-$(pwd)}

# Name of the Data Location
DATA_LOCATION=${BASEDIR}/${DATA_LOCATION:-"sites/${SITE_UUID}/${SITE_ENV}"}

# Where should the log files output to
LOG_DIRECTORY=${LOG_DIRECTORY:-logs}

# Location of the GEOIP Database
GEOIP_FILE_LOCATION=${GEOIP_FILE_LOCATION:-${BASEDIR}/GeoLite2-City.mmdb}
# Report File Name to use with GoAccess
DATE_FORMAT=$(date +%Y%m%d-%H%M)

# Where should the reports output to
REPORT_DIRECTORY=${REPORT_DIRECTORY:-reports}
# Name of the HTML File Created
REPORT_FILE=${REPORT_DIRECTORY}/${REPORT_FILE:-"${SITE_UUID}-${SITE_ENV}-${DATE_FORMAT}.html"}

#####
# Helper functions 
#####

echo-red ()      { echo -e "${red}$1${NC}"; }
echo-green ()    { echo -e "${green}$1${NC}"; }
echo-green-bg () { echo -e "${green_bg}$1${NC}"; }
echo-yellow ()   { echo -e "${yellow}$1${NC}"; }

echo-warning() {
	echo -e "${yellow_bg} WARNING: ${NC} ${yellow}$1${NC}";
	shift
	for arg in "$@"; do
		echo -e "           $arg"
	done
}

echo-error() {
	echo -e "${red_bg} ERROR: ${NC} ${red}$1${NC}"
	shift
	for arg in "$@"; do
		echo -e "         $arg"
	done
}

echo-notice() {
	echo -e "${lightmagenta_bg} NOTICE: ${NC} ${lightmagenta}$1${NC}"
	shift
	for arg in "$@"; do
		echo -e "         $arg"
	done
}

# print string in $1 for $2 times
echo-repeat() {
    seq  -f $1 -s '' $2; echo
}

# prints message to stderr
echo-stderr() {
	(>&2 echo "$@")
}

# Exits fin if previous command exited with non-zero code
if_failed() {
	if [ ! $? -eq 0 ]; then
		echo-red "$*"
		exit 1
	fi
}

# Like if_failed but with more strict error
if_failed_error() {
	if [ ! $? -eq 0 ]; then
		echo-error "$@"
		exit 1
	fi
}

# Local function 
check_if_exists_create () {
  local DIR=$1
  if [[ ! -d ${DIR} ]]; then
    mkdir -p ${DIR}
  fi
}

########### Additional settings you don't have to change unless you want to ###########
# OPTIONAL: Set AGGREGATE_NGINX to true if you want to aggregate nginx logs.
#  WARNING: If set to true, this will potentially create a large file
AGGREGATE_NGINX=true
# if you just want to aggregate the files already collected, set COLLECT_LOGS to FALSE
COLLECT_LOGS=true
# CLEANUP_AGGREGATE_DIR removes all logs except combined.logs from aggregate-logs directory.
CLEANUP_AGGREGATE_DIR=false
# CLEANUP_LOGS removals all logs downloaded
CLEANUP_LOGS=true

if [[ "${SITE_UUID}" == ""  ]] || [[ "${SITE_ENV}" == "" ]]; then
  echo-error "SITE_UUID and SITE_ENV are required variables."
  exit 1
fi 

check_if_exists_create $BASEDIR

if [[ "${DOWNLOAD_GEOIP}" == "1" ]]; then
  if [[ "${GEOIP_KEY}" == "" ]]; then
    echo-error "GEOIP_KEY required in order to update GeoIP"
  else
    echo-notice "Downloading latest GeoLite2 Database from MaxMind"
    cd /tmp/
    curl -fsSL -o geoip.tar.gz "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=${GEOIP_KEY}&suffix=tar.gz"
    tar -xf geoip.tar.gz
    mv GeoLite2-City_*/GeoLite2-City.mmdb $BASEDIR
    rm -rf geopip.tar.gz GeoLite2-City*
  fi
fi

cd $BASEDIR

# Check if the Geo IP file exists.
if [[ -f ${GEOIP_FILE_LOCATION} ]]; then
  GEOIP_FILE="--geoip-database=/GeoIP.mmdb"
  GEOIP_MOUNT="-v '${GEOIP_FILE_LOCATION}:/GeoIP.mmdb'"
fi

# Get Actual Location of GoAccessRC File
GOACCESS_CONFIG_FILE=$(realpath ${GOACCESS_CONFIG_FILE:-$HOME/.goaccessrc})

# If Access File Downlaod Exist Download latest one.
if [[ ! -f "${GOACCESS_CONFIG_FILE}" ]]; then
  curl -fsSL -o $GOACCESS_CONFIG_FILE https://raw.githubusercontent.com/allinurl/goaccess/master/config/goaccess.conf
fi

# If no SSH_OPTIONS are set, use default.
if [[ "${SSH_OPTIONS}" == "" ]]; then
  # If need to use a special key and don't want to define
  if [[ "${SSH_KEY}" != "" ]]; then
    SSH_KEY="-i "${SSH_KEY}" -F /dev/null"
  fi
  SSH_OPTIONS="-e \"ssh -p 2222 -o StrictHostKeyChecking=no ${SSH_KEY}\""
else
  SSH_OPTIONS="-e \"${SSH_OPTIONS}\""
fi

# If location doesn't exist create it.
check_if_exists_create $DATA_LOCATION

# Change to the Data Location Directory.
cd $DATA_LOCATION

# Check if Log Directory exists for storing items.
check_if_exists_create $LOG_DIRECTORY

# Delete all logs found within the Log Directory
if [[ $CLEANUP_LOGS == true ]]; then
  rm -rf ${LOG_DIRECTORY}/*
fi

# Check if Report Directory Exists
check_if_exists_create ${REPORT_DIRECTORY}

# Download Logs to the Log Directory
cd ${LOG_DIRECTORY}

if [ $COLLECT_LOGS == true ]; then
  echo-warning 'COLLECT_LOGS set to $COLLECT_LOGS. Beginning the process...'
  # Download all logs from appservers.
  for app_server in $(dig @8.8.8.8 +short -4 appserver.$SITE_ENV.$SITE_UUID.drush.in); do
    eval rsync -rlz $RSYNC_FLAG --size-only --ipv4 --progress ${SSH_OPTIONS} "$SITE_ENV.$SITE_UUID@$app_server:logs" "app_server_$app_server"
  done

  # Include MySQL logs
  for db_server in $(dig @8.8.8.8 +short -4 dbserver.$SITE_ENV.$SITE_UUID.drush.in); do
    eval rsync -rlz $RSYNC_FLAG --size-only --ipv4 --progress $SSH_OPTIONS "$SITE_ENV.$SITE_UUID@$db_server:logs" "db_server_$db_server"
  done
else
  echo-notice 'skipping the collection of logs..'
fi

if [ $AGGREGATE_NGINX == true ]; then
  echo-notice 'AGGREGATE_NGINX set to $AGGREGATE_NGINX. Starting the process of combining nginx-access logs...'
  check_if_exists_create aggregate-logs

  for d in $(ls -d app*/logs/nginx); do
    for f in $(ls -f "$d"); do
      if [[ $f == "nginx-access.log" ]]; then
        cat "$d/$f" >> aggregate-logs/nginx-access.log
        echo "" >> aggregate-logs/nginx-access.log
      fi
      if [[ $f =~ \.gz ]]; then
        eval cp $CP_FLAG "$d/$f" aggregate-logs/
      fi
    done
  done

  echo-notice "unzipping nginx-access logs in aggregate-logs directory..."
  for f in $(ls -f aggregate-logs); do
    if [[ $f =~ \.gz ]]; then
      eval gunzip $GZ_FLAG -f aggregate-logs/"$f"
    fi
  done
  echo-notice "combining all nginx access logs..."
  for f in $(find aggregate-logs -maxdepth 1 -not -type d -not -name "combined.logs"); do
    cat "$f" >> aggregate-logs/combined.logs
  done
  echo-green 'the combined logs file can be found in aggregate-logs/combined.logs'
else
  echo-notice "AGGREGATE_NGINX set to $AGGREGATE_NGINX. So we're done."
fi

if [ $CLEANUP_AGGREGATE_DIR == true ]; then
  echo-notice 'CLEANUP_AGGREGATE_DIR set to $CLEANUP_AGGREGATE_DIR. Cleaning up the aggregate-logs directory'
  find ./aggregate-logs/ -name 'nginx-access*' -print -exec rm {} \;
fi

cd ..

# GoAccess to Run Report
eval docker run -it --rm -e TZ=${TZ:-"America/Los_Angeles"} \
  -v $(PWD):/mnt/logs \
  -v '${GOACCESS_CONFIG_FILE}:/root/.goaccessrc' \
  $GEOIP_MOUNT \
  allinurl/goaccess \
  $GEOIP_FILE \
  /mnt/logs/${LOG_DIRECTORY}/aggregate-logs/combined.logs \
  -a \
  -o /mnt/logs/${REPORT_FILE} \
  $GOACCESS_EXTRA_ARGS

# Report the file is done
echo-green "Report Created: ${REPORT_PATH}/${REPORT_FILE}"

# Open for MacOS
open $REPORT_FILE
