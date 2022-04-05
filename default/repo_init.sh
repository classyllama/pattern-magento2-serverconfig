#!/usr/bin/env bash

set -eu

# This file is commonly called during 'gitman install' and executed by the giman_init.sh script inside the source repo when it is created or updated by gitman

# Verify if persistent directory symlink exists
[[ -L persistent ]] || (echo "ERROR: This script is expected to be called by gitman_init.sh during 'gitman install' from the source directory." && exit 1)

# If this file is copied into the persistent directory the gitman_init.sh script will link to the custom script in the persistent directory instead of the default one contained in the repo, and that will allow for custom defined initialization steps.


echo "Initializing Source/Persistent Additional Steps"
# Create symlinks in persistent to source files
# [[ -L persistent/README.md ]] || ln -s source/README.md persistent/README.md


# Create symlinks in source to persistent files
#SYMLINK_PATH="ansible/ansible.cfg"
#TARGET_PATH="../persistent/ansible.cfg"
#([[ -L ${SYMLINK_PATH} ]] && [ "$(readlink -- ${SYMLINK_PATH})" = ${TARGET_PATH} ]) \
#  || rm -f ${SYMLINK_PATH}
#[[ -L ${SYMLINK_PATH} ]] || ln -s ${TARGET_PATH} ${SYMLINK_PATH}

SYMLINK_PATH="ansible/inventories"
TARGET_PATH="../persistent/inventories"
([[ -L ${SYMLINK_PATH} ]] && [ "$(readlink -- ${SYMLINK_PATH})" = ${TARGET_PATH} ]) \
  || rm -f ${SYMLINK_PATH}
[[ -L ${SYMLINK_PATH} ]] || ln -s ${TARGET_PATH} ${SYMLINK_PATH}

SYMLINK_PATH="ansible/group_vars"
TARGET_PATH="../persistent/group_vars"
([[ -L ${SYMLINK_PATH} ]] && [ "$(readlink -- ${SYMLINK_PATH})" = ${TARGET_PATH} ]) \
  || rm -f ${SYMLINK_PATH}
[[ -L ${SYMLINK_PATH} ]] || ln -s ${TARGET_PATH} ${SYMLINK_PATH}

SYMLINK_PATH="ansible/host_vars"
TARGET_PATH="../persistent/host_vars"
([[ -L ${SYMLINK_PATH} ]] && [ "$(readlink -- ${SYMLINK_PATH})" = ${TARGET_PATH} ]) \
  || rm -f ${SYMLINK_PATH}
[[ -L ${SYMLINK_PATH} ]] || ln -s ${TARGET_PATH} ${SYMLINK_PATH}

# Create symlinks in source to simplify paths in files
SYMLINK_PATH="ansible/persistent"
TARGET_PATH="../persistent"
([[ -L ${SYMLINK_PATH} ]] && [ "$(readlink -- ${SYMLINK_PATH})" = ${TARGET_PATH} ]) \
  || rm -f ${SYMLINK_PATH}
[[ -L ${SYMLINK_PATH} ]] || ln -s ${TARGET_PATH} ${SYMLINK_PATH}

SYMLINK_PATH="ansible/playbooks/persistent"
TARGET_PATH="../../persistent"
([[ -L ${SYMLINK_PATH} ]] && [ "$(readlink -- ${SYMLINK_PATH})" = ${TARGET_PATH} ]) \
  || rm -f ${SYMLINK_PATH}
[[ -L ${SYMLINK_PATH} ]] || ln -s ${TARGET_PATH} ${SYMLINK_PATH}

SYMLINK_PATH="ansible/playbooks/group_vars"
TARGET_PATH="../persistent/group_vars"
([[ -L ${SYMLINK_PATH} ]] && [ "$(readlink -- ${SYMLINK_PATH})" = ${TARGET_PATH} ]) \
  || rm -f ${SYMLINK_PATH}
[[ -L ${SYMLINK_PATH} ]] || ln -s ${TARGET_PATH} ${SYMLINK_PATH}

SYMLINK_PATH="ansible/playbooks/host_vars"
TARGET_PATH="../persistent/host_vars"
([[ -L ${SYMLINK_PATH} ]] && [ "$(readlink -- ${SYMLINK_PATH})" = ${TARGET_PATH} ]) \
  || rm -f ${SYMLINK_PATH}
[[ -L ${SYMLINK_PATH} ]] || ln -s ${TARGET_PATH} ${SYMLINK_PATH}

SYMLINK_PATH="ansible/playbooks/vars"
TARGET_PATH="../vars"
([[ -L ${SYMLINK_PATH} ]] && [ "$(readlink -- ${SYMLINK_PATH})" = ${TARGET_PATH} ]) \
  || rm -f ${SYMLINK_PATH}
[[ -L ${SYMLINK_PATH} ]] || ln -s ${TARGET_PATH} ${SYMLINK_PATH}

SYMLINK_PATH="ansible/playbooks/tasks"
TARGET_PATH="../tasks"
([[ -L ${SYMLINK_PATH} ]] && [ "$(readlink -- ${SYMLINK_PATH})" = ${TARGET_PATH} ]) \
  || rm -f ${SYMLINK_PATH}
[[ -L ${SYMLINK_PATH} ]] || ln -s ${TARGET_PATH} ${SYMLINK_PATH}

SYMLINK_PATH="ansible/playbooks/files"
TARGET_PATH="../persistent/files"
([[ -L ${SYMLINK_PATH} ]] && [ "$(readlink -- ${SYMLINK_PATH})" = ${TARGET_PATH} ]) \
  || rm -f ${SYMLINK_PATH}
[[ -L ${SYMLINK_PATH} ]] || ln -s ${TARGET_PATH} ${SYMLINK_PATH}
