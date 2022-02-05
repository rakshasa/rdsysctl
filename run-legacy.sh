#!/bin/bash

# Run a docker container using the legacy entrypoint script and verify
# the run directory content and behavior.

set -euo pipefail

project_root="$(cd "$(cd "$( dirname "${BASH_SOURCE[0]}" )" && git rev-parse --show-toplevel)" && pwd)"; readonly project_root
cd "${project_root}"

work_dir="$(mktemp -d)"; readonly work_dir

readonly tag_prefix="rtdo/rdsysctl"
readonly name_prefix="rdo-rdsysctl"

docker_args=(
  #--rm
  --detach
  --tty
  --label "${tag_prefix}"
)

start_node() {
  local node_name="${1:?Missing argument.}"

  cd "${work_dir}/run/current/nodes"

  mkdir -p "./${node_name}"
  cd "./${node_name}"

  echo "stage" > ./signal
  echo "starting" > ./state

  docker run "${docker_args[@]}" \
    --name "${name_prefix}-${node_name}" \
    --mount "type=bind,src=${work_dir}/run/current/nodes/${node_name},dst=/run/self" \
    "${tag_prefix}/test_wait"
}

wait_state_change() {
  set +x

  local node_name="${1:?Missing argument.}"
  local from_state="${2:?Missing argument.}"
  local to_state="${3:?Missing argument.}"

  cd "${work_dir}/run/current/nodes/${node_name}"

  local timeout=$(( SECONDS + 60 ))

  while true; do
    local current_state="$(cat ./state)"

    if [[ "${current_state}" =~ ${to_state} ]]; then
      set -x
      return
    fi

    if ! [[ "${current_state}" =~ ^(${from_state})$ ]]; then
      echo "invalid state: ${current_state}" >&2
      exit 1
    fi

    if (( SECONDS > timeout )); then
      echo "state change wait timed out" >&2
      exit 1
    fi

    sleep 0.1
  done
}

set -x

./build.sh

( cd "${work_dir}"

  mkdir -p ./run/current/nodes
)

node_name="test-wait"

docker rm -f "${name_prefix}-${node_name}" || :

start_node "${node_name}"
wait_state_change "${node_name}" "starting" "staging"

echo "${node_name}: state staging"

echo "deploy" > "${work_dir}/run/current/nodes/${node_name}/signal"
wait_state_change "${node_name}" "staging" "running"

echo "${node_name}: state running"
