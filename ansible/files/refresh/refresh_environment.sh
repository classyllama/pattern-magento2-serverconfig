#!/usr/bin/env bash

set -eu

########################################
## Static variables
########################################
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

########################################
## Introduction
########################################
HELP_INFO=$(cat <<CONTENTS_HEREDOC
refresh_environment.sh v0.2
Copyright (c) 2021, Matt Johnson (matt.johnson@classyllama.com). All 
rights reserved.

This script expects there to be a config file either piped into the script as input
or supplied as a config option where configurations specific to these environment can 
exist along with any sensetive details such as commands to change database config 
values so that lives separately from this script.

Usage: refresh_environment.sh [options]
  -f=file_name,         --file=file_name         File with URLs on each line
  --check         Check Mode / Dry Run
                  Displays commands built from config file only, does not run them
  --help          This help information

Examples:
  # Normal Execution
  cat ./file_name | ./refresh_environment.sh
  ./refresh_environment.sh -f=file_name
  ./refresh_environment.sh --file=file_name
  
  # Check Mode / Dry Run
  cat ./file_name | ./refresh_environment.sh --check
  ./refresh_environment.sh -f=file_name --check
  ./refresh_environment.sh --file=file_name --check
  
  # Override configs with multiple json files
  cat ./config_default ./config_override ./config_override_sensitive | jq -s add | ./refresh_environment.sh --check
CONTENTS_HEREDOC
)

# Move execution to realpath of script
cd $(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

########################################
## Command Line Options
########################################
FLAG_CHECK_MODE=false
declare FILE=""
declare FLAG_FILE=false
declare FLAG_INPUT=false
for switch in $@; do
    case $switch in
        -f=*|--file=*)
            FILE="${switch#*=}"
            if [[ ! "${FILE}" =~ ^.+$ ]]; then
                >&2 echo "Error: Invalid value given -f|--file=${FILE}"
                exit -1
            fi
            if ! [ -f "${FILE}" ]; then
                >&2 echo "Error: No file found at location specified"
                exit -1
            fi
            FLAG_FILE=true
            ;;
        --check)
            FLAG_CHECK_MODE=true
            ;;
        --help)
            echo "${HELP_INFO}"
            exit;
            ;;
    esac
done

########################################
## Check for required parameters
## Test for piped input or command option
########################################
if [ -t 0 ]; then # check if STDIN is a terminal
  if [[ ${FLAG_FILE} == true ]]; then
    if [ ! -z "${FILE}" ]; then # is not empty
      INPUT=$(< ${FILE});
      FLAG_INPUT=true
    else
      >&2 printf "Error: ${RED}The config file ${YELLOW}${FILE}${RED} was not found.${NC}\n"
      exit -1
    fi
  fi
else # expecting STDIN to be piped data
  INPUT=$(< /dev/stdin);
  if [ ! -z "${INPUT}" ]; then # is not empty
    FLAG_INPUT=true
  fi
fi
if [[ ${FLAG_INPUT} == false ]]; then
  >&2 printf "Error: ${RED}No config data was provided.${NC}\n\n"
  echo "${HELP_INFO}"
  exit -1
fi
if [[ -z "${INPUT}" ]]; then
  >&2 printf "Error: ${RED}The config data provided was empty.${NC}\n"
  exit -1
fi
if ! (echo "${INPUT}" | jq empty >/dev/null 2>&1); then
  >&2 printf "Error: ${RED}Parsing config file input${RED}:${NC}\n"
  echo "${INPUT}" | jq -e .
  exit -1
fi

########################################
## Collect Config Values
########################################

# Extract variables from JSON config file
CONFIG_USE_SSH_AGENT_FORWARDING=$(echo "${INPUT}" | jq -r '.CONFIG_USE_SSH_AGENT_FORWARDING')

SOURCE_DB_NAME=$(echo "${INPUT}" | jq -r '.SOURCE_DB_NAME')
SOURCE_DB_HOST=$(echo "${INPUT}" | jq -r '.SOURCE_DB_HOST')
SOURCE_MAGENTO_ROOT=$(echo "${INPUT}" | jq -r '.SOURCE_MAGENTO_ROOT')

SOURCE_DB_TABLES_TO_EXCLUDE_JSON=$(echo "${INPUT}" | jq -r '.SOURCE_DB_TABLES_TO_EXCLUDE')
SOURCE_MYSQLDUMP_IGNORE_TABLES=(
)
for EACH_ENTRY in $(echo "${SOURCE_DB_TABLES_TO_EXCLUDE_JSON}" | jq -r '.[] | @base64'); do
  EACH_TABLE=$(printf "%s\n" ${EACH_ENTRY} | base64 --decode)
  SOURCE_MYSQLDUMP_IGNORE_TABLES+=(--ignore-table="${SOURCE_DB_NAME}.${EACH_TABLE}")
  
