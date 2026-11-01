#!/usr/bin/env bash
export TEMPLATE_WS="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
export PATH=/usr/bin:/bin:$PATH
source /opt/ros/noetic/setup.bash
for base in "$HOME/uav_ws" "$HOME/livox_ws"; do
  if [ -f "$base/devel/setup.bash" ]; then source "$base/devel/setup.bash" --extend; fi
done
source "$TEMPLATE_WS/devel/setup.bash" --extend
export ROS_MASTER_URI=http://127.0.0.1:11311
export ROS_IP=127.0.0.1
unset ROS_HOSTNAME
