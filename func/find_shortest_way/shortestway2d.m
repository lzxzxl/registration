function [xs,ys,f]=shortestway2d(im,x,y,s,t,img_DT_proj,img_DT)
L=bwlabeln(im,8);
path=[];
% 用不着这个，因为存在走空白的路线
% if L(y(s),x(s))~=L(y(t),x(t))
%     disp('there is no path from s to t!');
%     return;
% end
% path=shortestpath3(double(im),x-1,y-1,z-1,s,t);
[xs,ys,f]=shortestway2d_c(double(im),x-1,y-1,s,t,double(img_DT_proj),double(img_DT));%真实
% [xs,ys,f]=shortestway2d_cc(double(im),x-1,y-1,s,t,double(img_DT_proj),double(img_DT));%仿真
xs=xs+1;
ys=ys+1;
end