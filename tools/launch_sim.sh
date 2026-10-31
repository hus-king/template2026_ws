#!/usr/bin/env bash
set -e
source "$(dirname -- "${BASH_SOURCE[0]}")/env.sh" >/dev/null
exec roslaunch -p 11411 "$TEMPLATE_WS/simulation/sitl.launch" \
  gui:="${1:-false}" workspace:="$TEMPLATE_WS" px4_root:="$PX4_ROOT" \
  px4_build:="$PX4_BUILD_DIR" gui_prefix:="$GAZEBO_GUI_PREFIX" > "$ROS_HOME/sitl.log" 2>&1
