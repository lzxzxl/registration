function Tstar = Get_True_T(T)
% T = [pitch yaw roll tx ty tz], with R = Rx*Ry*Rz and Y = R*X + t
% returns Tstar so that X = Rstar*Y + tstar (same convention)

pitch=T(1); yaw=T(2); roll=T(3);
t = T(4:6).';

Rx=[1,0,0; 0,cos(pitch),-sin(pitch); 0,sin(pitch),cos(pitch)];
Ry=[cos(yaw),0,sin(yaw); 0,1,0; -sin(yaw),0,cos(yaw)];
Rz=[cos(roll),-sin(roll),0; sin(roll),cos(roll),0; 0,0,1];
R = Rx*Ry*Rz;

Rstar = R.';          % inverse rotation
tstar = -R.' * t;     % inverse translation

% ---- extract Euler from Rstar with SAME convention: Rstar = Rx(p*)*Ry(y*)*Rz(r*) ----
sy = Rstar(1,3);
yaw_star = asin(max(-1,min(1,sy)));  % clamp for numerical stability
cy = cos(yaw_star);

if abs(cy) < 1e-10
    % gimbal lock
    roll_star  = 0;
    pitch_star = atan2(Rstar(2,1), Rstar(2,2));
else
    pitch_star = atan2(-Rstar(2,3), Rstar(3,3));
    roll_star  = atan2(-Rstar(1,2), Rstar(1,1));
end

Tstar = [pitch_star, yaw_star, roll_star, tstar.'];
end
