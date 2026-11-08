#!/bin/zsh
set -e

# 创建会话和第一个窗口。
tmux new-session -d -s ros_session -n main_nodes zsh
tmux set-window-option -t ros_session:main_nodes pane-base-index 0

# Pane 0：ROS 主服务。
tmux send-keys -t ros_session:main_nodes.0 'roscore' C-m

# Pane 1：飞控连接、雷达和定位。
tmux split-window -h -t ros_session:main_nodes.0 zsh
tmux send-keys -t ros_session:main_nodes.1 'sleep 3; roslaunch fly_demo utils.launch' C-m

# Pane 2：hover 任务，程序提示后由操作者输入 1。
tmux split-window -h -t ros_session:main_nodes.1 zsh
tmux send-keys -t ros_session:main_nodes.2 'sleep 8; roslaunch mission hover.launch' C-m

# 整理分屏并打开会话。
tmux select-layout -t ros_session:main_nodes tiled
tmux attach-session -t ros_session