done

SOURCE_DIRECTORIES_TO_SYNC=$(echo "${INPUT}" | jq -r '.SOURCE_DIRECTORIES_TO_SYNC')

DESTINATION_SSH_HOST=$(echo "${INPUT}" | jq -r '.DESTINATION_SSH_HOST')
DESTINATION_SSH_HOST_GET_PUBLIC_IP=$(echo "${INPUT}" | jq -r '.DESTINATION_SSH_HOST_GET_PUBLIC_IP')
DESTINATION_SSH_HOST_USE_IP_OVERRIDE=$(echo "${INPUT}" | jq -r '.DESTINATION_SSH_HOST_USE_IP_OVERRIDE')
DESTINATION_SSH_HOST_IP_OVERRIDE=$(echo "${INPUT}" | jq -r '.DESTINATION_SSH_HOST_IP_OVERRIDE')
DESTINATION_SSH_PORT=$(echo "${INPUT}" | jq -r '.DESTINATION_SSH_PORT')
DESTINATION_SSH_USER=$(echo "${INPUT}" | jq -r '.DESTINATION_SSH_USER')
DESTINATION_DB_NAME=$(echo "${INPUT}" | jq -r '.DESTINATION_DB_NAME')
DESTINATION_DB_HOST=$(echo "${INPUT}" | jq -r '.DESTINATION_DB_HOST')
DESTINATION_MAGENTO_ROOT=$(echo "${INPUT}" | jq -r '.DESTINATION_MAGENTO_ROOT')
DESTINATION_COMMANDS_JSON=$(echo "${INPUT}" | jq -r '.DESTINATION_COMMANDS')
DESTINATION_COMMANDS=""
for EACH_ENTRY in $(echo "${DESTINATION_COMMANDS_JSON}" | jq -r '.[] | @base64'); do
  [[ "${DESTINATION_COMMANDS}" == "" ]] || DESTINATION_COMMANDS="${DESTINATION_COMMANDS}\n"
  EACH_COMMAND=$(printf "%s\n" ${EACH_ENTRY} | base64 --decode)
  DESTINATION_COMMANDS="${DESTINATION_COMMANDS}${EACH_COMMAND}"
done

# Dynamically calculated variables
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
STAGE_BACKUP="backup_prior_to_refresh_${TIMESTAMP}.sql"
IS_SSH_AGENT_FORWARDING_ACTIVE="$( [[ ${SSH_AUTH_SOCK:-false} == false ]] && echo false || echo true )"

FLAG_CONFIG_USE_SSH_AGENT_FORWARDING=false
[[ "${CONFIG_USE_SSH_AGENT_FORWARDING}" == "true" ]] && FLAG_CONFIG_USE_SSH_AGENT_FORWARDING=true
FLAG_DESTINATION_SSH_HOST_GET_PUBLIC_IP=false
[[ "${DESTINATION_SSH_HOST_GET_PUBLIC_IP}" == "true" ]] && FLAG_DESTINATION_SSH_HOST_GET_PUBLIC_IP=true
FLAG_DESTINATION_SSH_HOST_USE_IP_OVERRIDE=false
[[ "${DESTINATION_SSH_HOST_USE_IP_OVERRIDE}" == "true" ]] && FLAG_DESTINATION_SSH_HOST_USE_IP_OVERRIDE=true

if [[ ${FLAG_DESTINATION_SSH_HOST_GET_PUBLIC_IP} == true ]]; then
  DESTINATION_SSH_HOST_IP_OVERRIDE=$(dig +short @8.8.8.8 ${DESTINATION_SSH_HOST} | tail -n1)
fi
DESTINATION_SSH_OPTIONS=""
if [[ ! -z "${DESTINATION_SSH_PORT}" ]]; then
  DESTINATION_SSH_OPTIONS+=" -p ${DESTINATION_SSH_PORT}"
fi
if [[ ${FLAG_DESTINATION_SSH_HOST_GET_PUBLIC_IP} == true || ${FLAG_DESTINATION_SSH_HOST_USE_IP_OVERRIDE} == true ]]; then
  DESTINATION_SSH_OPTIONS+=" -o HostName=${DESTINATION_SSH_HOST_IP_OVERRIDE}"
