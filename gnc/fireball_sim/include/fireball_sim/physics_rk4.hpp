#pragma once

struct State{
    double h;
    double v;
    double m;
};

struct Param{
    double thrust=50000.0;
    double isp=300.0;
    double g0=9.81;
    double cd=0.3;
    double area=1.0;
    double rho=1.225;

};

State derivative(State s, Param p);

State rk4(State s, Param p, double dt);