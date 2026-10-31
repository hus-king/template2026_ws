# template2026_ws：ROS 1 / PX4 仿真任务

本包提供三个 ROS 1 / MAVROS 飞行任务：定点悬停 `hover`、四点巡航 `square` 和雷达避障 `avoidance`。公共控制函数位于 [template.h](src/template/include/template.h)，避障算法位于 [avoidance.h](src/template/include/avoidance.h)。

## 文件与任务

| 任务 | 源码 | 启动文件 | 参数文件 | 执行流程 |
| --- | --- | --- | --- | --- |
| hover | [hover.cpp](src/mission/src/hover.cpp) | [hover.launch](src/mission/launch/hover.launch) | [hover.yaml](src/mission/config/hover.yaml) | 起飞 → 悬停 30 秒 → 降落 |
| square | [square.cpp](src/mission/src/square.cpp) | [square.launch](src/mission/launch/square.launch) | [square.yaml](src/mission/config/square.yaml) | 起飞 → 依次到达四个航点 → 在最后一个航点附近降落 |
| avoidance | [avoidance.cpp](src/mission/src/avoidance.cpp) | [avoidance.launch](src/mission/launch/avoidance.launch) | [avoidance.yaml](src/mission/config/avoidance.yaml) | 起飞 → 追踪目标并躲避障碍 → 距目标小于 0.3 米时降落 |

三个节点均以 20 Hz 发布控制指令。源码启动后会提示 `1 to go on , else to quit`，输入 `1` 继续，其他值退出；随后等待飞控连接，并执行模式切换和解锁逻辑。

## 仿真可用状态

194 服务器上的仿真环境已可用，已完成 ROS 编译、Gazebo 图形界面启动及三个任务的空场仿真运行。使用下方脚本即可启动验收。

| 检查项 | 实际结果 |
| --- | --- |
| 编译 | `template`、`hover`、`square`、`avoidance` 四个目标编译通过 |
| Gazebo / MAVROS | 图形界面可打开，飞控连接、里程计和 720 点激光扫描正常 |
| hover | 进入 OFFBOARD、解锁起飞，完成约 30 秒悬停 |
| square | 依次到达四个航点，记录到的最近三维位置误差均小于 0.08 m |
| avoidance | 空场中运行到目标附近并进入降落阶段，尚未验证障碍绕行 |
| 降落闭环 | 未通过：任务按计时退出后，飞控仍未确认落地并上锁 |
| 实机飞行 | 未测试 |

仿真启动和任务运行已验证，完整降落流程仍有待修复。测试结果保存在 [docs/validation/2026-10-31](docs/validation/2026-10-31/)。

## 在 194 上启动

### 1. SSH 连接并建立远程桌面隧道

在 Windows PowerShell 中执行，连接后保持终端开启：

```powershell
ssh -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -L 14000:127.0.0.1:4000 -p 19422 airhust@airhust.cn
```

打开 NoMachine，协议选择 **NX**，主机填写 `127.0.0.1`，端口填写 `14000`，登录 `airhust` 桌面。

### 2. 启动仿真和 Gazebo 画面

在 SSH 终端执行：

```bash
cd /home/airhust/template2026_ws
bash tools/start_sim.sh --gui
```

脚本等待 MAVROS 连接、有效里程计、720 点激光扫描和运行中的仿真时钟。出现 `Simulation ready` 后再启动任务。

`--gui` 使用当前终端的 `DISPLAY`；SSH 中没有 `DISPLAY` 时，默认使用已验证的 NoMachine 桌面 `:1001`。只需要后台仿真时可以使用 `--headless`。

### 3. 选择一个任务运行

悬停：

```bash
bash tools/run_task.sh hover
```

出现提示后输入 **`1`** 开始，其他输入取消。随后程序自动请求 OFFBOARD 和解锁，在 Gazebo 中观察起飞、悬停和降落阶段。

每次换任务前先停止并重启仿真。例如验收四点巡航：

```bash
bash tools/stop_sim.sh
bash tools/start_sim.sh --gui
bash tools/run_task.sh square
```

空场目标追踪测试：

```bash
bash tools/stop_sim.sh
bash tools/start_sim.sh --gui
bash tools/run_task.sh avoidance
```

三个任务共用 `/mavros/setpoint_raw/local`，每次只运行一个。启动脚本发现已有控制节点或飞控仍处于解锁状态时会拒绝启动新任务。

### 4. 停止仿真

```bash
bash tools/stop_sim.sh
```

脚本关闭本工作空间的 `template2026_sim` 会话。每次任务运行后重新启动仿真，可清除上次任务的飞控状态和模型位置。

## 编译与环境

