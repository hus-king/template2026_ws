# template2026_ws

ROS Noetic / PX4 SITL / Gazebo Classic 仿真任务。已验证悬停、四点巡航及空场目标追踪；降落后确认上锁仍未通过，障碍绕行未测。

## 启动

电脑需已安装 Ubuntu 20.04、ROS Noetic、Gazebo 11、MAVROS、tmux，并编译好 PX4 SITL 和 Gazebo Classic 插件。

```bash
git clone https://github.com/hus-king/template2026_ws.git ~/template2026_ws
cd ~/template2026_ws
source /opt/ros/noetic/setup.bash
rosdep install --from-paths src --ignore-src -r -y
catkin_make -j4
cp tools/local.env.example tools/local.env
```

修改 `tools/local.env` 中的 `PX4_ROOT`，填自己的 PX4 目录，然后在电脑的图形桌面终端启动：

```bash
bash tools/start_sim.sh --gui
bash tools/run_task.sh hover
```

输入 `1` 开始。`hover` 可换成 `square`（四点巡航）或 `avoidance`（空场目标追踪）。每次换任务前先重启仿真：

```bash
bash tools/stop_sim.sh
bash tools/start_sim.sh --gui
bash tools/run_task.sh square
```

停止：`bash tools/stop_sim.sh`。无图形界面时将 `--gui` 换成 `--headless`。

## 哪里需要改

| 文件 | 修改内容 |
| --- | --- |
| `tools/local.env` | `PX4_ROOT`：本机 PX4 目录；构建目录不同时设置 `PX4_BUILD_DIR` |
| `src/mission/config/hover.yaml` | 到点误差 `err_max`、自动 OFFBOARD 开关 `if_debug` |
| `src/mission/config/square.yaml` | 高度 `altitude`、四个航点 `waypoints` |
| `src/mission/config/avoidance.yaml` | 目标 `target_x/target_y`、避障半径和速度 |
| `src/template/include/template.h` | hover/avoidance 高度 `ALTITUDE` |
| `src/mission/src/hover.cpp` | 悬停时间 `hover(30.0)` |

修改 YAML 后重启任务；修改 C++/头文件后重新 `catkin_make -j4`。工作空间路径自动识别。

PX4 已验证提交：`79c55614d860d2f3e8ce775741dd96ef062c998f`；其他版本未验证。远程桌面需要 VirtualGL 时，在 `tools/local.env` 中设置 `GAZEBO_GUI_PREFIX="vglrun -d egl0 -fps 30"`。
