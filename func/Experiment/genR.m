function R = genR(T)
pitch=T(1);yaw=T(2);roll=T(3);
Rx=[1,0,0;
    0,cos(pitch),-sin(pitch);
    0,sin(pitch),cos(pitch)];
Ry=[cos(yaw),0,sin(yaw);
    0,1,0;
    -sin(yaw),0,cos(yaw)];
Rz=[cos(roll),-sin(roll),0;
    sin(roll),cos(roll),0;
    0,0,1];
R=Rx*Ry*Rz;
end

