#!/usr/bin/env bash
export TEMPLATE_WS="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [ -r "$TEMPLATE_WS/tools/local.env" ]; then source "$TEMPLATE_WS/tools/local.env"; fi
export PATH=/usr/bin:/bin:$PATH
ros_setup="${ROS_SETUP:-/opt/ros/noetic/setup.bash}"
for required in "$ros_setup" "$TEMPLATE_WS/devel/setup.bash"; do
  if [ ! -r "$required" ]; then echo "Missing $required; source ROS Noetic and run catkin_make first." >&2; return 1; fi
done
source "$ros_setup"
source "$TEMPLATE_WS/devel/setup.bash"
export PX4_ROOT="${PX4_ROOT:-$HOME/PX4-Autopilot}"
export PX4_BUILD_DIR="${PX4_BUILD_DIR:-$PX4_ROOT/build/px4_sitl_default}"
if [ ! -x "$PX4_BUILD_DIR/bin/px4" ]; then
  echo "Missing PX4 SITL binary: $PX4_BUILD_DIR/bin/px4. Set PX4_ROOT in tools/local.env and build PX4 SITL." >&2
  return 1
fi
px4_setup=
for candidate in "$PX4_ROOT/Tools/simulation/gazebo/setup_gazebo.bash" "$PX4_ROOT/Tools/setup_gazebo.bash"; do
  if [ -f "$candidate" ]; then px4_setup="$candidate"; break; fi
done
if [ -z "$px4_setup" ]; then echo "Missing Gazebo Classic setup under $PX4_ROOT" >&2; return 1; fi
source "$px4_setup" "$PX4_ROOT" "$PX4_BUILD_DIR"
export ROS_PACKAGE_PATH="$ROS_PACKAGE_PATH:$PX4_ROOT"
export GAZEBO_GUI_PREFIX="${GAZEBO_GUI_PREFIX:-}"
export ROS_MASTER_URI=http://127.0.0.1:11411
export ROS_IP=127.0.0.1
export GAZEBO_MASTER_URI=http://127.0.0.1:11445
export GAZEBO_MODEL_DATABASE_URI=
export ROS_HOME="$TEMPLATE_WS/validation/runtime"
export ROS_LOG_DIR="$ROS_HOME/roslog"
mkdir -p "$ROS_HOME" "$ROS_LOG_DIR"
