#!/usr/bin/env bash
set -e
source "$(dirname -- "${BASH_SOURCE[0]}")/env.sh" >/dev/null
gui=false
case "${1:-}" in --gui) gui=true;; --headless|'') ;; *) echo 'Usage: tools/start_sim.sh [--gui|--headless]'; exit 2;; esac
if tmux has-session -t template2026_sim 2>/dev/null; then
  echo 'Simulation already exists. Stop it with: bash tools/stop_sim.sh'; exit 1
fi
if [ "$gui" = true ]; then
  if [ -z "${DISPLAY:-}" ]; then echo 'DISPLAY is unset. Run in a desktop terminal, or use --headless.' >&2; exit 1; fi
  if command -v xdpyinfo >/dev/null && ! timeout 3 xdpyinfo >/dev/null 2>&1; then
    echo "Cannot access DISPLAY=$DISPLAY" >&2; exit 1
  fi
fi
python3 - <<'PY'
import socket
for kind,ports in [(socket.SOCK_STREAM,[11411,11445,4561]),(socket.SOCK_DGRAM,[14541,14581])]:
 for port in ports:
  sock=socket.socket(socket.AF_INET,kind)
  if kind==socket.SOCK_STREAM: sock.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
  try: sock.bind(('127.0.0.1',port))
  except OSError: raise SystemExit('Port already in use: '+str(port))
  finally: sock.close()
PY
printf -v cmd '%q ' env "PX4_ROOT=$PX4_ROOT" "PX4_BUILD_DIR=$PX4_BUILD_DIR" \
  "GAZEBO_GUI_PREFIX=$GAZEBO_GUI_PREFIX" "DISPLAY=${DISPLAY:-}" \
  "XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}" bash "$TEMPLATE_WS/tools/launch_sim.sh" "$gui"
tmux new-session -d -s template2026_sim -n sitl "$cmd"
if ! python3 "$TEMPLATE_WS/tools/check_ready.py"; then
  tail -40 "$ROS_HOME/sitl.log"
  echo 'Startup failed. Stop with: bash tools/stop_sim.sh'; exit 1
fi
echo 'Simulation ready. Run: bash tools/run_task.sh hover'
echo "Log: $ROS_HOME/sitl.log"
