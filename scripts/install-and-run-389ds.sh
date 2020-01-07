#!/bin/bash
set -eo pipefail

export DIRSRV_HOSTNAME=${DIRSRV_HOSTNAME:-$(hostname --fqdn)}
export DIRSRV_ADMIN_USERNAME=${DIRSRV_ADMIN_USERNAME:-"admin"}
export DIRSRV_ADMIN_PASSWORD=${DIRSRV_ADMIN_PASSWORD:-${DIRSRV_MANAGER_PASSWORD:-"admin@123"}}
export DIRSRV_MANAGER_PASSWORD=${DIRSRV_MANAGER_PASSWORD:-${DIRSRV_ADMIN_PASSWORD:-"admin@123"}}
export DIRSRV_SUFFIX=${DIR_SUFFIX:-"dc=keycloak,dc=org"}
export DIRSRV_USERS_COUNT="${DIRSRV_USERS_COUNT:-1200}"
export DIRSRV_GROUPS_COUNT="${DIRSRV_GROUPS_COUNT:-300}"
export DIRSRV_MEMBERS_COUNT="${DIRSRV_MEMBERS_COUNT:-100}"

BASEDIR="/etc/dirsrv/slapd-dir"
ROOT_DN="cn=Directory Manager"
RUN_DIR="/var/run/dirsrv"
LOG_DIR="/var/log/dirsrv/slapd-dir"
LOCK_DIR="/var/lock/dirsrv/slapd-dir"

# Pre-create requested count of LDAP users & groups
dyn_generate_ldap_users_and_groups() {
  local LDIF_FILE="/tmp/users_and_groups.ldif"
  echo "Creating ${DIRSRV_USERS_COUNT} LDAP users, ${DIRSRV_GROUPS_COUNT} LDAP groups, and adding each user to be member of ${DIRSRV_MEMBERS_COUNT} groups."
  source /usr/bin/generate_x_users_and_groups.sh "${DIRSRV_USERS_COUNT}" "${DIRSRV_GROUPS_COUNT}" "${DIRSRV_MEMBERS_COUNT}" >> "${LDIF_FILE}"
  echo "LDAP users & groups created!"
}

#
# Setup DS
#
setup() {
  /bin/cp -rp /etc/dirsrv-tmpl/* /etc/dirsrv
  /sbin/setup-ds.pl -s -f /389ds-setup.inf --debug &&
  /bin/rm -f /389ds-setup.inf
}

#
# Load the example_com domain with sample users/groups
#
load_example_com() {
  # Start and run ns-slapd
  ns-slapd -D $BASEDIR && sleep 5
  ldapadd -x -c -D"$ROOT_DN" -w${DIRSRV_MANAGER_PASSWORD} -f /tmp/users_and_groups.ldif
  pkill -f ns-slapd  && sleep 5
}


if [ ! -d ${LOCK_DIR} ]; then
   mkdir -p ${RUN_DIR} && chown -R nobody:nobody ${RUN_DIR}
   mkdir -p ${LOCK_DIR} && chown -R nobody:nobody ${LOCK_DIR}
fi

if [ ! -d "$BASEDIR" ]; then
  /usr/local/bin/confd -onetime -backend env
  setup
  dyn_generate_ldap_users_and_groups
  load_example_com
fi

# Run the DIR Server
exec /usr/sbin/ns-slapd -D ${BASEDIR} -d 0
