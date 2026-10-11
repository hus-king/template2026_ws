#include <template.h>
#include <avoidance.h>


//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>全 局 变 量<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
//--------------------------------------------输入--------------------------------------------------
float target_x;                                                 //期望位置_x
float target_y;                                                 //期望位置_y

void printf_avoidance()//打印函数
{
    cout <<">>>>>>>>>>>>>>>>>>>>>>>>>>>>>collision_avoidance<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" <<endl;
    cout << "Minimun_distance : "<<endl;
    cout << "Distance : " << distance_c << " [m] "<<endl;
    cout << "Angle :    " << angle_c    << " [du] "<<endl;
    cout << "distance_cx :    " << distance_cx    << " [m] "<<endl;
    cout << "distance_cy :    " << distance_cy    << " [m] "<<endl;
    if(flag_collision_avoidance.data == true)
    {
        cout << "Collision avoidance Enabled "<<endl;
    }
    else
    {
        cout << "Collision avoidance Disabled "<<endl;
    }
    cout << "vel_track_x : " << vel_track[0] << " [m/s] "<<endl;
    cout << "vel_track_y : " << vel_track[1] << " [m/s] "<<endl;

    cout << "vel_collision_x : " << vel_collision[0] << " [m/s] "<<endl;
    cout << "vel_collision_y : " << vel_collision[1] << " [m/s] "<<endl;

    cout << "vel_sp_x : " << vel_sp_ENU[0] << " [m/s] "<<endl;
    cout << "vel_sp_y : " << vel_sp_ENU[1] << " [m/s] "<<endl;
}                                                              
void printf_param()
{
    cout <<">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Parameter <<<<<<<<<<<<<<<<<<<<<<<<<<<" <<endl;
    cout << "target_x : "<< target_x << endl;
    cout << "target_y : "<< target_y << endl;

    cout << "R_outside : "<< R_outside << endl;
    cout << "R_inside : "<< R_inside << endl;

    cout << "p_xy : "<< p_xy << endl;
    cout << "vel_track_max : "<< vel_track_max << endl;

    cout << "p_R : "<< p_R << endl;
    cout << "p_r : "<< p_r << endl;

    cout << "vel_collision_max : "<< vel_collision_max << endl;

    cout << "vel_sp_max : "<< vel_sp_max << endl;
    cout << "range_min : "<< range_min << endl;
    cout << "range_max : "<< range_max << endl;
}                                                          //打印各项参数以供检查
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>主 函 数<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
int main(int argc, char **argv)
{
      // 防止中文输出乱码
    setlocale(LC_ALL, "");

    ros::init(argc, argv, "avoidance");
    ros::NodeHandle nh;

    // 订阅mavros相关话题
    ros::Subscriber state_sub = nh.subscribe<mavros_msgs::State>("mavros/state", 10, state_cb);
    ros::Subscriber local_pos_sub = nh.subscribe<nav_msgs::Odometry>("/mavros/local_position/odom", 10, local_pos_cb);

    //【订阅】Lidar数据
    ros::Subscriber lidar_sub = nh.subscribe<sensor_msgs::LaserScan>("/scan", 1000, lidar_cb);
    

    // 发布无人机多维控制话题
    ros::Publisher mavros_setpoint_pos_pub = nh.advertise<mavros_msgs::PositionTarget>("/mavros/setpoint_raw/local", 100);

    // 创建服务客户端
    ros::ServiceClient arming_client = nh.serviceClient<mavros_msgs::CommandBool>("mavros/cmd/arming");
    ros::ServiceClient set_mode_client = nh.serviceClient<mavros_msgs::SetMode>("mavros/set_mode");
    ros::ServiceClient ctrl_pwm_client = nh.serviceClient<mavros_msgs::CommandLong>("mavros/cmd/command");

    // 频率 [20Hz]
    ros::Rate rate(20.0);
    //读取参数表中的参数
    nh.param<float>("target_x", target_x, 1.0); 
    nh.param<float>("target_y", target_y, 0.0); 

    nh.param<float>("R_outside", R_outside, 1.6);
    nh.param<float>("R_inside", R_inside, 0.8);

    nh.param<float>("p_xy", p_xy, 0.5);

    nh.param<float>("vel_track_max", vel_track_max, 0.25);

    nh.param<float>("p_R", p_R, 0.6);
    nh.param<float>("p_r", p_r, 1.2);

    nh.param<float>("vel_collision_max", vel_collision_max, 0.30);
    nh.param<float>("vel_sp_max", vel_sp_max, 0.3);

    nh.param<int>("range_min", range_min, 0);
    nh.param<int>("range_max", range_max, 359);

    nh.param<float>("if_debug", if_debug, 0);

    //打印现实检查参数
    printf_param();

  
    int choice = 0;
    std::cout << "1 to go on , else to quit" << std::endl;
    std::cin >> choice;
    if (choice != 1) return 0;
    ros::spinOnce();
    rate.sleep();


    // 等待连接到飞控
    while (ros::ok() && !current_state.connected)
    {
        ros::spinOnce();
        rate.sleep();
    }

    // 定义客户端变量，设置为offboard模式
    mavros_msgs::SetMode offb_set_mode;
    offb_set_mode.request.custom_mode = "OFFBOARD";

    // 定义客户端变量，请求无人机解锁
    mavros_msgs::CommandBool arm_cmd;
    arm_cmd.request.value = true;

    // 记录当前时间，并赋值给变量last_request
    ros::Time last_request = ros::Time::now();

    while (ros::ok())
    {
        if (current_state.mode != "OFFBOARD" && (ros::Time::now() - last_request > ros::Duration(3.0)))
        {
        if(if_debug == 1)
        {
            if (set_mode_client.call(offb_set_mode) && offb_set_mode.response.mode_sent)
            {
            ROS_INFO("Offboard enabled");
            }
        }
        else
        {
            ROS_INFO("Waiting for OFFBOARD mode");
        }
        last_request = ros::Time::now();
        }
        else
        {
        if (!current_state.armed && (ros::Time::now() - last_request > ros::Duration(3.0)))
        {
            if (arming_client.call(arm_cmd) && arm_cmd.response.success)
            {
            ROS_INFO("Vehicle armed");
            }
            last_request = ros::Time::now();
        }
        }
        // 当无人机到达起飞点高度后，悬停3秒后进入任务模式，提高视觉效果
        if (fabs(local_pos.pose.pose.position.z - init_position_z_take_off - ALTITUDE) < 0.2)
        {
        if (ros::Time::now() - last_request > ros::Duration(1.0))
        {
            mission_num = 1;
            last_request = ros::Time::now();
            break;
        }
        }

        mission_pos_cruise(0, 0, ALTITUDE, 0, err_max); 
        mavros_setpoint_pos_pub.publish(setpoint_raw);
        ros::spinOnce();
        rate.sleep();
    }


    //初值
    vel_track[0]= 0;
    vel_track[1]= 0;

    vel_collision[0]= 0;
    vel_collision[1]= 0;

    vel_sp_ENU[0]= 0;
    vel_sp_ENU[1]= 0;

    while (ros::ok())
    {
        ROS_WARN("mission_num = %d", mission_num);
        
        switch (mission_num)
        {
        // mission1: 起飞
        case 1:
            if (mission_pos_cruise(0, 0, ALTITUDE, 0, err_max))
            {
            if(lib_time_record_func(1.0, ros::Time::now()))
            {
                mission_num = 2;
                last_request = ros::Time::now();
            } 
            }
            else if(ros::Time::now() - last_request >= ros::Duration(3.0))
            {
            mission_num = 2;
            last_request = ros::Time::now();
            lib_time_init_flag = true;
            }
            break;

        //避障
        case 2:
            collision_avoidance(target_x,target_y);
	        setpoint_raw.type_mask = 1 + 2 /* + 4 + 8 + 16 */ + 32 + 64 + 128 + 256 + 512 /*+ 1024 */+ 2048; // xy速度控制，z位置控制
            setpoint_raw.coordinate_frame = 1;
            setpoint_raw.position.z = ALTITUDE; // 保持高度
            setpoint_raw.velocity.x = vel_sp_ENU[0];
            setpoint_raw.velocity.y = vel_sp_ENU[1];
	        setpoint_raw.yaw = 0;
            printf_avoidance();
            float abs_distance = sqrt((local_pos.pose.pose.position.x - target_x) * (local_pos.pose.pose.position.x - target_x) + (local_pos.pose.pose.position.y - target_y) * (local_pos.pose.pose.position.y - target_y));
            if(abs_distance < 0.3)
            {
                mission_num = 3;
                last_request = ros::Time::now();
            }
            break;

        //降落
            case 3:
            if(precision_land())
            {
            mission_num = -1; // 任务结束
            last_request = ros::Time::now();
            }
            break;
        }
        mavros_setpoint_pos_pub.publish(setpoint_raw);
        ros::spinOnce();
        rate.sleep();
        
        if(mission_num == -1) 
        {
        exit(0);
        }
    }
    return 0;
}








