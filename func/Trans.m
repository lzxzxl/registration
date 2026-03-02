function VesData3D_Trans = Trans(T,VesData3D) 
%进去是N*3,出来是3*N

%%转化为DSA坐标,进去是CTA坐标，出来是DSA坐标，T作用在CTA坐标上
N=size(VesData3D.node_positions,1);%三维点数量
pitch=T(1);yaw=T(2);roll=T(3);t_x=T(4);t_y=T(5);t_z=T(6);
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
t=[t_x,t_y,t_z]';
VesData3D_Trans=R*VesData3D.node_positions'+t;

VesData3D_Trans=VesData3D.trans_base\(VesData3D_Trans-repmat(VesData3D.Sourcepoint',1,N));


end

