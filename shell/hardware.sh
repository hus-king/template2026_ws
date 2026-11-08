#!/bin/zsh
# 用法：zsh shell/hardware.sh hover|square|avoidance
TASK=${1:-hover}
case "$TASK" in
  hover|square|avoidance) ;;
  *) echo '任务可选：hover、square、avoidance'; exit 1 ;;
esac
cd "${0:A:h:h}"
WS=$PWD

# 已有会话时直接查看。
if tmux has-session -t template2026_hardware 2>/dev/null; then
  tmux attach-session -t template2026_hardware
  exit 0
fi

# 第一个窗口：ROS 主服务。
P_CORE=$(tmux new-session -d -s template2026_hardware -n core -P -F '#{pane_id}' 'zsh')
tmux set-option -t template2026_hardware remain-on-exit on
tmux send-keys -t "$P_CORE" 'export ROS_MASTER_URI=http://127.0.0.1:11311 ROS_IP=127.0.0.1; roscore -p 11311' C-m

# 第二个窗口：飞控连接、雷达和定位。
# fly_demo 是飞机上的驱动包；更换飞机时修改这一行。
P_SENSORS=$(tmux new-window -t template2026_hardware -n sensors -P -F '#{pane_id}' 'zsh')
tmux send-keys -t "$P_SENSORS" 'sleep 3; export ROS_MASTER_URI=http://127.0.0.1:11311 ROS_IP=127.0.0.1; roslaunch fly_demo utils.launch' C-m

# 避障额外启动点云转激光扫描。
if [ "$TASK" = avoidance ]; then
  P_SCAN=$(tmux split-window -h -t "$P_SENSORS" -P -F '#{pane_id}' 'zsh')
  tmux send-keys -t "$P_SCAN" 'sleep 6; export ROS_MASTER_URI=http://127.0.0.1:11311 ROS_IP=127.0.0.1; roslaunch mission mid360_scan.launch cloud_topic:=/cloud_registered' C-m
  tmux select-layout -t template2026_hardware:sensors tiled
fi

# 第三个窗口：任务。只填入命令，由操作者按回车并输入 1 确认。
P_TASK=$(tmux new-window -t template2026_hardware -n task -P -F '#{pane_id}' 'zsh')
tmux send-keys -t "$P_TASK" -l "cd ${(q)WS}; zsh shell/run_hardware.sh $TASK"

# 打开驱动窗口检查数据。
tmux select-window -t template2026_hardware:sensors
tmux attach-session -t template2026_hardware
