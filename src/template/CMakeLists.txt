cmake_minimum_required(VERSION 3.0.2)
project(template)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(catkin REQUIRED COMPONENTS
  roscpp
  rospy
  std_msgs
  sensor_msgs
  geometry_msgs
  mavros_msgs
  nav_msgs
  tf
  actionlib
  move_base_msgs
  image_transport
  visualization_msgs
)
catkin_package(INCLUDE_DIRS include CATKIN_DEPENDS roscpp rospy std_msgs sensor_msgs geometry_msgs mavros_msgs nav_msgs tf actionlib move_base_msgs image_transport visualization_msgs)
include_directories(include ${catkin_INCLUDE_DIRS})
add_executable(template src/template.cpp)
target_link_libraries(template ${catkin_LIBRARIES})
add_dependencies(template ${catkin_EXPORTED_TARGETS})
