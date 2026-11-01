#!/usr/bin/env python3
"""Mock task/entry checks inside kernel-isolated namespaces; never launch MAVROS."""
import hashlib,json,math,os,re,signal,socket,subprocess,threading,time,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(os.environ['NO_FLIGHT_WS']); OUT=Path(os.environ['NO_FLIGHT_RUN'])

def isolation():
 interfaces=[name for _,name in socket.if_nameindex()]
 assert interfaces==['lo'],interfaces
 net=os.readlink('/proc/self/ns/net')
 assert net!=os.environ['NO_FLIGHT_HOST_NETNS']
 assert set(os.listdir('/dev'))=={'null','zero','random','urandom','fd'}
 sock=socket.socket(); sock.settimeout(.5)
 try:
  sock.connect(('192.168.124.77',11311))
 except OSError as e: blocked=str(e)
 else: raise AssertionError('Host network reachable')
 finally: sock.close()
 return {'interfaces':interfaces,'visible_dev':os.listdir('/dev'),'network_namespace':net,'host_network_namespace':os.environ['NO_FLIGHT_HOST_NETNS'],'host_connection_blocked':blocked,'physical_serial_access':False,'fd_link':os.readlink('/dev/fd')}

proof=isolation(); (OUT/'isolation.json').write_text(json.dumps(proof,indent=2))
master_log=(OUT/'roscore.log').open('w')
master=subprocess.Popen(['roscore','-p','11311'],stdout=master_log,stderr=subprocess.STDOUT,start_new_session=True)
import rosgraph,rospy
from geometry_msgs.msg import Quaternion
from mavros_msgs.msg import State,PositionTarget
from mavros_msgs.srv import CommandBool,CommandBoolResponse,SetMode,SetModeResponse,CommandLong,CommandLongResponse
from nav_msgs.msg import Odometry
from sensor_msgs.msg import LaserScan
from rosgraph_msgs.msg import Log
end=time.monotonic()+20
while True:
 try: rosgraph.Master('/mock_startup').getPid(); break
 except Exception:
  if time.monotonic()>end: raise
  time.sleep(.1)
rospy.init_node('no_flight_test_harness',anonymous=True,disable_signals=True)
rospy.set_param('/use_sim_time',False)
report={'test_kind':'kernel-isolated mock feedback, not physical flight or hardware integration','isolation':proof,'binary_sha256':{},'guards':[],'missions':[]}
for name in ['hover','square','avoidance']:
 report['binary_sha256'][name]=hashlib.sha256((ROOT/'devel/lib/mission'/name).read_bytes()).hexdigest()

# Root feedback exists only in the private ROS network, for entry guard checks.
root_state=rospy.Publisher('/mavros/state',State,queue_size=1)
root_odom=rospy.Publisher('/mavros/local_position/odom',Odometry,queue_size=1)
root_scan=rospy.Publisher('/scan',LaserScan,queue_size=1)
root_control={'armed':False,'connected':False,'stale':False,'points':720}
root_sp=[]
root_sp_sub=rospy.Subscriber('/mavros/setpoint_raw/local',PositionTarget,lambda m:root_sp.append(m),queue_size=1)
stop_root=threading.Event()
def root_feedback():
 while not stop_root.is_set():
  st=State(connected=root_control['connected'],armed=root_control['armed'],mode='POSCTL'); root_state.publish(st)
  od=Odometry(); od.header.stamp=rospy.Time(0) if root_control['stale'] else rospy.Time.now(); od.pose.pose.position.z=.05; od.pose.pose.orientation.w=1; root_odom.publish(od)
  sc=LaserScan(); sc.header.stamp=rospy.Time.now(); sc.angle_min=-math.pi; sc.angle_increment=math.pi/360; sc.ranges=[5.0]*root_control['points']; root_scan.publish(sc)
  stop_root.wait(.02)
thread=threading.Thread(target=root_feedback,daemon=True); thread.start()

def guard(name,task,settings,expected):
 root_control.update(armed=False,connected=True,stale=False,points=720); root_control.update(settings); time.sleep(.15)
 result=subprocess.run(['bash',str(ROOT/'tools/run_hardware.sh'),task],input=b'0\n',stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=15)
 text=result.stdout.decode(errors='replace'); (OUT/(name+'.log')).write_text(text)
 passed=expected in text and not root_sp
 if name=='cancel': passed=passed and result.returncode==0
 else: passed=passed and result.returncode!=0
 row={'name':name,'passed':passed,'exit_code':result.returncode,'expected_message':expected,'root_setpoints':len(root_sp)}
 report['guards'].append(row); print('GUARD '+json.dumps(row),flush=True)