fi
DESTINATION_RSYNC_SSH_OPTIONS=""
if [[ ! -z "${DESTINATION_SSH_OPTIONS}" ]]; then
  DESTINATION_RSYNC_SSH_OPTIONS="-e \"ssh ${DESTINATION_SSH_OPTIONS}\""
fi

########################################
## Validation checks
########################################
if [[ ${FLAG_CHECK_MODE} == false ]] && [ ! -d "${SOURCE_MAGENTO_ROOT}" ]; then
    printf "${RED}The ${YELLOW}SOURCE_MAGENTO_ROOT${RED} (${SOURCE_MAGENTO_ROOT}) directory doesn't exist.${NC}\n"
    exit
fi

if [[ ${FLAG_CHECK_MODE} == false ]] \
  && [[ ${FLAG_CONFIG_USE_SSH_AGENT_FORWARDING} == true ]] \
  && [[ ${IS_SSH_AGENT_FORWARDING_ACTIVE} == false ]]; then
    printf "${RED}You need to connect with user agent forwarding. Disconnect this SSH session and then reconnect with the '-A' flag.${NC}\n"
    exit
fi

[[ ${FLAG_CHECK_MODE} == false ]] && printf "${RED}
################# IMPORTANT #################
Are you sure you want to refresh the DESTINATION environment from SOURCE?${NC}
  This will destroy any data on the DESTINATION environment and replace it with data from SOURCE.
  For more information about this command use the --help option.
  
  Only 'yes' will be accepted to approve and continue.
  
"
[[ ${FLAG_CHECK_MODE} == false ]] && read -p "  Enter a value: " -r </dev/tty
if [[ ${FLAG_CHECK_MODE} == false ]] && [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]
then
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
fi

########################################
## Refresh Commands
########################################
echo ""
echo "------------------------------------------"
echo "-- Test DESTINATION connectivity"
echo "------------------------------------------"
# Create dump of DB in the "var" directory. This will naturally get cleaned up by Capistrano once this release is purged
COMMANDS=$(cat <<COMMANDS_HEREDOC
echo "echo 'hello DESTINATION'" \
  | ssh ${DESTINATION_SSH_OPTIONS} ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST} 'bash -s'
COMMANDS_HEREDOC
)
echo "${COMMANDS}"
if [[ ${FLAG_CHECK_MODE} == false ]]; then
  set -x
  echo "echo 'hello DESTINATION'" \
    | ssh ${DESTINATION_SSH_OPTIONS} ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST} 'bash -s'
  set +x
fi

echo ""
echo "------------------------------------------"
echo "-- Backup DESTINATION database"
echo "------------------------------------------"
# Create dump of DB in the "var" directory. This will naturally get cleaned up by Capistrano once this release is purged
COMMANDS=$(cat <<COMMANDS_HEREDOC
echo "
mysqldump \
    --single-transaction \
    --no-tablespaces \
    --routines \
    --events \
    ${DESTINATION_DB_NAME} \
  | gzip > ${DESTINATION_MAGENTO_ROOT}/var/backup_prior_to_sync_from_source_${TIMESTAMP}.sql.gz
" | ssh ${DESTINATION_SSH_OPTIONS} ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST} 'bash -s'
COMMANDS_HEREDOC
)
echo -e "${COMMANDS}"
if [[ ${FLAG_CHECK_MODE} == false ]]; then
  set -x
  echo "
  mysqldump \
      --single-transaction \
      --no-tablespaces \
      --routines \
      --events \
      ${DESTINATION_DB_NAME} \
    | gzip > ${DESTINATION_MAGENTO_ROOT}/var/backup_prior_to_sync_from_source_${TIMESTAMP}.sql.gz
  " | ssh ${DESTINATION_SSH_OPTIONS} ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST} 'bash -s'
  set +x
fi

echo ""
echo "------------------------------------------"
echo "-- Pull SOURCE database schema"
echo "------------------------------------------"
COMMANDS=$(cat <<COMMANDS_HEREDOC
mysqldump \
  --single-transaction \
  --no-tablespaces \
  --no-data \
  ${SOURCE_DB_NAME} \
    | LC_ALL=C sed 's/\/\*[^*]*DEFINER=[^*]*\*\///g' \
    | gzip > ~/${SOURCE_DB_NAME}_schema_${TIMESTAMP}.sql.gz
COMMANDS_HEREDOC
)
echo -e "${COMMANDS}"
if [[ ${FLAG_CHECK_MODE} == false ]]; then
  set -x
  mysqldump \
    --single-transaction \
    --no-tablespaces \
    --no-data \
    ${SOURCE_DB_NAME} \
      | LC_ALL=C sed 's/\/\*[^*]*DEFINER=[^*]*\*\///g' \
      | gzip > ~/${SOURCE_DB_NAME}_schema_${TIMESTAMP}.sql.gz
  set +x
