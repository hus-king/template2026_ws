# mission 飞行任务

本包提供三个 ROS 1 / MAVROS 飞行任务：定点悬停 `hover`、四点巡航 `square` 和雷达避障 `avoidance`。公共控制函数位于 [template.h](../template/include/template.h)，避障算法位于 [avoidance.h](../template/include/avoidance.h)。

## 文件与任务

| 任务 | 源码 | 启动文件 | 参数文件 | 执行流程 |
| --- | --- | --- | --- | --- |
| hover | [hover.cpp](src/hover.cpp) | [hover.launch](launch/hover.launch) | [hover.yaml](config/hover.yaml) | 起飞 → 悬停 30 秒 → 降落 |
| square | [square.cpp](src/square.cpp) | [square.launch](launch/square.launch) | [square.yaml](config/square.yaml) | 起飞 → 依次到达四个航点 → 在最后一个航点附近降落 |
| avoidance | [avoidance.cpp](src/avoidance.cpp) | [avoidance.launch](launch/avoidance.launch) | [avoidance.yaml](config/avoidance.yaml) | 起飞 → 追踪目标并躲避障碍 → 距目标小于 0.3 米时降落 |

三个节点均以 20 Hz 发布控制指令。源码启动后会提示 `1 to go on , else to quit`，输入 `1` 继续，其他值退出；随后等待飞控连接，并执行模式切换和解锁逻辑。

## 编译与启动

在配置好 ROS 1 的飞机或仿真环境中，先准备 [CMakeLists.txt](CMakeLists.txt) 和 [package.xml](package.xml) 中声明的依赖，包括 MAVROS、`template`、`QR_node`、`yolov8_ros_msgs`、`cloud_recognition` 等。当前源码存在下文列出的运行前问题，需要先处理，再编译：

```bash
cd ~/template2026_ws
catkin_make
source devel/setup.bash
```

先启动 MAVROS 和本地定位；`avoidance` 还需要雷达驱动发布 `/scan`。这些任务 launch 只启动任务节点，不启动飞控连接、定位或雷达。

每次选择一个任务运行：

```bash
roslaunch mission hover.launch
```

```bash
roslaunch mission square.launch
```

```bash
roslaunch mission avoidance.launch
```

三个任务使用同一个飞控控制话题，应单独运行。修改 YAML 后重新启动任务即可加载新值；修改 C++ 后需要重新编译。

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

## 当前运行前问题与验证范围

- `hover.launch` 当前节点 `name` 为空，且 YAML 放在节点内部加载到私有命名空间；源码使用普通 `NodeHandle` 读取公共参数。需要设置有效节点名，并将 YAML 加载范围与源码一致。square 和 avoidance 的 launch 已采用公共参数加载。
- `avoidance.cpp` 当前缺少 `mission_num`、`if_debug`、`err_max` 的定义；`case 2` 中局部变量 `abs_distance` 的初始化还需要用独立作用域包住，避免后续 `case` 标签跨越初始化。这些问题会影响编译。
- 公共 `precision_land()` 保持进入降落时的 XY，设置本地 Z 目标为 `-0.15`，约 5 秒后返回完成；它没有依据落地状态确认着陆，也没有主动发送上锁请求。

本文按当前源码和配置编写。已对 square 的参数对应关系及 square、avoidance 的 launch/YAML 做静态检查；尚未进行 ROS 编译、仿真或实机飞行验证。
