#!/usr/bin/env bash
set -e
ws="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
run="$ws/validation/no_flight/$(date +%Y%m%d_%H%M%S)_$$"
mkdir -p "$run/dev"
for name in null zero random urandom; do touch "$run/dev/$name"; done
ln -s /proc/self/fd "$run/dev/fd"
export NO_FLIGHT_WS="$ws" NO_FLIGHT_RUN="$run" NO_FLIGHT_HOST_NETNS="$(readlink /proc/self/ns/net)"
# All mounts and networking below belong to fresh user/mount/network/PID namespaces.
unshare --user --map-root-user --net --mount --pid --fork --mount-proc bash --noprofile --norc -c '
set -e
mount --make-rprivate /
for name in null zero random urandom; do mount --bind "/dev/$name" "$NO_FLIGHT_RUN/dev/$name"; done
mount --bind "$NO_FLIGHT_RUN/dev" /dev
ip link set lo up
export PATH=/usr/bin:/bin:$PATH
source /opt/ros/noetic/setup.bash
source "$NO_FLIGHT_WS/devel/setup.bash"
export ROS_MASTER_URI=http://127.0.0.1:11311 ROS_IP=127.0.0.1
unset ROS_HOSTNAME
export ROS_HOME="$NO_FLIGHT_RUN/ros_home" ROS_LOG_DIR="$NO_FLIGHT_RUN/ros_logs"
mkdir -p "$ROS_HOME" "$ROS_LOG_DIR"
exec python3 "$NO_FLIGHT_WS/tools/no_flight_harness.py"
'
echo "Evidence: $run"
