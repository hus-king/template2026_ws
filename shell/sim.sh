#!/bin/zsh
# 用法：./shell/sim.sh [hover|square|avoidance]
TASK=${1:-hover}
case "$TASK" in
  hover|square|avoidance) ;;
  *) echo '任务可选：hover、square、avoidance'; exit 1 ;;
esac
cd "${0:A:h:h}"
WS=$PWD
PX4_ROOT=$HOME/PX4-Autopilot
PX4_BUILD_DIR=$PX4_ROOT/build/px4_sitl_default
GUI=true

# 已启动时直接进入会话。
if tmux has-session -t template2026_sim 2>/dev/null; then
  tmux attach-session -t template2026_sim
  exit 0
fi

# 第一个窗口：独立 ROS 主服务，使用仿真专用端口。
P_CORE=$(tmux new-session -d -s template2026_sim -n simulation -P -F '#{pane_id}' zsh)
tmux set-option -t template2026_sim remain-on-exit on
tmux send-keys -t "$P_CORE" 'export ROS_MASTER_URI=http://127.0.0.1:11411 ROS_IP=127.0.0.1; roscore -p 11411' C-m

# 第二个面板：PX4、Gazebo、MAVROS 和仿真定位。
P_SIM=$(tmux split-window -h -t "$P_CORE" -P -F '#{pane_id}' zsh)
tmux send-keys -t "$P_SIM" "sleep 3; cd ${(q)WS}; export ROS_MASTER_URI=http://127.0.0.1:11411 ROS_IP=127.0.0.1 GAZEBO_MASTER_URI=http://127.0.0.1:11445 TEMPLATE_WS=${(q)WS}; roslaunch -p 11411 src/mission/simulation/sitl.launch gui:=$GUI workspace:=${(q)WS} px4_root:=${(q)PX4_ROOT} px4_build:=${(q)PX4_BUILD_DIR}" C-m
tmux select-layout -t template2026_sim:simulation tiled

# 第二个窗口：等待仿真反馈就绪，再运行所选任务。
P_TASK=$(tmux new-window -t template2026_sim -n task -P -F '#{pane_id}' zsh)
tmux send-keys -t "$P_TASK" "sleep 5; cd ${(q)WS}; export ROS_MASTER_URI=http://127.0.0.1:11411 ROS_IP=127.0.0.1; python3 src/mission/scripts/check_ready.py && roslaunch -p 11411 mission acceptance.launch task:=$TASK confirmed:=true" C-m

tmux select-window -t template2026_sim:simulation
tmux attach-session -t template2026_sim
