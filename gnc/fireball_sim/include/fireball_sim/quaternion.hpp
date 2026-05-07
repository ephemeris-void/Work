#pragma once

struct Quaternion{

    double w;
    double x;
    double y;
    double z;
};

Quaternion Multiplication(Quaternion a, Quaternion  b);
Quaternion normalization(Quaternion a);
Quaternion euler_to_quaternion(double roll,double pitch,double yaw);