#!/usr/bin/env bash
set -e
source "$(dirname -- "${BASH_SOURCE[0]}")/env_hardware.sh"
case "${1:-}" in hover|square|avoidance) task="$1";; *) echo 'Usage: bash tools/run_hardware.sh hover|square|avoidance'; exit 2;; esac
python3 - "$task" <<'PY'
import math,sys,time
import rosgraph,rospy
from mavros_msgs.msg import State
from nav_msgs.msg import Odometry
from sensor_msgs.msg import LaserScan
master=rosgraph.Master('/hardware_preflight')
if master.hasParam('/use_sim_time') and master.getParam('/use_sim_time'):
 raise SystemExit('Refusing hardware task: use_sim_time is true.')
pubs=dict(master.getSystemState()[0]).get('/mavros/setpoint_raw/local',[])
if pubs: raise SystemExit('Another controller is publishing: '+str(pubs))
rospy.init_node('hardware_preflight',anonymous=True)
state=rospy.wait_for_message('/mavros/state',State,timeout=5)
if not state.connected or state.armed: raise SystemExit('FCU must be connected and disarmed before startup.')
odom=rospy.wait_for_message('/mavros/local_position/odom',Odometry,timeout=5)
p=odom.pose.pose.position
if not all(math.isfinite(v) for v in [p.x,p.y,p.z]) or odom.header.stamp.is_zero() or abs((rospy.Time.now()-odom.header.stamp).to_sec())>1:
 raise SystemExit('Missing or stale odometry. Start and check the localization provider first.')
if sys.argv[1]=='avoidance':
 try:
  scan=rospy.wait_for_message('/scan',LaserScan,timeout=5)
 except rospy.ROSException:
  raise SystemExit('No /scan messages. Start the sensor-only converter first: roslaunch mission mid360_scan.launch')
 if len(scan.ranges)!=720 or abs(scan.angle_increment-math.pi/360)>1e-4 or abs(scan.angle_min+math.pi)>0.02:
  raise SystemExit('This avoidance implementation needs 720 points, 0.5-degree steps, angle_min=-pi; current scan is not verified compatible.')
PY
echo "Hardware task: $task. Manual OFFBOARD is required; the task can then request arming."
echo 'Enter 1 to start the task; anything else cancels.'
read -r choice || exit 0
if [ "$choice" != 1 ]; then echo 'Cancelled.'; exit 0; fi
exec roslaunch -p 11311 mission hardware.launch task:="$task" start_task:=true if_debug:=0
