#include "fireball_sim/physics_rk4.hpp"
#include"rclcpp/rclcpp.hpp"
#include "geometry_msgs/msg/point_stamped.hpp"
#include "std_msgs/msg/bool.hpp"

class physics_node: public rclcpp::Node {

 public: 
 physics_node():Node("physics_node"){
    pub_=create_publisher<geometry_msgs::msg::PointStamped>("/rocket/position",10);
    sub_launch_=create_subscription<std_msgs::msg::Bool>("/rocket/launch",10,
    
    [this](std_msgs::msg::Bool::SharedPtr msg){
        launched_=msg->data;
    });
    timer_=create_wall_timer(std::chrono::milliseconds(100),std::bind(&physics_node::step,this));
    
}

 private:
 void step(){
    if(!launched_) return;
    if(s_.m<100.0) {s_={0.0, 0.0, 1000.0};return;}
    s_=rk4(s_,p_,0.001);
    auto msg=geometry_msgs::msg::PointStamped();
    msg.header.stamp=now();
    msg.header.frame_id="world";
    msg.point.x=0.0;
    msg.point.y=0.0;
    msg.point.z=s_.h;
    pub_->publish(msg);

 }
State s_{0.0,0.0,1000.0};
Param p_;
bool launched_=false;
rclcpp::Publisher<geometry_msgs::msg::PointStamped>::SharedPtr pub_;
rclcpp::TimerBase::SharedPtr timer_;
rclcpp::Subscription<std_msgs::msg::Bool>::SharedPtr sub_launch_;

};

int main(int argc ,char** argv){
    rclcpp::init(argc,argv);
    rclcpp::spin(std::make_shared<physics_node>());
    rclcpp::shutdown();
}
