#include "fireball_sim/quaternion.hpp"
#include <cmath>

Quaternion Multiplication(Quaternion a, Quaternion b){
    Quaternion q;

    q.w=a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z;
    q.x=a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.w;
    q.y=a.w*b.y-a.x*b.y-a.y*b.x+a.z*b.w;
    q.z=a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w;

    return q;
}

Quaternion normalization(Quaternion a){

    double n=std::sqrt(a.w*a.w+a.x*a.x+a.y*a.y+a.z*a.z);

    return {
        a.w/n,a.x/n,a.y/n,a.z/n
    };

}

Quaternion euler_to_quaternion(double roll, double pitch, double yaw){

 double cr=cos(roll/2);
 double cp=cos(pitch/2);
double cy=cos(yaw/2);

double sr=sin(roll/2);
double sp=sin(pitch/2);
double sy=sin(yaw/2);

Quaternion q;

q.w=cr*cp*cy+sr*sp*sy;
q.x=sr*cp*cy-cr*sp*sy;
q.y=cr*sp*cy+sr*cp*sy;
q.z=cr*cp*sy-sr*sp*cy;

return q;
}