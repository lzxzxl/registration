function [] = Visualization_sim(T,VesData3D,VesData2D)
img_DT=VesData2D.img_DT;
N=size(VesData3D.node_positions,1);%三维点数量
VesData3D_Trans=Trans(T,VesData3D);

VesData3D_Proj=Proj(VesData3D_Trans,VesData2D.K);

ptsIdxs=double(round(VesData3D_Proj));
% ptsIdxs(ptsIdxs<1) = 1;
% ptsIdxs(ptsIdxs>=size(img_DT,1)) = size(img_DT,1)-1;
% for i=1:N
%     x=ptsIdxs(i,1);y=ptsIdxs(i,2);
%     y=512-y;
%     disterr(i)=img_DT(y,x);
% end
% Err=sum(disterr)/N

% ptsIdxs(ptsIdxs(:,1)<1|ptsIdxs(:,2)<1,:) = [];
% ptsIdxs(ptsIdxs(:,2)>=size(img_DT,1)|ptsIdxs(:,1)>=size(img_DT,2),:) = [];
%删除投影到界面之外的点
x=ptsIdxs(:,1);
y=512-ptsIdxs(:,2);
inx=x<1|x>size(img_DT,2)|y<1|y>size(img_DT,1);
x(inx)=[];
y(inx)=[];

%平均距离误差
m=size(img_DT,1);
disterr=img_DT(y+m*(x-1));
Err=mean(disterr)


% figure;
% centerline=bwskel(VesData2D.Centerline);
% [yy, xx] = find(centerline);
% plot(xx,512-yy,'g.','MarkerSize',4);
% hold on
% plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'.','Markersize',5,'Color','r');
% axis equal
% 
figure;
plot(VesData2D.node_positions(:,1),VesData2D.node_positions(:,2),'.','Markersize',2,'Color','g');
hold on
plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'.','Markersize',5,'Color','r');
axis equal




end

