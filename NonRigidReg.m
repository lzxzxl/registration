clear all;clc;


%要改的量，load载入T，选取第几帧，folder，Angle_Z/Angle_X，dir，vesseltracking中的DSA路径，终止判断条件
addpath(genpath(pwd));
tic
load('T_unet1.mat');
%定义第几个序列
Number_seq=9;%9
T=T_all(Number_seq,:);


% f=1091;
% dx=0.30559;dy=0.30559;
% u0=256;v0=256; %主点
% %内置参数K
% K=[f/dx,0,u0;
% 0,f/dy,v0;
% 0,0,1];

%%
%DSA路径
folder='dsa_unet1\';
%获取所有标签
File_label=fullfile(folder,'*.png');
File_name=dir(File_label);
%按文件名排序
names={File_name.name};
[~,sortedIndex]=sort(names);
File_name=File_name(sortedIndex);



% %图片数量
% Num=length(File_name);
% 
% DSA_Path=[folder,File_name(Number_seq).name];
% [img, cmap] = imread(DSA_Path);
% img_rgb = ind2rgb(img, cmap); % 将索引图像转为RGB
% img = img_rgb;
% white_threshold = 0.9; % 根据实际图像调整阈值
% 
% % 创建白色区域掩码
% vessel_2DLine = img(:,:,1) > white_threshold & ...
%        img(:,:,2) > white_threshold & ...
%        img(:,:,3) > white_threshold;
% % vessel_2DLine = imread(DSA_Path);
% vessel_2DLine(1:6,:)=0; %削
% 
% %人工连接！！！
% % vessel_2DLine(512-366,197)=1;
% % vessel_2DLine(512-365,198)=1;
% % vessel_2DLine(512-364,198)=1;
% % vessel_2DLine(512-366,198)=1;
% % vessel_2DLine(512-364,199)=1;
% 
% % vessel_2DLine(512-362,234)=1;
% 
% %vessel_2DLine=img;
% 
% vessel_2DLine=vessel_2DLine>0;
% %%%%%%%%%%%%%%%%%%
% cc = bwconncomp(vessel_2DLine,4); 
% stats = regionprops(cc, 'Area'); 
% idx = find([stats.Area] < 1000); %300
% L=ismember(labelmatrix(cc), idx); 
% vessel_2DLine(L)=0;
% %%%%%%%%%%%%%%%%%%%%%
% %spacing=struct('x',0.305,'z',0.305);
% [z, x] = find(vessel_2DLine == 1);
% z=512-z;
% coordinates = [x,z];
% % figure;
% % plot(x,z,'.','MarkerSize',5);
% 
% img_DT=bwdist(vessel_2DLine);
% 
% %区别于第一部分，直接将中心线存进结构体
% CL=bwskel(vessel_2DLine);  %%%vessel_2DLine为照片形式
% [yy,xx]=find(CL);
% Centerline=[xx,512-yy];
% 
% % 构建输出结构体
% VesData2D = struct('node_positions', coordinates,'img_DT',img_DT,'K',K,'DSA_Path',DSA_Path,'Centerline',Centerline,'Map',vessel_2DLine);


%%
%导入三维数据
load('CTA_Centralline.mat','vessel_3DLine');
% 物理间距参数
spacing = struct('x', 0.43359, 'y', 0.43359, 'z', 0.4); 
[y,x,z] = ind2sub(size(vessel_3DLine), find(vessel_3DLine == 1));
% XYZ坐标计算 细节要交换
coordinates = [ (x-1)*spacing.x,(y-1)*spacing.y,(z-1)*spacing.z];  
%平移到中心
Display=[(max(coordinates)+min(coordinates))/2];
coordinates_move=coordinates-repmat(Display,size(coordinates,1),1);
%考虑source变换后，CTA的坐标变换
Angle_Z=-33.34;Angle_X=-20.97999;
% Angle_Z=40.1599;Angle_X=18.8099;%序列2
%Angle_Z=-28.95;Angle_X=34.81999; %序列3
a=Angle_Z*pi/180;b=Angle_X*pi/180;
dxc=765;%sourcetopatient光源到病人距离
p_base=sqrt(1+tan(a)^2+tan(b)^2);
p_x=dxc*tan(a)/p_base;
p_y=-dxc/p_base;
p_z=dxc*tan(b)/p_base;
p=[p_x,p_y,p_z];
%source变换后的基坐标
y_axis=-p./dxc;
z_axis=[0,p_z/sqrt(p_z^2+p_y^2),-p_y/sqrt(p_z^2+p_y^2)];
x_base=sqrt((p_y^2+p_z^2)^2+p_x^2*p_y^2+p_x^2*p_z^2);
x_axis=[(p_y^2+p_z^2)/x_base,-p_x*p_y/x_base,-p_x*p_z/x_base];
%得到CTA相对于新source的坐标
trans_base=[x_axis',y_axis',z_axis'];

% 构建输出结构体
VesData3D = struct('node_positions', coordinates_move,'trans_base',trans_base,'Sourcepoint',p);

%%
%重构顺序为DFS顺序
[Resort,adj_matrix]=reconstruct_centerline_dfs(VesData3D.node_positions,695);%根节点695！！！
VesData3D.node_positions=VesData3D.node_positions(Resort,:);



%变换到DSA坐标系
VesData3D_Trans=Trans(T,VesData3D);
VesData3D_Trans=VesData3D_Trans';

N=size(VesData3D_Trans,1);

VesData3D.node_positions=(VesData3D.trans_base*VesData3D_Trans'+repmat(VesData3D.Sourcepoint',1,N))';