fi

echo ""
echo "------------------------------------------"
echo "-- Pull SOURCE database data"
echo "------------------------------------------"
echo -e "
mysqldump \
  --single-transaction \
  --no-tablespaces \
  --routines \
  --events \
  "${SOURCE_MYSQLDUMP_IGNORE_TABLES[@]}" \
  ${SOURCE_DB_NAME} \
    | LC_ALL=C sed 's/\/\*[^*]*DEFINER=[^*]*\*\///g' \
    | gzip > ~/${SOURCE_DB_NAME}_data_${TIMESTAMP}.sql.gz
"
if [[ ${FLAG_CHECK_MODE} == false ]]; then
  set -x
  mysqldump \
    --single-transaction \
    --no-tablespaces \
    --routines \
    --events \
    "${SOURCE_MYSQLDUMP_IGNORE_TABLES[@]}" \
    ${SOURCE_DB_NAME} \
      | LC_ALL=C sed 's/\/\*[^*]*DEFINER=[^*]*\*\///g' \
      | gzip > ~/${SOURCE_DB_NAME}_data_${TIMESTAMP}.sql.gz
  set +x
fi

echo ""
echo "------------------------------------------"
echo "-- Transfer SOURCE database files to DESTINATION"
echo "------------------------------------------"
echo -e rsync --progress -azv ${DESTINATION_RSYNC_SSH_OPTIONS} \
  ~/${SOURCE_DB_NAME}_schema_${TIMESTAMP}.sql.gz \
  ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST}:~/${SOURCE_DB_NAME}_schema_${TIMESTAMP}.sql.gz
echo -e rsync --progress -azv ${DESTINATION_RSYNC_SSH_OPTIONS} \
  ~/${SOURCE_DB_NAME}_data_${TIMESTAMP}.sql.gz \
  ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST}:~/${SOURCE_DB_NAME}_data_${TIMESTAMP}.sql.gz
if [[ ${FLAG_CHECK_MODE} == false ]]; then
  set -x
  rsync --progress -azv ${DESTINATION_RSYNC_SSH_OPTIONS} \
    ~/${SOURCE_DB_NAME}_schema_${TIMESTAMP}.sql.gz \
    ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST}:~/${SOURCE_DB_NAME}_schema_${TIMESTAMP}.sql.gz
  rsync --progress -azv ${DESTINATION_RSYNC_SSH_OPTIONS} \
    ~/${SOURCE_DB_NAME}_data_${TIMESTAMP}.sql.gz \
    ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST}:~/${SOURCE_DB_NAME}_data_${TIMESTAMP}.sql.gz
  set +x
fi

echo ""
echo "------------------------------------------"
echo "-- Cleanup local database files copy"
echo "------------------------------------------"
COMMANDS=$(cat <<COMMANDS_HEREDOC
rm -f ~/${SOURCE_DB_NAME}_schema_${TIMESTAMP}.sql.gz
rm -f ~/${SOURCE_DB_NAME}_data_${TIMESTAMP}.sql.gz
COMMANDS_HEREDOC
)
echo -e "${COMMANDS}"
if [[ ${FLAG_CHECK_MODE} == false ]]; then
  rm -f ~/${SOURCE_DB_NAME}_schema_${TIMESTAMP}.sql.gz
  rm -f ~/${SOURCE_DB_NAME}_data_${TIMESTAMP}.sql.gz
fi

echo ""
echo "------------------------------------------"
echo "-- Import SOURCE database files into DESTINATION database"
echo "------------------------------------------"
COMMANDS=$(cat <<COMMANDS_HEREDOC
echo "
cat ~/${SOURCE_DB_NAME}_schema_${TIMESTAMP}.sql.gz | gunzip | mysql -D ${DESTINATION_DB_NAME}
" | ssh ${DESTINATION_SSH_OPTIONS} ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST} 'bash -s'
echo "
cat ~/${SOURCE_DB_NAME}_data_${TIMESTAMP}.sql.gz | gunzip | mysql -D ${DESTINATION_DB_NAME}
" | ssh ${DESTINATION_SSH_OPTIONS} ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST} 'bash -s'
COMMANDS_HEREDOC
)
echo -e "${COMMANDS}"
if [[ ${FLAG_CHECK_MODE} == false ]]; then
  echo "
  cat ~/${SOURCE_DB_NAME}_schema_${TIMESTAMP}.sql.gz | gunzip | mysql -D ${DESTINATION_DB_NAME}
  " | ssh ${DESTINATION_SSH_OPTIONS} ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST} 'bash -s'
  echo "
  cat ~/${SOURCE_DB_NAME}_data_${TIMESTAMP}.sql.gz | gunzip | mysql -D ${DESTINATION_DB_NAME}
  " | ssh ${DESTINATION_SSH_OPTIONS} ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST} 'bash -s'