当前验证环境为 Ubuntu 20.04.6、ROS Noetic、Gazebo 11.15.1；服务器已准备好 MAVROS、PX4 SITL 和 VirtualGL。需要重新编译时执行：

```bash
cd /home/airhust/template2026_ws
source /opt/ros/noetic/setup.bash
catkin_make -j4
```

当前仿真脚本按 194 的目录配置：

- 本工作空间：`/home/airhust/template2026_ws`
- 已有 PX4：`/home/husking/PX4-Autopilot`，提交 `79c55614d860d2f3e8ce775741dd96ef062c998f`
- PX4 构建目录：`/home/husking/PX4-Autopilot/build/px4_sitl_default`

在其他机器部署时，需要先准备相同的 ROS/PX4/Gazebo 依赖，并调整 [tools/env.sh](tools/env.sh)、启动脚本和 launch 中的路径；当前版本未提供通用的一键安装脚本。

## sh 与 launch 入口

| 文件 | 用途 |
| --- | --- |
| [start_sim.sh](tools/start_sim.sh) | 启动独立仿真，可选择 Gazebo 图形界面，等待反馈就绪 |
| [run_task.sh](tools/run_task.sh) | 检查飞控和控制话题，输入 `1` 后通过 launch 启动任务 |
| [stop_sim.sh](tools/stop_sim.sh) | 停止本工作空间的仿真会话 |
| [sitl.launch](simulation/sitl.launch) | 启动 PX4、MAVROS、Gazebo、模拟视觉定位及可选 GUI |
| [acceptance.launch](src/mission/launch/acceptance.launch) | 按 `task` 参数选择任务，并向原程序提供启动输入 |
| [check_ready.py](tools/check_ready.py) | 检查飞控连接、里程计、扫描数据和仿真时钟 |

需要直接使用 launch 时，先在一个终端启动仿真：

```bash
cd /home/airhust/template2026_ws
source tools/env.sh
export DISPLAY="${DISPLAY:-:1001}"
roslaunch -p 11411 simulation/sitl.launch gui:=true
```

在另一个 SSH 终端启动任务：

```bash
cd /home/airhust/template2026_ws
source tools/env.sh
roslaunch -p 11411 mission acceptance.launch task:=hover confirmed:=true
```

`task` 可以是 `hover`、`square`、`avoidance`。`confirmed:=true` 代表明确启动任务，会直接进入程序的 OFFBOARD/解锁流程；普通验收推荐使用带就绪检查和输入确认的 `run_task.sh`。直接运行仿真 launch 时，在它的终端按 `Ctrl+C` 停止。

## 仿真数据链路

```text
Gazebo 模型真值 → MAVROS vision_pose → PX4 EKF
  → MAVROS local_position/odom → 任务节点
  → MAVROS setpoint_raw/local → PX4 → Gazebo
```

当前空场景为 [empty.world](simulation/empty.world)。本地仿真机型关闭了未使用的相机/Livox，加入 20 Hz、720 点、0.5 度间隔的二维激光扫描，以匹配现有避障代码。模拟定位来自 Gazebo 真值，真实环境中的定位误差和遮挡不在本次验证范围内。

仿真使用独立接口：ROS master `11411`、Gazebo master `11445`、PX4 实例 `1`、MAVLink system ID `2`，MAVROS UDP `14541` 对接 PX4 `14581`。

本机完整运行日志保存在 `validation/`，该目录不提交到 Git；仓库只保留小体积结果摘要。启动日志为 `validation/runtime/sitl.log`，任务 ROS 日志为 `validation/runtime/roslog/`。

## hover 配置

`hover.yaml` 当前内容：

```yaml
err_max: 0.15
if_debug: 1
```

- `err_max`：到点判断的每轴位置误差阈值，单位为米；公共函数还要求航向误差小于 0.1 弧度。
- `if_debug`：`1` 表示自动请求 OFFBOARD；`0` 表示等待遥控器切换。解锁请求另有逻辑，设为 `0` 不等于关闭自动解锁。

hover 的起飞高度由 `template.h` 中的 `ALTITUDE` 指定，当前为 1.4 米；悬停时间在 `hover.cpp` 中为 30 秒。这两项目前未接入 hover 的 YAML。

## square 配置

`square.yaml` 当前内容：

```yaml
err_max: 0.15
if_debug: 1

# 起飞和四个航点的统一高度 [m]
altitude: 1.4

waypoints:
  "0":
    x: 0.0
    y: 0.0
  "1":
    x: 1.0
    y: 0.0
  "2":
    x: 1.0
    y: 1.0
  "3":
    x: 0.0
    y: 1.0
```

