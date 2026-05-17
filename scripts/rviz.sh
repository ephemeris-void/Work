#!/bin/bash
xhost +local:
distrobox enter ros2 -- bash /home/spider/tools/scripts/ros_start.sh
