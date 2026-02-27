function [xs,ys,zs]=shortestway3(im,x,y,z,s,t)
L=bwlabeln(im,26);
path=[];
if L(y(s),x(s),z(s))~=L(y(t),x(t),z(t))
    disp('there is no path from s to t!');
    return;
end
% path=shortestpath3(double(im),x-1,y-1,z-1,s,t);
[xs,ys,zs]=shortest_parth_3d_2v(double(im),x-1,y-1,z-1,s,t);
xs=xs+1;
ys=ys+1;
zs=zs+1;
end