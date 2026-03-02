function [] = Visualization(T,VesData3D,VesData2D,seq,VesData3D_Seg)
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



figure;
% plot(VesData2D.node_positions(:,1),VesData2D.node_positions(:,2),'.','Markersize',2,'Color','g');
plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'.','Markersize',2,'Color',[83/255,214/255,0/255]);
hold on
for i=1:numel(VesData3D_Seg)
    temp=VesData3D_Seg(i).idx;
    plot(VesData3D_Proj(temp,1),VesData3D_Proj(temp,2),'Color',[247/255,10/255,18/255],'LineWidth',1.5);
end
ylim([0,512]);
axis equal


% figure;
%num_file=regexp(VesData2D.DSA_Path, '(?<=_)\d+', 'match', 'once');
num_file=regexp(VesData2D.DSA_Path, '\d+', 'match');
num_file=str2double(num_file{end}); 
% %%原始DSA路径
% % DSA_OriPath=['C:\Users\Lzx\Desktop\dsa\IMG-0003-',sprintf('%05d',num_file),'.bmp']; %序列2
% DSA_OriPath=['C:\Users\Lzx\Desktop\dsa1\IMG-0040-',sprintf('%05d',num_file),'.bmp']; %序列1
% % DSA_OriPath=['C:\Users\Lzx\Desktop\dsa2\IMG-0001-',sprintf('%05d',num_file),'.bmp']; %序列3
% % DSA_OriPath=['C:\Users\Lzx\Desktop\dsa3\IMG-0002-',sprintf('%05d',num_file),'.bmp']; %序列3
% 
% DSA_OriPath=['F:\Registration\SequenceFile\seq_',num2str(seq),'\frame_',sprintf('%04d',num_file),'.png'];
% 
% I=imread(DSA_OriPath);
% imshow(I);
% hold on
% plot(VesData2D.Centerline(:,1),512-VesData2D.Centerline(:,2),'.','Markersize',3,'Color',[83/255,214/255,0/255]);
% for i=1:numel(VesData3D_Seg)
%     temp=VesData3D_Seg(i).idx;
%     plot(VesData3D_Proj(temp,1),512-VesData3D_Proj(temp,2),'Color',[247/255,10/255,18/255],'LineWidth',1.5);
% end
% % text(12,12,['Score:',num2str(Err)],'FontSize',20,'Color',[83/255,214/255,0/255]);

ax = gca;
ax.Visible = 'off';
exportgraphics(ax,['C:\Users\Lzx\Desktop\配准\paper_miccai\experiment_picture\overview\rigid',sprintf('%d',num_file),'.png']);
end

