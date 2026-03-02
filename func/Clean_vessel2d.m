function VesData2D = Clean_vessel2d(VesData2D,VesData3D_Proj)
VesData3D_Proj=double(round(VesData3D_Proj));
Sz=size(VesData3D_Proj,1);
Projimg=zeros(512,512);
for i=1:Sz
    x = round(VesData3D_Proj(i,1));
    y = round(VesData3D_Proj(i,2));
    y = 512 - y;

    if x >= 1 && x <= 512 && y >= 1 && y <= 512
        Projimg(y, x) = 1;
    end
    % Projimg(512-VesData3D_Proj(i,2),VesData3D_Proj(i,1))=1;
end
Projimg_DT=bwdist(Projimg);
% x=round(VesData2D.Centerline(:,1));
% y=round(VesData2D.Centerline(:,2));
% 
% x = min(max(x, 1), 512); %!!新增
% y = min(max(y, 1), 512); %!!新增
% disterr=Projimg_DT(512-y+512*(x-1));%！！新增
% % disterr=Projimg_DT(512-y+512*(x-1));
% inx=disterr>35; %!!30
% x(inx)=[];
% y(inx)=[];
% VesData2D.Centerline=[x,y];


x=VesData2D.node_positions(:,1);
y=VesData2D.node_positions(:,2);
x = min(max(x, 1), 512); %!!新增
y = min(max(y, 1), 512); %!!新增
disterr=Projimg_DT(512-y+512*(x-1));
inx=disterr>35;
x(inx)=[];
y(inx)=[];
VesData2D.node_positions=[x,y];

vessel_2d=zeros(512,512);
for i=1:length(x)
    vessel_2d(512-y(i),x(i))=1;
end
VesData2D.img_DT=bwdist(vessel_2d);



% figure;
% plot(x,y,'g.');
% hold on;
% plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'r.');



end