% figure;%观察顺序
% grid on;
% axis equal;
% xlabel('X');
% ylabel('Y');
% zlabel('Z');
% for i=1:size(VesData3D_Trans,1)
%     plot3(VesData3D_Trans(i,1),VesData3D_Trans(i,2),VesData3D_Trans(i,3),'r.');
%     hold on
%     pause(0.01);
% end
dir=-1;
VesselTracking(VesData3D,adj_matrix,Number_seq,folder,File_name,dir);





























% VesData3D_Init=VesData3D_Trans;
% 
% N=size(VesData3D_Trans,1);
% 
% 
% 
% 
% 
% % fig = figure('Name', '血管形变模拟', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 700]);
% % movegui(fig, 'center');
% % ax=subplot(2,2,[1,2,3,4]);
% % axis(ax,'equal');
% % hold(ax,'on');
% % % view(ax,3);  %开三维视角
% 
% 
% 
% 
% 
% 
% VesData3D_Proj=Proj(VesData3D_Trans',VesData2D.K);
% %针对投影点过滤二维DSA图像
% VesData2D=Clean_vessel2d(VesData2D,VesData3D_Proj);
% 
% 
% %三维分段,并确保每段连续
% VesData3D_Seg=Segm(VesData3D_Trans,adj_matrix);
% for i=1:size(VesData3D_Seg,2)
%     idx=VesData3D_Seg(i).idx;
%     if idx(2)-idx(1)~=1
%         VesData3D_Seg(i).idx(1)=[];
%         VesData3D_Seg(i).positions(1,:)=[];
%     end
% end
% 
% 
% % figure;%观察分段
% % Number_seg=size(VesData3D_Seg,2);             
% % h = linspace(0,1,Number_seg+1); h(end)=[]; % 均匀分布的色相
% % s = 0.9 * ones(1,Number_seg);              % 高饱和度
% % v = 0.9 * ones(1,Number_seg);              % 高亮度
% % colors = hsv2rgb([h' s' v']);     % 转成 RGB
% % for i=1:Number_seg
% %     plot3(VesData3D_Seg(i).positions(:,1),VesData3D_Seg(i).positions(:,2),VesData3D_Seg(i).positions(:,3),'.','Color',colors(i,:));
% %     hold on;
% % end
% 
% %判定每段的匹配效果,针对不好的段作曲线对应
% VesData2D_Match=DenseMatching(VesData3D_Seg,VesData2D,N,VesData3D_Proj);
% % load('VesData2D_Match.mat');
% 
% %找到所有的对应后作点移动
% 
% 
% 
% 
% %用三维坐标表示,像素坐标要转空间点坐标
% 
% 
% VesData2D_Match=(VesData2D_Match-u0)*dx;
% VesData3D_Match=[VesData2D_Match(:,1),repmat(f,[N,1]),VesData2D_Match(:,2)];
% k_int=1000;
% m=1;
% c=2;
% dt=0.02;
% total_time=10.0;
% steps=floor(total_time/dt);
% v=zeros(N,3);%速度
% k_ext=120;
% 
% 
% % %观察二维
% % plot(ax,VesData2D.node_positions(:,1),VesData2D.node_positions(:,2),'.','Markersize',2,'Color','g');
% % for i=1:N
% %     node_points(i)=plot(ax,VesData3D_Proj(i,1),VesData3D_Proj(i,2),'.','Markersize',5,'Color','r');
% % end
% 
% % %观察三维
% % node_points=gobjects(N,1);
% % for i=1:N
% %     node_points(i)=plot3(ax,VesData3D_Trans(i,1),VesData3D_Trans(i,2),VesData3D_Trans(i,3),'.','Markersize',5,'Color','r');
% % end
% 
% 
% % 创建视频记录
% % video_writer = VideoWriter('vessel_simulation.mp4', 'MPEG-4');
% % video_writer.FrameRate = 30;
% % open(video_writer);
% 
% 
% 
% 
% for step=1:steps
% 
% 
%     F_total=zeros(N,3);
%     %获取内部力
%     F_Int=Calc_IntF(VesData3D_Init,VesData3D_Trans,k_int,adj_matrix);
%     %获取外部力
%     F_ext=Calc_ExtF(VesData3D_Trans,VesData3D_Match);
%     %F_ext=Calc_ExtF(VesData3D_Trans,sourcepoint);
%     %计算总力
%     F_total=F_ext+F_Int-c*v;
% 
%     a=F_total/m;
%     v=v+a*dt;
%     VesData3D_Trans=VesData3D_Trans+v*dt;
% 
%     VesData3D_Proj=Proj(VesData3D_Trans',VesData2D.K);
% 
%     % %观察三维
%     % for i=1:N
%     %     set(node_points(i),'XData',VesData3D_Trans(i,1),'YData',VesData3D_Trans(i,2),'ZData',VesData3D_Trans(i,3)); 
%     % end
%     % % 观察二维
%     % for i=1:N
%     %     set(node_points(i),'XData',VesData3D_Proj(i,1),'YData',VesData3D_Proj(i,2)); 
%     % end
%     % 
%     % 
%     % 
%     % % 刷新图形
%     % drawnow limitrate;
%     % 
%     % frame = getframe(fig);
%     % writeVideo(video_writer, frame);
% 
% 
% end
% % for i=1:N
% %     set(node_points(i),'XData',VesData3D_Proj(i,1),'YData',VesData3D_Proj(i,2)); 
% % end
% figure;
% plot(VesData2D.node_positions(:,1),VesData2D.node_positions(:,2),'g.');
% hold on;
% plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'r.');
% axis equal
% 
% VesselTracking(VesData3D_Trans,adj_matrix,Number_seq-1,folder,File_name);
