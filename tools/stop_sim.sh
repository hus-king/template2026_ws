#!/usr/bin/env bash
set -e
if ! tmux has-session -t template2026_sim 2>/dev/null; then exit 0; fi
tmux send-keys -t template2026_sim:sitl C-c 2>/dev/null || true
for attempt in $(seq 1 15); do
 if ! tmux list-windows -t template2026_sim -F '#W' 2>/dev/null | grep -qx sitl; then break; fi
 sleep 1
done
tmux kill-session -t template2026_sim 2>/dev/null || true
