function X_CTA = TransInv(Y_DSA, T, VesData3D)
% Y_DSA: 3xN (就是你Trans输出的那种)
% 返回 X_CTA: 3xN

pitch=T(1); yaw=T(2); roll=T(3);
t = T(4:6).';
A = VesData3D.trans_base;
S = VesData3D.Sourcepoint(:);

Rx=[1,0,0; 0,cos(pitch),-sin(pitch); 0,sin(pitch),cos(pitch)];
Ry=[cos(yaw),0,sin(yaw); 0,1,0; -sin(yaw),0,cos(yaw)];
Rz=[cos(roll),-sin(roll),0; sin(roll),cos(roll),0; 0,0,1];
R = Rx*Ry*Rz;

X_CTA = R.' * (A*Y_DSA + S - t);
end
