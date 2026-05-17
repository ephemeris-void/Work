#!/bin/bash
export DISPLAY=:0
export LIBGL_ALWAYS_SOFTWARE=1
export MESA_GL_VERSION_OVERRIDE=3.3
source /opt/ros/humble/setup.bash
ros2 run rviz2 rviz2
