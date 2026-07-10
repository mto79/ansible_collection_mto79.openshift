#!/usr/bin/env bash
#
# add_role.sh — scaffold a new role in this collection from ansible_role_template.
#
# Usage:
#   bash add_role.sh <role_name>
#   bash add_role.sh                 # prompts for the name
#
set -euo pipefail

cd "$(dirname "$0")"

TEMPLATE_REPO="https://github.com/mto79/ansible_role_template.git"

role_name="${1:-}"
if [[ -z "${role_name}" ]]; then
  read -rp "Enter role name: " role_name
fi

if ! [[ "${role_name}" =~ ^[a-z][a-z0-9_]*$ ]]; then
  echo "ERROR: invalid role name '${role_name}' (lowercase letters, digits, underscores; start with a letter)." >&2
  exit 1
fi
if [[ -e "roles/${role_name}" ]]; then
  echo "ERROR: roles/${role_name} already exists." >&2
  exit 1
fi

git clone --depth 1 "${TEMPLATE_REPO}" "roles/${role_name}"
rm -rf "roles/${role_name}/.git"

( cd "roles/${role_name}" && ROLE_IN_COLLECTION=true bash replace.sh "${role_name}" )

echo "==> Role scaffolded at roles/${role_name}"
