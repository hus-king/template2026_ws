## 实机启动脚本

```zsh
./shell/hardware.sh
# 四点巡航：./shell/hardware.sh square
# 雷达避障：./shell/hardware.sh avoidance
```

先启动飞控连接、雷达和定位。避障额外启动点云转扫描。任务窗口仅填入命令，由操作者按回车，再输入 `1` 确认；手动切 OFFBOARD 后程序会请求解锁。

`Ctrl+B`、`W` 切换窗口，`Ctrl+B`、`D` 离开画面并保留程序；在各运行窗口按 `Ctrl+C` 停止程序。

## 需要改的参数

| 位置 | 参数 |
| --- | --- |
| `shell/hardware.sh` | `roslaunch fly_demo utils.launch`：替换为当前飞机的驱动、定位启动命令 |
| `src/mission/config/hover.yaml` | 到点误差 `err_max` |
| `src/mission/config/square.yaml` | 高度 `altitude`、航点 `waypoints` |
| `src/mission/config/avoidance.yaml` | 目标 `target_x/target_y`、避障半径、速度 |
| `src/mission/config/mid360_scan.yaml` | 点云高度过滤、距离范围 |
| `src/template/include/template.h` | hover/avoidance 高度 `ALTITUDE`、`AIM_ALTITUDE` |
| `src/mission/src/hover.cpp` | 悬停时间 `hover(30.0)` |

修改 YAML 后重启任务；修改 C++ 或头文件后重新编译。
