#!/bin/zsh
# Used by acceptance.launch after the caller explicitly confirms the mission.
set -e
exec "$@" < <(printf '1\n')
