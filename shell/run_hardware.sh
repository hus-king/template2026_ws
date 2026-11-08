#!/bin/zsh
set -e
export TEMPLATE_WS="${${(%):-%x}:A:h:h}"
export ROS_MASTER_URI=http://127.0.0.1:11311 ROS_IP=127.0.0.1
case "${1:-}" in hover|square|avoidance) task="$1";; *) echo 'Usage: zsh shell/run_hardware.sh hover|square|avoidance'; exit 2;; esac
python3 "$TEMPLATE_WS/src/mission/scripts/hardware_preflight.py" "$task"
echo "Hardware task: $task. Manual OFFBOARD is required; the task can then request arming."
echo 'Enter 1 to start the task; anything else cancels.'
read -r choice || exit 0
if [ "$choice" != 1 ]; then echo 'Cancelled.'; exit 0; fi
exec roslaunch -p 11311 mission hardware.launch task:="$task" start_task:=true if_debug:=0
