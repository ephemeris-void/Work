from launch import LaunchDescription
from launch_ros.actions import Node
import os

def generate_launch_description():

        urdf_path = os.path.expanduser("~/work/gnc/simulation/urdf/fireball_initialization.urdf")
        with open(urdf_path, 'r') as f:
            robot_desc = f.read()
        robot_state_pub = Node(
            package = "robot_state_publisher",
            executable = "robot_state_publisher",
            name = "robot_state_publisher",
            output = "screen",
            parameters = [{"robot_description": robot_desc}]
        )
        physics=Node(
            package = "fireball_sim",
            executable = "physics_rk4_node",
            output = "screen"
    )
        quaternion=Node(
            package = "fireball_sim",
            executable = "quaternion_node",
            output = "screen"
    )
        viz=Node(
            package = "fireball_sim",
            executable = "visualization_node",
            output = "screen"
    )
        rviz=Node(
            package = "rviz2",
            executable = "rviz2",
            output = "screen"
    )

        return LaunchDescription([
            robot_state_pub,
            physics,
            quaternion,
            viz,
            rviz,


    ])