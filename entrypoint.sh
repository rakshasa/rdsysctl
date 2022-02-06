#!/bin/bash

set -eux

echo "staging" > "/run/self/state"

if [ -f "/run/self/resolv.conf" ]; then
  cp "/run/self/resolv.conf" "/etc/resolv.conf"
fi

TIMEOUT=$(( SECONDS + 60 ))

while true; do
  if (( SECONDS > TIMEOUT )); then
    echo "error" > "/run/self/state"
    echo "staging_timeout" > "/run/self/error"
    exit 0
  fi

  if [ ! -f "/run/self/signal" ] || [ "$(cat "/run/self/signal")" == "stage" ]; then
    sleep 0.1
    continue
  fi

  if [ "$(cat "/run/self/signal")" != "deploy" ]; then
    echo "error" > "/run/self/state"
    echo "staging_unexpected_state" > "/run/self/error"
    exit 0
  fi

  break
done

echo "running" > "/run/self/state"

mkdir -p "/run/self/logs"

run_command() {
  unset run_child_pid
  unset run_kill_needed

  trap '
    if [[ -n "${run_child_pid}" ]]; then
      kill -TERM "${run_child_pid}" 2> /dev/null
    else
      run_kill_needed="yes"
    fi
  ' SIGTERM SIGINT

  if [[ -n "${RUN_COMMAND}" ]]; then
    eval "${RUN_COMMAND} &"
    run_child_pid=$!
  else
    # TODO: Rename.
    /run/self/run &
    run_child_pid=$!
  fi

  ( # Wait an extra time as trap can return before the child process exits.
    if [[ "${term_kill_needed}" == "yes" ]]; then
      kill -TERM "${term_child_pid}"
    fi

    wait ${term_child_pid}
    trap - SIGTERM SIGINT
    wait ${term_child_pid}
  ) 2>/dev/null

  return 0
}

if ! (run_command &> "/run/self/logs/entrypoint.log"); then
  echo "error" > "/run/self/state"
  echo "run_error" > "/run/self/error"
  exit 0
fi

echo "exited" > "/run/self/state"