fi

echo ""
echo "------------------------------------------"
echo "-- Cleanup remote database files copy"
echo "------------------------------------------"
COMMANDS=$(cat <<COMMANDS_HEREDOC
echo "
rm -f ~/${SOURCE_DB_NAME}_schema_${TIMESTAMP}.sql.gz
" | ssh ${DESTINATION_SSH_OPTIONS} ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST} 'bash -s'
echo "
rm -f ~/${SOURCE_DB_NAME}_data_${TIMESTAMP}.sql.gz
" | ssh ${DESTINATION_SSH_OPTIONS} ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST} 'bash -s'
COMMANDS_HEREDOC
)
echo -e "${COMMANDS}"
if [[ ${FLAG_CHECK_MODE} == false ]]; then
  echo "
  rm -f ~/${SOURCE_DB_NAME}_schema_${TIMESTAMP}.sql.gz
  " | ssh ${DESTINATION_SSH_OPTIONS} ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST} 'bash -s'
  echo "
  rm -f ~/${SOURCE_DB_NAME}_data_${TIMESTAMP}.sql.gz
  " | ssh ${DESTINATION_SSH_OPTIONS} ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST} 'bash -s'
fi



echo ""
echo "------------------------------------------"
echo "-- Sync files"
echo "------------------------------------------"
for EACH_ENTRY in $(echo "${SOURCE_DIRECTORIES_TO_SYNC}" | jq -r '.[] | @base64'); do
  
  EACH_PATH=$(printf "%s\n" ${EACH_ENTRY} | base64 --decode | jq -r '.PATH')
  EACH_PATH_EXCLUSIONS=$(printf "%s\n" ${EACH_ENTRY} | base64 --decode | jq -r '.PATH_EXCLUSIONS')
  
  RSYNC_EXCLUSION_LIST=(
  )
  
  for EACH_EXCLUSION_ENTRY in $(echo "${EACH_PATH_EXCLUSIONS}" | jq -r '.[] | @base64'); do
    EACH_EXCLUSION=$(echo "${EACH_EXCLUSION_ENTRY}" | base64 --decode)
    RSYNC_EXCLUSION_LIST+=(--exclude="${EACH_EXCLUSION}")
  done

  echo -e rsync --progress -avz --no-owner --no-group --delete \
      ${DESTINATION_RSYNC_SSH_OPTIONS} \
      "${RSYNC_EXCLUSION_LIST[@]}" \
      "${SOURCE_MAGENTO_ROOT}/${EACH_PATH}/" \
      "${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST}:${DESTINATION_MAGENTO_ROOT}/${EACH_PATH}/"
  if [[ ${FLAG_CHECK_MODE} == false ]]; then
    set -x
    rsync --progress -avz --no-owner --no-group --delete \
      ${DESTINATION_RSYNC_SSH_OPTIONS} \
      "${RSYNC_EXCLUSION_LIST[@]}" \
      "${SOURCE_MAGENTO_ROOT}/${EACH_PATH}/" \
      "${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST}:${DESTINATION_MAGENTO_ROOT}/${EACH_PATH}/"
    set +x
  fi
done



echo ""
echo "------------------------------------------"
echo "-- Run additional destination commands"
echo "------------------------------------------"
export DESTINATION_COMMANDS
COMMANDS=$(cat <<COMMANDS_HEREDOC
echo -e "
cd ${DESTINATION_MAGENTO_ROOT}
$(echo -e "${DESTINATION_COMMANDS}" | perl -pe 's/"/\\"/g')
" | ssh ${DESTINATION_SSH_OPTIONS} ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST} 'bash -s'
COMMANDS_HEREDOC
)
echo -e "${COMMANDS}"
if [[ ${FLAG_CHECK_MODE} == false ]]; then
  set -x
  echo -e "
  cd ${DESTINATION_MAGENTO_ROOT}
  ${DESTINATION_COMMANDS}
  " | ssh ${DESTINATION_SSH_OPTIONS} ${DESTINATION_SSH_USER}@${DESTINATION_SSH_HOST} 'bash -s'
  set +x
fi
