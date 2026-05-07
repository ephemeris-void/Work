#include "fireball_sim/physics_rk4.hpp"

State derivative(State s, Param p){

    double drag=0.5*p.rho*s.v*s.v*p.cd*p.area;
    return {
        s.v,p.thrust/s.m-p.g0-drag/s.m,
        -p.thrust/(p.isp*p.g0)
    };

}

State rk4(State s, Param p, double dt){
    auto k1= derivative(s,p);
    auto k2= derivative({s.h+0.5*dt*k1.h,s.v+0.5*dt*k1.v,s.m+0.5*dt*k1.m},p);
    auto k3= derivative({s.h+0.5*dt*k2.h,s.v+0.5*dt*k2.v,s.m+0.5*dt*k2.m},p);
    auto k4= derivative({s.h+dt*k3.h,s.v+dt*k3.v,s.m+dt*k3.m},p);
  return {
    s.h+(dt/6.0)*(k1.h+2*k2.h+2*k3.h+k4.h),
     s.v+(dt/6.0)*(k1.v+2*k2.v+2*k3.v+k4.v),
      s.m+(dt/6.0)*(k1.m+2*k2.m+2*k3.m+k4.m),
  };
}