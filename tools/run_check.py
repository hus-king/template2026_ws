#!/usr/bin/env python3
"""Run one mission against this workspace's SITL and record measured feedback."""
import argparse, json, math, os, re, subprocess, time
from pathlib import Path
import rospy, rosgraph
from mavros_msgs.msg import State, ExtendedState, PositionTarget
from nav_msgs.msg import Odometry
from gazebo_msgs.msg import ModelStates
from sensor_msgs.msg import LaserScan
from rosgraph_msgs.msg import Log
from mavros_msgs.srv import SetMode
p=argparse.ArgumentParser(); p.add_argument('task',choices=['hover','square','avoidance']); p.add_argument('--timeout',type=float,default=100); a=p.parse_args()
assert os.environ.get('ROS_MASTER_URI')=='http://127.0.0.1:11411'
root=Path(__file__).resolve().parent.parent; out=root/'validation'/a.task; out.mkdir(exist_ok=True)
ready_deadline=time.monotonic()+30
while time.monotonic()<ready_deadline:
 try:
  if rosgraph.Master('/check_startup').getParam('/use_sim_time') is True: break
 except Exception: pass
 time.sleep(.1)
else: raise RuntimeError('Simulation master did not enable simulated time')
rospy.init_node('check_'+a.task,anonymous=True)
latest={}; stages=[]; sp_times=[]; scan_counts=set(); samples=[]
def state(m): latest.update(state={'connected':m.connected,'armed':m.armed,'mode':m.mode})
def ext(m): latest['landed_state']=m.landed_state
def odom(m):
 q=m.pose.pose.position; latest['odom']=[q.x,q.y,q.z]
def truth(m):
 if 'iris' in m.name:
  q=m.pose[m.name.index('iris')].position; latest['truth']=[q.x,q.y,q.z]
def sp(m):
 sp_times.append(rospy.Time.now().to_sec()); latest['setpoint']={'position':[m.position.x,m.position.y,m.position.z],'velocity':[m.velocity.x,m.velocity.y,m.velocity.z],'mask':m.type_mask}
def scan(m):
 scan_counts.add(len(m.ranges)); finite=[r for r in m.ranges if math.isfinite(r)]; latest['scan_min']=min(finite) if finite else None
def log(m):
 match=re.search(r'mission_num = (\d+)',m.msg)
 if match and (not stages or stages[-1]['stage']!=int(match[1])): stages.append({'stage':int(match[1]),'t':m.header.stamp.to_sec()})
subs=[rospy.Subscriber('/mavros/state',State,state),rospy.Subscriber('/mavros/extended_state',ExtendedState,ext),rospy.Subscriber('/mavros/local_position/odom',Odometry,odom),rospy.Subscriber('/gazebo/model_states',ModelStates,truth),rospy.Subscriber('/mavros/setpoint_raw/local',PositionTarget,sp),rospy.Subscriber('/scan',LaserScan,scan),rospy.Subscriber('/rosout',Log,log)]
deadline=time.monotonic()+40
while time.monotonic()<deadline:
 if latest.get('state',{}).get('connected') and 'odom' in latest and 'truth' in latest and latest.get('landed_state')==1 and scan_counts: break
 time.sleep(.1)
else: raise RuntimeError('SITL not ready: '+str(latest))
master=rosgraph.Master(rospy.get_name())
def publishers(): return dict(master.getSystemState()[0]).get('/mavros/setpoint_raw/local',[])
assert not publishers(), 'Another controller is publishing'
initial=json.loads(json.dumps(latest)); subprocess.run(['rosparam','load',str(root/'src/mission/config'/(a.task+'.yaml'))],check=True)
logfile=(out/'mission.log').open('w'); proc=subprocess.Popen(['rosrun','mission',a.task,'__name:='+a.task],stdin=subprocess.PIPE,stdout=logfile,stderr=subprocess.STDOUT); proc.stdin.write(b'1\n'); proc.stdin.close()
start=time.monotonic(); timed_out=False; seen_publishers=set()
with (out/'telemetry.jsonl').open('w') as f:
 while time.monotonic()-start<a.timeout:
  row=json.loads(json.dumps(latest)); row.update(t=rospy.Time.now().to_sec(),wall_elapsed=time.monotonic()-start); samples.append(row); f.write(json.dumps(row)+'\n'); f.flush()
  if len(samples)%10==0: seen_publishers.update(publishers())
  if proc.poll() is not None: break
  time.sleep(.1)
 else:
  timed_out=True; proc.terminate(); proc.wait(timeout=8)
 # Gather actual landing confirmation separately from the mission's timer.
 end=time.monotonic()+20
 while time.monotonic()<end:
  row=json.loads(json.dumps(latest)); row.update(t=rospy.Time.now().to_sec(),wall_elapsed=time.monotonic()-start); samples.append(row); f.write(json.dumps(row)+'\n')
  if latest.get('landed_state')==1 and not latest.get('state',{}).get('armed'): break
  time.sleep(.2)
if latest.get('state',{}).get('armed'):
 rospy.ServiceProxy('/mavros/set_mode',SetMode)(custom_mode='AUTO.LAND')
result={'task':a.task,'telemetry_clock':'simulated' if rospy.get_param('/use_sim_time',False) and rospy.Time.now().to_sec()<1000000000 else 'wall','exit_code':proc.poll(),'timed_out':timed_out,'initial':initial,'final':latest,'stages':stages,'scan_lengths':sorted(scan_counts),'setpoint_publishers':sorted(seen_publishers),'setpoint_count':len(sp_times),'setpoint_hz':(len(sp_times)-1)/(sp_times[-1]-sp_times[0]) if len(sp_times)>1 else 0,'max_truth_z':max(x['truth'][2] for x in samples if 'truth'in x),'observed_offboard_armed':any(x.get('state',{}).get('armed') and x.get('state',{}).get('mode')=='OFFBOARD' for x in samples),'landed_and_disarmed':latest.get('landed_state')==1 and not latest.get('state',{}).get('armed'),'collision_test': 'not_run_empty_world','localization_source':'Gazebo ground truth -> MAVROS vision_pose -> PX4 EKF -> MAVROS local odometry'}
if a.task=='square':
 origin=initial['odom']; result['waypoint_min_errors_m']=[min(math.dist(x['odom'],[origin[0]+dx,origin[1]+dy,origin[2]+1.4]) for x in samples if 'odom'in x) for dx,dy in [(0,0),(1,0),(1,1),(0,1)]]
if a.task=='hover':
 hold=[x for x in samples if 'odom'in x and len(stages)>=2 and stages[1]['t']<=x['t']<(stages[2]['t'] if len(stages)>2 else float('inf'))]; result['hold_samples']=len(hold)
 if hold: result['hold_odom_z_range']=[min(x['odom'][2] for x in hold),max(x['odom'][2] for x in hold)]; result['hold_duration_sim_s']=hold[-1]['t']-hold[0]['t']
(out/'result.json').write_text(json.dumps(result,indent=2)); print(json.dumps(result,indent=2))
