#!/bin/bash

set -euo pipefail

project_root="$(cd "$(cd "$( dirname "${BASH_SOURCE[0]}" )" && git rev-parse --show-toplevel)" && pwd)"; readonly project_root
cd "${project_root}"

readonly tag_prefix="rtdo/rdsysctl"

docker_args=(
  --label "${tag_prefix}"
)
docker_targets=(
  entrypoint
  test_wait
)

set -x

for target_name in "${docker_targets[@]}"; do
  docker build "${docker_args[@]}" \
    --tag "${tag_prefix}/${target_name}" \
    --target "${target_name}" \
    .
done
