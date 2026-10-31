#!/usr/bin/env python3
"""Verify the dedicated simulator is connected and publishing fresh feedback."""
import os,time
import rosgraph,rospy
from mavros_msgs.msg import State
from nav_msgs.msg import Odometry
from sensor_msgs.msg import LaserScan
assert os.environ.get('ROS_MASTER_URI')=='http://127.0.0.1:11411'
deadline=time.monotonic()+45
while time.monotonic()<deadline:
 try:
  if rosgraph.Master('/template_ready').getParam('/use_sim_time') is True: break
 except Exception: pass
 time.sleep(.2)
else: raise SystemExit('Simulation master did not become ready')
rospy.init_node('template_ready',anonymous=True,disable_signals=True)
latest={}
def state(m): latest.update(connected=m.connected,armed=m.armed)
def odom(m): latest['odom_wall']=time.monotonic()
def scan(m): latest.update(scan_wall=time.monotonic(),points=len(m.ranges))
subs=[rospy.Subscriber('/mavros/state',State,state),rospy.Subscriber('/mavros/local_position/odom',Odometry,odom),rospy.Subscriber('/scan',LaserScan,scan)]
while time.monotonic()<deadline:
 now=time.monotonic()
 if latest.get('connected') and now-latest.get('odom_wall',0)<1 and now-latest.get('scan_wall',0)<1 and latest.get('points')==720 and rospy.Time.now().to_sec()>10:
  print('MAVROS connected; fresh odometry; /scan 720 points; simulator clock running.')
  raise SystemExit(0)
 time.sleep(.2)
raise SystemExit('Simulator feedback not ready: '+str(latest))
