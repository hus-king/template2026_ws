#!/usr/bin/env bash
set -e
source "$(dirname -- "$BASH_SOURCE")/env_hardware.sh"
ws="$TEMPLATE_WS"
task="$1"
[ -n "$task" ] || task=hover
case "$task" in hover|square|avoidance) ;; *) echo 'Usage: bash tools/start_hardware.sh hover|square|avoidance [--no-attach]'; exit 2;; esac
case "$2" in --no-attach|'') ;; *) echo 'Unknown option'; exit 2;; esac
command -v tmux >/dev/null
session=template2026_hardware
if tmux has-session -t "$session" 2>/dev/null; then
  echo "Session exists. Attach: tmux attach -t $session"
  exit 1
fi
plan=$(python3 - <<'PY'
import rosgraph
master=rosgraph.Master('/hardware_shell_plan')
try:
 pubs,_,_=master.getSystemState()
except OSError:
 print('start missing')
 raise SystemExit(0)
pubs=dict(pubs)
if pubs.get('/mavros/setpoint_raw/local'):
 raise SystemExit('A task is already publishing. Stop that task before opening another.')
if master.hasParam('/use_sim_time') and master.getParam('/use_sim_time'):
 raise SystemExit('Hardware startup requires use_sim_time=false.')
state=bool(pubs.get('/mavros/state'))
odom=bool(pubs.get('/Odometry'))
if state != odom:
 raise SystemExit('Sensor stack is partly running. Finish or stop the existing sensor startup first.')
print(('reuse' if state else 'start')+' '+('reuse' if pubs.get('/scan') else 'missing'))
PY
)
read -r sensors scan <<< "$plan"
authority="$XAUTHORITY"
[ -n "$authority" ] || authority="$HOME/.Xauthority"
printf -v setup 'cd %q; source %q; ' "$ws" "$ws/tools/env_hardware.sh"
make_command() {
  printf -v pane_command '%q ' env "DISPLAY=$DISPLAY" "XAUTHORITY=$authority" bash --noprofile --norc -c "$setup$1"
}
if [ "$sensors" = start ]; then
  make_command 'exec roslaunch fly_demo utils.launch'
else
  make_command 'echo "Using existing MAVROS and localization."; exec bash --noprofile --norc'
fi
tmux new-session -d -s "$session" -n sensors "$pane_command"
if [ "$task" = avoidance ] && [ "$scan" = missing ]; then
  make_command 'exec roslaunch mission mid360_scan.launch cloud_topic:=/cloud_registered'
  tmux new-window -t "$session" -n scan "$pane_command"
fi
make_command 'exec bash --noprofile --norc'
tmux new-window -t "$session" -n task "$pane_command"
printf -v prepared 'bash %q %q' "$ws/tools/run_hardware.sh" "$task"
# No Enter is sent: the operator must execute and confirm the task personally.
tmux send-keys -t "$session:task" -l "$prepared"
tmux select-window -t "$session:task"
echo 'Task command is prepared. Press Enter, then enter 1 when ready.'
if [ "$2" != --no-attach ]; then
  if [ -n "$TMUX" ]; then tmux switch-client -t "$session"; else tmux attach-session -t "$session"; fi
fi
