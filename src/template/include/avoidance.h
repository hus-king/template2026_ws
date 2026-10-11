#pragma once

#include <sensor_msgs/LaserScan.h>
#include <std_msgs/Bool.h>

//全局变量
//--------------------------------------------雷打--------------------------------------------------
sensor_msgs::LaserScan Laser;                                   //激光雷达点云数据
int range_min;                                                //激光雷达探测范围 最小角度
int range_max;                                                //激光雷达探测范围 最大角度

//--------------------------------------------算法相关--------------------------------------------------
float R_outside,R_inside;                                       //安全半径 [避障算法相关参数]
float p_R;                                                      //大圈比例参数
float p_r;                                                      //小圈比例参数
float distance_c,angle_c;                                       //最近障碍物距离 角度
float distance_cx,distance_cy;                                  //最近障碍物距离XY
float vel_collision[2];                                         //躲避障碍部分速度
float vel_collision_ENU[2];                                     //躲避障碍部分世界速度
float vel_collision_max;                                        //躲避障碍部分速度限幅
float p_xy;                                                     //追踪部分位置环P
float vel_track[2];                                             //追踪部分速度
float vel_track_max;                                            //追踪部分速度限幅

//--------------------------------------------输出--------------------------------------------------
std_msgs::Bool flag_collision_avoidance;                       //是否进入避障模式标志位
float vel_sp_ENU[2];                                            //ENU下的总速度
float vel_sp_max;                                               //总速度限幅


void rotation_yaw(float yaw_angle, float input[2], float output[2])
{
    output[0] = input[0] * cos(yaw_angle) - input[1] * sin(yaw_angle);
    output[1] = input[0] * sin(yaw_angle) + input[1] * cos(yaw_angle);
}

//计算前后左右四向最小距离
void cal_min_distance()
{
    distance_c = Laser.ranges[range_min];
    angle_c = 0;
    
    for (int i = range_min*2; i <= range_max*2; i++)
    {
        if(Laser.ranges[i] < distance_c)
        {
            distance_c = Laser.ranges[i];
            angle_c = i/2;
        }
    }
}



//避障函数
void collision_avoidance(float target_x,float target_y)
{
    //2. 根据最小距离判断：是否启用避障策略
    if (distance_c >= R_outside )
    {
        flag_collision_avoidance.data = false;
    }
    else
    {
        flag_collision_avoidance.data = true;
    }

    //3. 计算追踪速度
    vel_track[0] = p_xy * (target_x - local_pos.pose.pose.position.x);
    vel_track[1] = p_xy * (target_y - local_pos.pose.pose.position.y);

    //速度限幅
    float vel_max = (fabs(vel_track[0])>=fabs(vel_track[1]))?fabs(vel_track[0]):fabs(vel_track[1]);
    if (vel_max > vel_track_max){
        for (int i = 0; i < 2; i++)
        {
            vel_track[i] = vel_track[i] * vel_track_max / vel_max;
        }
    }

    vel_collision[0]= 0;
    vel_collision[1]= 0;

    //4. 避障策略
    if(flag_collision_avoidance.data == true)
    {
        distance_cx = distance_c * cos(angle_c/180*3.1415926);
        distance_cy = distance_c * sin(angle_c/180*3.1415926);

        float F_c = 0;

        //小幅度抑制移动速度
        if(distance_c > R_inside && distance_c <= R_outside)
        {
            F_c = p_R * (R_outside - distance_c);

        }

        //大幅度抑制移动速度
        if(distance_c <= R_inside )
        {
            F_c = p_R * (R_outside - R_inside) + p_r * (R_inside - distance_c);
        }

        vel_collision[0] = vel_collision[0] - F_c * distance_cx / distance_c;
        vel_collision[1] = vel_collision[1] - F_c * distance_cy / distance_c;
        //避障速度限幅（需要等比例修改）
        vel_max = (fabs(vel_collision[0])>=fabs(vel_collision[1]))?fabs(vel_collision[0]):fabs(vel_collision[1]);
        if (vel_max > vel_collision_max){
            for (int i = 0; i < 2; i++)
            {
                vel_collision[i] = vel_collision[i] * vel_collision_max / vel_max;
            }
        }

        // 引入随机扰动，避免局部极小值
        float random_disturbance[2];
        random_disturbance[0] = ((float)rand() / RAND_MAX - 0.5) * 0.1; // -0.05 到 0.05 之间的随机数
        random_disturbance[1] = ((float)rand() / RAND_MAX - 0.5) * 0.1;

        vel_collision[0] += random_disturbance[0];
        vel_collision[1] += random_disturbance[1];
    }

    rotation_yaw(yaw,vel_collision,vel_collision_ENU);

    vel_sp_ENU[0] = vel_track[0] + vel_collision_ENU[0];
    vel_sp_ENU[1] = vel_track[1] + vel_collision_ENU[1];


    //找当前位置到目标点的xy差值，如果出现其中一个差值小，另一个差值大，
    //且过了一会还是保持这个差值就开始从差值入手。
    //比如，y方向接近0，但x还差很多，但x方向有障碍，这个时候按discx cy的大小，缓解y的难题。
    vel_max = (fabs(vel_sp_ENU[0])>=fabs(vel_sp_ENU[1]))?fabs(vel_sp_ENU[0]):fabs(vel_sp_ENU[1]);
    if (vel_max > vel_sp_max){
        for (int i = 0; i < 2; i++)
        {
            vel_sp_ENU[i] = vel_sp_ENU[i] * vel_sp_max / vel_max;
        }
    }
}

//接收雷达的数据，并做相应处理,然后最小距离
void lidar_cb(const sensor_msgs::LaserScan::ConstPtr& scan)
{
    sensor_msgs::LaserScan Laser_tmp;
    Laser_tmp = *scan;
    Laser = *scan;
    int count;    //count = 359
    count = Laser.ranges.size();

    //剔除inf的情况
    for(int i = 0; i < count; i++)
    {
        //判断是否为inf
        int a = isinf(Laser_tmp.ranges[i]);
        //如果为inf，则赋值上一角度的值
        if(a == 1)
        {
            if(i == 0)
            {
                Laser_tmp.ranges[i] = Laser_tmp.ranges[count-1];
            }
            else
            {
                Laser_tmp.ranges[i] = Laser_tmp.ranges[i-1];
            }
        }
    
    }
    for(int i = 0; i < count; i++)
    {
           if(i+360>719) Laser.ranges[i]=Laser_tmp.ranges[i-360];
           else Laser.ranges[i]=Laser_tmp.ranges[i+360];
    }
    //计算前后左右四向最小距离
    cal_min_distance();
}
