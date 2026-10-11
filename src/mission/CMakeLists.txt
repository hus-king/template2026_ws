cmake_minimum_required(VERSION 3.0.2)
project(mission)

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
  template
  yolov8_ros_msgs
  cloud_recognition
)

catkin_package(
)


include_directories(
  include
  ${catkin_INCLUDE_DIRS}
  ${PCL_INCLUDE_DIRS}
)


# add_executable(endurance src/endurance.cpp)
# target_link_libraries(endurance ${catkin_LIBRARIES} )

# add_executable(cross src/cross.cpp)
# target_link_libraries(cross ${catkin_LIBRARIES} )

# add_executable(circle src/circle.cpp)
# target_link_libraries(circle ${catkin_LIBRARIES} )

# add_executable(hover src/hover.cpp)
# target_link_libraries(hover ${catkin_LIBRARIES})

add_executable(hover src/hover.cpp)
target_link_libraries(hover ${catkin_LIBRARIES})

add_executable(square src/square.cpp)
target_link_libraries(square ${catkin_LIBRARIES})

add_executable(avoidance src/avoidance.cpp)
target_link_libraries(avoidance ${catkin_LIBRARIES})