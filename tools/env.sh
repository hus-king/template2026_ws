#!/usr/bin/env bash
export PATH=/usr/bin:/bin:$PATH
source /opt/ros/noetic/setup.bash
source /home/airhust/template2026_ws/devel/setup.bash
source /home/husking/PX4-Autopilot/Tools/simulation/gazebo/setup_gazebo.bash /home/husking/PX4-Autopilot /home/husking/PX4-Autopilot/build/px4_sitl_default
export ROS_PACKAGE_PATH="$ROS_PACKAGE_PATH:/home/husking/PX4-Autopilot"
export ROS_MASTER_URI=http://127.0.0.1:11411
export ROS_IP=127.0.0.1
export GAZEBO_MASTER_URI=http://127.0.0.1:11445
export GAZEBO_MODEL_DATABASE_URI=
export ROS_HOME=/home/airhust/template2026_ws/validation/runtime
export ROS_LOG_DIR=/home/airhust/template2026_ws/validation/runtime/roslog
mkdir -p "$ROS_HOME" "$ROS_LOG_DIR"
