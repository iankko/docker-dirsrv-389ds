#!/usr/bin/env bash
set -eo pipefail

# Helper script to dynamically generate USERS_COUNT LDAP users, GROUPS_COUNT
# LDAP groups, and make each user member of MEMBERS_COUNT groups
#
# Author: Jan Lieskovsky <jlieskov@redhat.com>

if [ "$#" -ne "0" ] && [ "$#" -ne "3" ]; then
  echo "Usage: $0 [USERS_COUNT] [GROUPS_COUNT] [MEMBERS_COUNT_PER_GROUP]"
  exit 1
fi

USERS_COUNT="${1:-1200}"
GROUPS_COUNT="${2:-300}"
MEMBERS_COUNT="${3:-100}"

declare -A GROUP_MEMBERS

# Create USERS_COUNT users & add each user as member of MEMBERS_COUNT groups
#
# Expand DIRSRV_SUFFIX directly rather than to rely on confd to do that to
# avoid expansion delay when generating large (more than 10k) count of users
for i in $(seq 1 "${USERS_COUNT}"); do
  echo
  echo "dn: uid=user-$i,ou=People,${DIRSRV_SUFFIX}"
  echo "objectClass: organizationalPerson"
  echo "objectClass: person"
  echo "objectClass: extensibleObject"
  echo "objectClass: uidObject"
  echo "objectClass: inetOrgPerson"
  echo "objectClass: top"
  echo "cn: user-$i-cn"
  echo "sn: user-$i-sn"
  echo "uid: user-$i"
  echo "givenName: user-$i-gn"
  echo "mail: user-$i@keycloak.org"
  echo "mobile: 0123456789"
  echo "ou: People"
  echo "userPassword: user-$i-password"
  GROUP_START_IDX="$(($i * $MEMBERS_COUNT % $GROUPS_COUNT))"
  if [ "${GROUP_START_IDX}" -eq "0" ]; then
    GROUP_START_IDX="1"
  fi
  for j in $(seq "${GROUP_START_IDX}" "$(( $GROUP_START_IDX + $MEMBERS_COUNT - 1 ))"); do
    GROUP_MEMBERS[$j]="${GROUP_MEMBERS[$j]} $i"
  #  echo "member: cn=group-$j,ou=Groups,${DIRSRV_SUFFIX}"
  done
done

# Create GROUPS_COUNT groups
#
# Expand DIRSRV_SUFFIX directly rather than to rely on confd to do that to
# avoid expansion delay when generating large (more than 10k) count of groups
for i in $(seq 1 "${GROUPS_COUNT}"); do
 echo
 echo "dn: cn=group-$i,ou=Groups,${DIRSRV_SUFFIX}"
 echo "objectClass: groupOfNames"
 echo "objectClass: top"
 echo "cn: group-$i"
 echo "ou: Groups"
 echo "description: Testing group-$i group"
 declare -a MEMBERS="( ${GROUP_MEMBERS[$i]} )"
 for m in "${MEMBERS[@]}"; do
   echo "member: uid=user-${m},ou=People,${DIRSRV_SUFFIX}"
 done
done
