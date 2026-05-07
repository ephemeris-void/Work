#include "fireball_sim/quaternion.hpp"
#include"rclcpp/rclcpp.hpp"
#include "geometry_msgs/msg/quaternion.hpp"
#include "geometry_msgs/msg/vector3.hpp"

class quaternion_node : public rclcpp::Node {

 public: 
 quaternion_node():Node("quaternion_node"){
    pub_=create_publisher<geometry_msgs::msg::Quaternion>("/rocket/rotation",10);
        sub_=create_subscription<geometry_msgs::msg::Vector3>("/rocket/cmd",10, [this](geometry_msgs::msg::Vector3::SharedPtr msg){

     roll_ = msg->x;
     pitch_ =msg->y;
     yaw_ = msg->z;

    });

    timer_=create_wall_timer(std::chrono::milliseconds(100),std::bind(&quaternion_node::step,this));
    
}

 private:
 void step(){

    Quaternion q=euler_to_quaternion(roll_,pitch_,yaw_);
    q=normalization(q);

    auto msg=geometry_msgs::msg::Quaternion();
    msg.w=q.w;
    msg.x=q.x;
    msg.y=q.y;
    msg.z=q.z;
    pub_->publish(msg);
  
 }
double roll_=0,pitch_=0,yaw_=0;

rclcpp::Publisher<geometry_msgs::msg::Quaternion>::SharedPtr pub_;
rclcpp::Subscription<geometry_msgs::msg::Vector3>::SharedPtr sub_;
rclcpp::TimerBase::SharedPtr timer_;
};

int main(int argc ,char** argv){
    rclcpp::init(argc,argv);
    rclcpp::spin(std::make_shared<quaternion_node>());
    rclcpp::shutdown();
}
