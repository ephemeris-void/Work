#include"rclcpp/rclcpp.hpp"
#include "geometry_msgs/msg/point_stamped.hpp"
#include "geometry_msgs/msg/quaternion.hpp"

#include "tf2_ros/transform_broadcaster.hpp"
#include "geometry_msgs/msg/transform_stamped.hpp"
#include <memory>

class viz_node: public rclcpp::Node{
    public: 
    viz_node(): Node("viz_node"){

       sub1_=create_subscription<geometry_msgs::msg::PointStamped>("/rocket/position",10, [this](geometry_msgs::msg::PointStamped::SharedPtr msg){

         z_=msg->point.z;
    });
     sub2_=create_subscription<geometry_msgs::msg::Quaternion>("/rocket/rotation",10, [this](geometry_msgs::msg::Quaternion::SharedPtr msg){
     qw_ = msg->w;
     qx_ = msg->x;
     qy_ = msg->y;
     qz_ = msg->z;

    });

    timer_=create_wall_timer(std::chrono::milliseconds(100),std::bind(&viz_node::step,this));
    tf_=std::make_shared<tf2_ros::TransformBroadcaster>(this);

    }

    private: 
    void step(){


            geometry_msgs::msg::TransformStamped t;
    t.header.stamp=now();
    t.header.frame_id="world";
    t.child_frame_id="base_link";
     t.transform.translation.x=0.0;
    t.transform.translation.y=0.0;  
     t.transform.translation.z=z_;
    t.transform.rotation.w=qw_;
    t.transform.rotation.x=qx_;
    t.transform.rotation.y=qy_;
    t.transform.rotation.z=qz_;
    tf_->sendTransform(t);

    }

 double z_=0.0;
 double qw_=1.0;
 double qx_=0.0;
 double qy_=0.0;
 double qz_=0.0;

rclcpp::Subscription<geometry_msgs::msg::PointStamped>::SharedPtr sub1_;
rclcpp::Subscription<geometry_msgs::msg::Quaternion>::SharedPtr sub2_;
rclcpp::TimerBase::SharedPtr timer_;
std::shared_ptr<tf2_ros::TransformBroadcaster> tf_;
};

int main(int argc ,char** argv){
    rclcpp::init(argc,argv);
    rclcpp::spin(std::make_shared<viz_node>());
    rclcpp::shutdown();
}