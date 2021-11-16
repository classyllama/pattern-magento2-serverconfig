#!/usr/bin/env bash

set -eu

# Move to realpath
cd $(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)



# Determine persistent and source paths
SOURCE_NAME="${PWD##*/}" # Use the current directory name
GITMAN_ROOT="../../"
PERSIST_DIR="${GITMAN_ROOT}" # Use gitman root
GITMAN_LOCATION=$(cd $(pwd -P)/../;echo ${PWD##*/})
SOURCE_DIR_FROM_PERSIST_DIR="${GITMAN_LOCATION}/${SOURCE_NAME}"

# Link from source directory to persistent directory
([[ -L persistent ]] && [ "$(readlink -- persistent)" = ${PERSIST_DIR} ]) \
  || rm -f persistent
[[ -L persistent ]] || ln -fs ${PERSIST_DIR} persistent

# Link from persistent directory to source
([[ -L persistent/source ]] && [ "$(readlink -- persistent/source)" = ${SOURCE_DIR_FROM_PERSIST_DIR} ]) \
  || rm -f persistent/source
[[ -L persistent/source ]] || ln -s ${SOURCE_DIR_FROM_PERSIST_DIR} persistent/source



# Rsync required reference files to persistent location if they don't already exist
rsync --ignore-existing -av reference/ persistent/



# Initialize customizable init script
CUST_INIT_SCRIPT="repo_init.sh"

# Check if symlink exist, otherwise create symlinks in source to default
[[ -L ${CUST_INIT_SCRIPT} ]] || ln -s default/${CUST_INIT_SCRIPT} ${CUST_INIT_SCRIPT}

# If a persistent file exists make sure the symlink matches it, otherwise delete the symlink
[[ -f persistent/${CUST_INIT_SCRIPT} ]] \
  && ( \
    ( \
      [[ -L ${CUST_INIT_SCRIPT} ]] && [ "$(readlink -- ${CUST_INIT_SCRIPT})" = persistent/${CUST_INIT_SCRIPT} ] \
    ) || rm -f ${CUST_INIT_SCRIPT} \
  )
# Check if symlink exist, otherwise, create symlinks in source to persistent
[[ -L ${CUST_INIT_SCRIPT} ]] || ln -s persistent/${CUST_INIT_SCRIPT} ${CUST_INIT_SCRIPT}

# Execute source initialization script
./${CUST_INIT_SCRIPT}
