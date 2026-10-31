#!/usr/bin/env bash
set -e
cd /home/airhust/template2026_ws
source tools/env.sh >/dev/null
gui=false
case "${1:-}" in --gui) gui=true;; --headless|'') ;; *) echo 'Usage: tools/start_sim.sh [--gui|--headless]'; exit 2;; esac
if tmux has-session -t template2026_sim 2>/dev/null; then
  echo 'template2026_sim already exists. Use: bash tools/stop_sim.sh'; exit 1
fi
if [ "$gui" = true ]; then
  export DISPLAY="${DISPLAY:-:1001}"
  command -v vglrun >/dev/null
  if ! timeout 3 xdpyinfo >/dev/null 2>&1; then
    echo "Cannot access desktop DISPLAY=$DISPLAY. Connect NoMachine first, then retry."
    exit 1
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
# Pass the chosen GUI settings explicitly; a pre-existing tmux server can have
# an older environment than the SSH shell.
cmd="cd /home/airhust/template2026_ws; source tools/env.sh >/dev/null; export DISPLAY='${DISPLAY:-}' XAUTHORITY='${XAUTHORITY:-$HOME/.Xauthority}'; exec roslaunch -p 11411 simulation/sitl.launch gui:=$gui > validation/runtime/sitl.log 2>&1"
tmux new-session -d -s template2026_sim -n sitl "$cmd"
if ! python3 tools/check_ready.py; then
  tail -40 validation/runtime/sitl.log
  echo 'Startup failed. Stop this session with: bash tools/stop_sim.sh'
  exit 1
fi
echo 'Simulation ready. Start a task: bash tools/run_task.sh hover'
echo 'Log: /home/airhust/template2026_ws/validation/runtime/sitl.log'