`altitude` 是相对记录的初始位置的高度，单位为米。`waypoints/0`～`waypoints/3` 的 `x`、`y` 是相对该初始位置、沿本地坐标轴的偏移，单位为米；坐标不会随初始航向旋转。初始位置由公共里程计回调在首次收到 `z != 0` 的位置时记录。

默认路线为：

```text
起飞至 (0, 0, 1.4)
  → 航点 0 (0, 0, 1.4)
  → 航点 1 (1, 0, 1.4)
  → 航点 2 (1, 1, 1.4)
  → 航点 3 (0, 1, 1.4)
  → 降落
```

高度及四个航点的源码默认值与上述 YAML 一致，参数缺失时使用这些默认值。`err_max` 和 `if_debug` 的含义与 hover 相同，但这两项源码读取时的回退值均为 `0`，需要确保 YAML 正确加载。

航点数量固定为四个，按编号顺序执行，到点后进入下一阶段，航向目标始终为 `0`。当前路线飞过正方形的三条边，最后直接降落，没有返回航点 0 的闭合段。起飞阶段仍先飞到相对初始位置的 `(0,0)`，之后才执行可配置的航点 0。

## avoidance 配置

| 参数 | 当前 YAML 值 | 含义 |
| --- | --- | --- |
| `target_x` | `1.0` | 目标本地 ENU 坐标 X，单位 m |
| `target_y` | `0.0` | 目标本地 ENU 坐标 Y，单位 m |
| `R_outside` | `1.6` | 进入避障的外圈半径，单位 m |
| `R_inside` | `0.8` | 加强避障的内圈半径，单位 m |
| `p_xy` | `0.5` | 目标追踪位置比例系数 |
| `vel_track_max` | `0.25` | 追踪速度分量限幅，单位 m/s |
| `p_R` | `0.6` | 外圈避障比例系数 |
| `p_r` | `1.2` | 内圈避障比例系数 |
| `vel_collision_max` | `0.30` | 避障速度分量限幅，单位 m/s；随后还会加入随机扰动 |
| `vel_sp_max` | `0.30` | 最终 XY 速度分量限幅，单位 m/s |
| `range_min` | `0` | 雷达处理起始角度，单位度 |
| `range_max` | `359` | 雷达处理结束角度，单位度 |
| `if_debug` | `1` | 自动请求 OFFBOARD；源码回退值为 `0` |

除 `if_debug` 外，上述 YAML 值均与源码读取时的默认值一致。目标坐标直接与本地里程计比较，不叠加初始位置。避障阶段使用 XY 速度控制及 Z 位置控制，Z 目标直接设置为 `ALTITUDE = 1.4`；它与起飞阶段叠加初始 Z 的处理有所不同。

雷达处理当前按 720 个采样点、每度两个采样点及固定半圈移位实现。接入不同点数或角度排列的 `/scan` 前，需要修改索引处理；`range_min`、`range_max` 不能替代扫描格式适配。

## 话题与服务

| 接口 | 用途 |
| --- | --- |
| `mavros/state` | 订阅飞控连接、模式和解锁状态 |
| `/mavros/local_position/odom` | 订阅本地位置与姿态 |
| `/scan` | avoidance 订阅 `sensor_msgs/LaserScan` |
| `/mavros/setpoint_raw/local` | 发布 `mavros_msgs/PositionTarget` |
| `mavros/set_mode` | 请求 OFFBOARD 模式 |
| `mavros/cmd/arming` | 请求解锁 |

## 本版修复与剩余问题

已修复影响编译和启动的问题：清理未使用的 `QR_node`、`yolov8_ros_msgs`、`cloud_recognition` 等依赖，补齐实际消息依赖；移除缺少源码的 `test_servo` 编译目标；补齐 `avoidance.cpp` 的变量及 `case 2` 作用域；修正 hover/template 的节点名和 YAML 参数加载范围。

公共控制函数和原任务状态机保留。当前仍有以下限制：

- `precision_land()` 将本地 Z 目标设为 `-0.15`，约 5 秒后按计时返回完成，没有检查落地状态，也没有主动发送上锁请求。本次三个任务接触地面后，PX4 仍报告解锁/未落地；节点退出后出现 OFFBOARD 丢失、无效设定值及失控保护告警，因此降落闭环不能判为通过。
- 降落时的掩码 `960` 仍启用速度字段，avoidance 进入降落时会保留上一阶段的 XY 速度。
- 当前只验证空场中的目标追踪，未验证有障碍物时的绕行和碰撞情况。激光代码依赖 720 点扫描格式。
- square 飞过三个边后在航点 3 附近降落，没有返回航点 0 的闭合段。
- 仿真可用不代表已完成实机验证。
