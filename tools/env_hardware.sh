#!/usr/bin/env bash
# Source from Bash or zsh; use the matching catkin setup files.
if [ -n "${ZSH_VERSION:-}" ]; then
  _template_env_file="${(%):-%x}"
  _template_setup_shell=zsh
elif [ -n "${BASH_VERSION:-}" ]; then
  _template_env_file="${BASH_SOURCE[0]}"
  _template_setup_shell=bash
else
  echo 'Source tools/env_hardware.sh from Bash or zsh.' >&2
  return 1
fi
export TEMPLATE_WS="$(cd -- "$(dirname -- "$_template_env_file")/.." && pwd -P)"
export PATH=/usr/bin:/bin:$PATH
for _template_required in "/opt/ros/noetic/setup.$_template_setup_shell" "$TEMPLATE_WS/devel/setup.$_template_setup_shell"; do
  if [ ! -r "$_template_required" ]; then
    echo "Missing setup file: $_template_required" >&2
    return 1
  fi
done
source "/opt/ros/noetic/setup.$_template_setup_shell" || return 1
for _template_base in "$HOME/uav_ws" "$HOME/livox_ws"; do
  if [ -f "$_template_base/devel/setup.$_template_setup_shell" ]; then
    source "$_template_base/devel/setup.$_template_setup_shell" --extend || return 1
  fi
done
source "$TEMPLATE_WS/devel/setup.$_template_setup_shell" --extend || return 1
export ROS_MASTER_URI=http://127.0.0.1:11311
export ROS_IP=127.0.0.1
unset ROS_HOSTNAME
unset _template_env_file _template_setup_shell _template_required _template_base
