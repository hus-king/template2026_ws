#!/usr/bin/env python3
"""Simulation only: Gazebo ground truth is the external vision input to PX4 EKF."""
import rospy
from gazebo_msgs.msg import ModelStates
from geometry_msgs.msg import PoseStamped
rospy.init_node('template_sim_vision')
pub=rospy.Publisher('/mavros/vision_pose/pose',PoseStamped,queue_size=1)
last=0.0
def callback(msg):
 global last
 now=rospy.Time.now()
 if now.to_sec()-last < 0.019 or 'iris' not in msg.name: return
 last=now.to_sec()
 out=PoseStamped(); out.header.stamp=now; out.header.frame_id='world'; out.pose=msg.pose[msg.name.index('iris')]; pub.publish(out)
rospy.Subscriber('/gazebo/model_states',ModelStates,callback,queue_size=1)
rospy.spin()
