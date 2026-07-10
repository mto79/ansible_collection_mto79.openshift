#!/usr/bin/env bash
#
# check_roles.sh — verify every role in this collection complies with the
# ansible_role_template structure. Run from the collection root; also runs in
# CI (.github/workflows/role-compliance.yml). Exits non-zero on any violation.
#
set -uo pipefail   # not -e: we accumulate and report all violations

cd "$(dirname "$0")"

if [[ ! -f galaxy.yml ]]; then
  echo "check_roles.sh: must run from a collection root (galaxy.yml not found)." >&2
  exit 2
fi

collection="$(awk '/^name:/{print $2; exit}' galaxy.yml)"
collection="${collection%\"}"; collection="${collection#\"}"
collection="${collection%\'}"; collection="${collection#\'}"

# Required paths every compliant role must contain.
required=(
  tasks/main.yml tasks/setup tasks/assert
  vars/main.yml defaults/main.yml handlers/main.yml meta/main.yml
  molecule/default/molecule.yml README.md requirements.txt requirements.yml
)

fail=0
shopt -s nullglob
roles=(roles/*/)
if [[ ${#roles[@]} -eq 0 ]]; then
  echo "No roles found under roles/ — nothing to check."
  exit 0
fi

for d in "${roles[@]}"; do
  role="$(basename "$d")"
  role_fail=0
  note() { echo "  ✗ $1"; role_fail=1; fail=1; }

  echo "== ${role} =="

  # 1. required paths
  for p in "${required[@]}"; do
    [[ -e "${d}${p}" ]] || note "missing ${p}"
  done

  # 2. no upstream action/scaffolding
  [[ -e "${d}tasks/upstream" ]] && note "tasks/upstream/ must be removed (upstream action is deprecated)"

  # 3. __role_name defined, not placeholder, matches <collection>_<role>
  if [[ -f "${d}vars/main.yml" ]]; then
    rn="$(awk -F'"' '/^__role_name:/{print $2; exit}' "${d}vars/main.yml")"
    if [[ -z "${rn}" ]]; then
      note "vars/main.yml: __role_name not defined"
    elif [[ "${rn}" == "template" ]]; then
      note "vars/main.yml: __role_name still set to the placeholder 'template'"
    elif [[ "${rn}" != "${collection}_${role}" ]]; then
      note "vars/main.yml: __role_name '${rn}' should be '${collection}_${role}'"
    fi
  fi

  # 4. tasks/main.yml carries the generic dispatcher (framework markers)
  if [[ -f "${d}tasks/main.yml" ]]; then
    for marker in "__role_file_search_order" "__role_action | default('setup')"; do
      grep -qF "${marker}" "${d}tasks/main.yml" || note "tasks/main.yml missing dispatcher marker: ${marker}"
    done
  fi

  # 5. var prefix convention: top-level vars in defaults/ and vars/ (except __
  #    internals) must start with "<collection>_<role>_"
  prefix="${collection}_${role}_"
  for vf in "${d}defaults/main.yml" "${d}"vars/*.yml; do
    [[ -f "${vf}" ]] || continue
    while IFS= read -r key; do
      [[ "${key}" == __* ]] && continue
      [[ "${key}" == "${prefix}"* ]] || note "$(realpath --relative-to=. "${vf}"): variable '${key}' lacks prefix '${prefix}'"
    done < <(grep -oE '^[A-Za-z_][A-Za-z0-9_]*:' "${vf}" | sed 's/:$//')
  done

  [[ ${role_fail} -eq 0 ]] && echo "  ✔ compliant"
done

echo ""
if [[ ${fail} -ne 0 ]]; then
  echo "Role compliance FAILED — fix the ✗ items above (see ansible_role_template)."
  exit 1
fi
echo "All roles comply with ansible_role_template."
