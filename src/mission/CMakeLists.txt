cmake_minimum_required(VERSION 3.0.2)
project(mission)
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
  template
)
catkin_package(CATKIN_DEPENDS roscpp rospy std_msgs sensor_msgs geometry_msgs mavros_msgs nav_msgs tf actionlib move_base_msgs image_transport visualization_msgs template)
include_directories(include ${catkin_INCLUDE_DIRS})
add_executable(hover src/hover.cpp)
target_link_libraries(hover ${catkin_LIBRARIES})
add_dependencies(hover ${catkin_EXPORTED_TARGETS})
add_executable(square src/square.cpp)
target_link_libraries(square ${catkin_LIBRARIES})
add_dependencies(square ${catkin_EXPORTED_TARGETS})
add_executable(avoidance src/avoidance.cpp)
target_link_libraries(avoidance ${catkin_LIBRARIES})
add_dependencies(avoidance ${catkin_EXPORTED_TARGETS})

catkin_install_python(PROGRAMS scripts/sim_vision_truth.py
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION})
