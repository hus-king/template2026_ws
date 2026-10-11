cmake_minimum_required(VERSION 3.0.2)
project(template)

## Compile as C++11, supported in ROS Kinetic and newer
# add_compile_options(-std=c++11)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

## Find catkin macros and libraries
## if COMPONENTS list like find_package(catkin REQUIRED COMPONENTS xyz)
## is used, also find other catkin packages


find_package(catkin REQUIRED COMPONENTS
  dynamic_reconfigure
  roscpp
  rospy
  QR_node
  std_msgs
  sensor_msgs
  geometry_msgs
  message_generation
  tf
  serial
  actionlib
  move_base_msgs
  tf2_eigen
  tf2
  tf2_ros
  tf2_sensor_msgs
  image_transport
  pcl_ros
  pcl_conversions
)
catkin_package(
  INCLUDE_DIRS include
  CATKIN_DEPENDS QR_node
)


include_directories(
  include
  ${catkin_INCLUDE_DIRS}
  ${PCL_INCLUDE_DIRS}
)


add_executable(template src/template.cpp)
target_link_libraries(template ${catkin_LIBRARIES} )

add_executable(test_servo src/test_servo.cpp)
target_link_libraries(test_servo ${catkin_LIBRARIES} )
