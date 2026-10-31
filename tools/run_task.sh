#!/usr/bin/env bash
set -e
source "$(dirname -- "${BASH_SOURCE[0]}")/env.sh" >/dev/null
cd "$TEMPLATE_WS"
case "${1:-}" in hover|square|avoidance) task="$1";; *) echo 'Usage: tools/run_task.sh hover|square|avoidance'; exit 2;; esac
python3 tools/check_ready.py
python3 - <<'PY'
import rosgraph,rospy
from mavros_msgs.msg import State
pubs=dict(rosgraph.Master('/template_task_preflight').getSystemState()[0]).get('/mavros/setpoint_raw/local',[])
if pubs: raise SystemExit('An existing controller is publishing: '+str(pubs))
rospy.init_node('template_task_preflight',anonymous=True)
if rospy.wait_for_message('/mavros/state',State,timeout=5).armed:
 raise SystemExit('SITL is still armed. Stop and restart this simulation before a new task.')
PY
echo "Task: $task. Enter 1 to start, any other input to cancel."
read -r choice || exit 0
if [ "$choice" != 1 ]; then echo 'Cancelled.'; exit 0; fi
exec roslaunch -p 11411 mission acceptance.launch task:="$task" confirmed:=true
