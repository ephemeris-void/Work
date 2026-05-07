cmake_minimum_required(VERSION 3.8)
project(fireball_sim)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake REQUIRED)
# uncomment the following section in order to fill in
# further dependencies manually.
# find_package(<dependency> REQUIRED)
find_package(rclcpp REQUIRED)
find_package(geometry_msgs REQUIRED)
find_package(tf2_ros REQUIRED)
find_package(tf2_geometry_msgs REQUIRED)
include_directories(include)

add_library(physics_rk4 src/physics_rk4.cpp)
add_library(quaternion src/quaternion.cpp)


add_executable(physics_rk4_node src/physics_rk4_node.cpp)
target_link_libraries(physics_rk4_node physics_rk4)
ament_target_dependencies(physics_rk4_node rclcpp geometry_msgs std_msgs)
install(TARGETS physics_rk4_node DESTINATION lib/${PROJECT_NAME})


add_executable(quaternion_node src/quaternion_node.cpp)
target_link_libraries(quaternion_node quaternion)
ament_target_dependencies(quaternion_node rclcpp geometry_msgs)
install(TARGETS quaternion_node DESTINATION lib/${PROJECT_NAME})


add_executable(visualization_node src/visualization_node.cpp)
ament_target_dependencies(visualization_node rclcpp geometry_msgs tf2_ros tf2_geometry_msgs)
install(TARGETS visualization_node DESTINATION lib/${PROJECT_NAME})

install(DIRECTORY launch DESTINATION share/${PROJECT_NAME}/)
ament_package()