guard('disconnected','hover',{'connected':False},'FCU must be connected and disarmed')
guard('already_armed','hover',{'armed':True},'FCU must be connected and disarmed')
guard('stale_odometry','hover',{'stale':True},'Missing or stale odometry')
guard('wrong_scan_format','avoidance',{'points':360},'needs 720 points')
guard('cancel','hover',{},'Cancelled.')
stop_root.set(); thread.join(timeout=2)
for item in [root_state,root_odom,root_scan,root_sp_sub]: item.unregister()

class MockMission:
 def __init__(self,task):
  self.task=task; self.prefix='/bench/'+task; self.pose=[0.,0.,.05]; self.command=None
  self.armed=False; self.mode='POSCTL'; self.calls=[]; self.times=[]; self.stages=[]; self.command_samples=[]; self.errors=[]; self.stopped=threading.Event(); self.start=None
  self.state=rospy.Publisher(self.prefix+'/state',State,queue_size=1)
  self.odom=rospy.Publisher(self.prefix+'/odom',Odometry,queue_size=1)
  self.scan=rospy.Publisher(self.prefix+'/scan',LaserScan,queue_size=1)
  self.subs=[rospy.Subscriber(self.prefix+'/setpoint',PositionTarget,self.setpoint,queue_size=100),rospy.Subscriber('/rosout',Log,self.log,queue_size=100)]
  self.services=[rospy.Service(self.prefix+'/arming',CommandBool,self.arm),rospy.Service(self.prefix+'/set_mode',SetMode,self.setmode),rospy.Service(self.prefix+'/command',CommandLong,self.longcmd)]
 def arm(self,req):
  self.calls.append({'service':'fake_arming','value':req.value,'t':time.monotonic()-self.start}); self.armed=req.value
  return CommandBoolResponse(success=True,result=0)
 def setmode(self,req):
  self.calls.append({'service':'fake_set_mode','mode':req.custom_mode,'t':time.monotonic()-self.start}); self.mode=req.custom_mode
  return SetModeResponse(mode_sent=True)
 def longcmd(self,req):
  self.calls.append({'service':'fake_command_long','command':req.command}); return CommandLongResponse(success=False,result=4)
 def log(self,msg):
  match=re.search(r'mission_num = (-?\d+)',msg.msg)
  if match and msg.name=='/'+self.task:
   stage=int(match[1])
   if not self.stages or self.stages[-1]['stage']!=stage: self.stages.append({'stage':stage,'t':time.monotonic()-self.start})
 def setpoint(self,msg):
  self.command=msg; now=time.monotonic(); self.times.append(now)
  values=[msg.position.x,msg.position.y,msg.position.z,msg.velocity.x,msg.velocity.y,msg.velocity.z,msg.yaw]
  if msg.coordinate_frame!=1 or not all(math.isfinite(x) for x in values): self.errors.append('invalid_setpoint')
  if len(self.times)%4==0: self.command_samples.append({'t':now-self.start,'pose':self.pose[:],'position':values[:3],'velocity':values[3:6],'mask':msg.type_mask})
 def loop(self):
  previous=time.monotonic()
  while not self.stopped.is_set():
   now=time.monotonic(); dt=min(now-previous,.05); previous=now
   # A simulated operator switches the fake state. No real mode service exists.
   if self.start is not None and now-self.start>4: self.mode='OFFBOARD'
   m=self.command
   if m is not None and self.armed:
    pos=[m.position.x,m.position.y,m.position.z]; vel=[m.velocity.x,m.velocity.y,m.velocity.z]
    for i in range(3):
     target=0.0
     if not m.type_mask&(1<<i): target+=2.0*(pos[i]-self.pose[i])
     if not m.type_mask&(8<<i): target+=vel[i]
     self.pose[i]+=max(-.8,min(.8,target))*dt
    self.pose[2]=max(.05,self.pose[2])
   self.state.publish(State(connected=True,armed=self.armed,mode=self.mode))
   od=Odometry(); od.header.stamp=rospy.Time.now(); od.header.frame_id='odom'; od.pose.pose.position.x,od.pose.pose.position.y,od.pose.pose.position.z=self.pose; od.pose.pose.orientation.w=1; self.odom.publish(od)
   scan=LaserScan(); scan.header.stamp=rospy.Time.now(); scan.angle_min=-math.pi; scan.angle_increment=math.pi/360; scan.angle_max=math.pi-math.pi/360; scan.range_min=.15; scan.range_max=15.; scan.ranges=[5.]*720; self.scan.publish(scan)
   self.stopped.wait(.02)
 def run(self):
  launch=ET.Element('launch'); group=ET.SubElement(launch,'group')
  for source,dest in [('mavros/state','state'),('/mavros/local_position/odom','odom'),('/mavros/setpoint_raw/local','setpoint'),('mavros/cmd/arming','arming'),('mavros/set_mode','set_mode'),('mavros/cmd/command','command'),('/scan','scan')]: ET.SubElement(group,'remap',{'from':source,'to':self.prefix+'/'+dest})
  inc=ET.SubElement(group,'include',{'file':str(ROOT/'src/mission/launch/hardware.launch')})
  for key,val in [('task',self.task),('start_task','true'),('if_debug','0')]: ET.SubElement(inc,'arg',{'name':key,'value':val})
  launchfile=OUT/(self.task+'_wrapped.launch'); launchfile.write_text(ET.tostring(launch,encoding='unicode'))
  log=(OUT/(self.task+'.log')).open('w'); self.start=time.monotonic()
  t=threading.Thread(target=self.loop,daemon=True); t.start()
  process=subprocess.Popen(['roslaunch',str(launchfile)],stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
  timed_out=False; graph_ok=True
  try:
   deadline=time.monotonic()+75
   while time.monotonic()<deadline:
    pubs,subs,srvs=rosgraph.Master('/graph_audit').getSystemState()
    # The real names and all real actuation services must remain absent, even
    # though kernel isolation already prevents access to the host's network.
    if any(n.startswith('/mavros/') for n,_ in pubs+srvs): graph_ok=False; break
    if process.poll() is not None: break
    time.sleep(.1)
   else: timed_out=True
  finally:
   if process.poll() is None:
    os.killpg(process.pid,signal.SIGINT)
    try:process.wait(timeout=8)
    except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGKILL); process.wait()
   self.stopped.set(); t.join(timeout=2)
   for sub in self.subs: sub.unregister()
   for service in self.services: service.shutdown()
   for pub in [self.state,self.odom,self.scan]: pub.unregister()
   log.close()
  expected={'hover':[1,2,3],'square':[1,2,3,4,5,6],'avoidance':[1,2,3]}[self.task]
  actual=[s['stage'] for s in self.stages]
  rate=(len(self.times)-1)/(self.times[-1]-self.times[0]) if len(self.times)>1 else 0
  outcome={'task':self.task,'exit_code':process.poll(),'timed_out':timed_out,'stages':self.stages,'setpoint_count':len(self.times),'setpoint_hz':rate,'invalid_setpoints':self.errors,'graph_remapping_valid':graph_ok,'fake_service_calls':self.calls,'final_mock_pose':self.pose,'final_mock_armed':self.armed,'real_flight_validation':False,'landing_confirmation_implemented':False}
  outcome['passed_task_flow']=process.returncode==0 and not timed_out and actual==expected and not self.errors and graph_ok and 18<rate<22 and any(c['service']=='fake_arming' for c in self.calls)
  if self.task=='hover' and actual==expected: outcome['hold_seconds']=self.stages[2]['t']-self.stages[1]['t']
  (OUT/(self.task+'_telemetry.json')).write_text(json.dumps(self.command_samples,indent=2))
  (OUT/(self.task+'_result.json')).write_text(json.dumps(outcome,indent=2))
  print('MISSION '+json.dumps(outcome),flush=True); return outcome

try:
 for task in ['hover','square','avoidance']:
  report['missions'].append(MockMission(task).run())
 report['all_mock_checks_passed']=all(r['passed'] for r in report['guards']) and all(r['passed_task_flow'] for r in report['missions'])
 report['physical_actuation_services_available']=False
 report['physical_flight_or_sensor_integration_tested']=False
 report['root_control_messages']=len(root_sp)
 report['final_isolation']=isolation()
 (OUT/'summary.json').write_text(json.dumps(report,indent=2))
 print('SUMMARY '+json.dumps({'passed':report['all_mock_checks_passed'],'path':str(OUT)}),flush=True)
finally:
 rospy.signal_shutdown('mock checks complete')
 os.killpg(master.pid,signal.SIGINT)
 try:master.wait(timeout=8)
 except subprocess.TimeoutExpired:os.killpg(master.pid,signal.SIGKILL); master.wait()

raise SystemExit(0 if report.get("all_mock_checks_passed") else 1)
