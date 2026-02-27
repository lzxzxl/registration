%%测试一个序列所有图像，运用粒子群，设置多个初始点，选取其中最好的结果
clc,clear;
addpath(genpath(pwd));
tic
%%要更改的量，Angle_Z,Angle_X,DSA路径-folder,Visualization中的DSA_OriPath


f=1091;
dx=0.30559;dy=0.30559;
u0=256;v0=256; %主点
%内置参数K
K=[f/dx,0,u0;
0,f/dy,v0;
0,0,1];


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
Angle_Z=-33.34;Angle_X=-20.97999; %序列1
 %Angle_Z=40.1599;Angle_X=18.8099; %序列2
% Angle_Z=-28.95;Angle_X=34.81999; %序列3
% Angle_Z=44.9599;Angle_X=-4.5799; %序列4
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

%DSA路径
folder='dsa_unet1\';
%folder='C:\Users\Lzx\Desktop\dsa_imclose\11\';
%获取所有标签
File_label=fullfile(folder,'*.png');
File_name=dir(File_label);
%按文件名排序
names={File_name.name};
[~,sortedIndex]=sort(names);
File_name=File_name(sortedIndex);
%图片数量
Num=length(File_name);

T_all=[];
Res=[];
Tmin=[];
resmin=1000;
VesData2D_min=[];
Filemin=[];


%设置初始点
pitch=0;
% yaw=-0.3:0.2:0.3;
% roll=-0.3:0.2:0.3;
yaw=[-0.25,-0.08,0.08,0.25];
roll=[-0.25,-0.08,0.08,0.25];
t_x=-30:10:30;
t_y=-20:10:20;
t_z=-30:10:30; %20间距

N=length(pitch)*length(yaw)*length(roll)*length(t_x)*length(t_y)*length(t_z);
InitPoints=zeros(N,6);
i=1;
for t1=pitch
    for t2=yaw
        for t3=roll
            for t4=t_x
                for t5=t_y
                    for t6=t_z
                        InitPoints(i,:)=[t1,t2,t3,t4,t5,t6];
                        i=i+1;
                    end
                end
            end
        end
    end
end
% rowrand=randperm(N);
% InitPoints=InitPoints(rowrand,:);

for iseq=8 %1:Num
    DSA_Path=[folder,File_name(iseq).name];
    % % vessel_2DLine=GetDSACentralline1(DSA_Path);
    [img, cmap] = imread(DSA_Path);
    % 
    % if ndims(img) == 2   % 灰度图或二值图
    %     img_rgb = cat(3, img, img, img); % 灰度转RGB
    % else
    %     img_rgb = ind2rgb(img, cmap); % 将索引图像转为RGB
    % end
    % 
    % img = img_rgb;
    % white_threshold = 0.9; % 根据实际图像调整阈值
    % 
    % % 创建白色区域掩码
    % vessel_2DLine = img(:,:,1) > white_threshold & ...
    %        img(:,:,2) > white_threshold & ...
    %        img(:,:,3) > white_threshold;
    vessel_2DLine = img>0;
    % vessel_2DLine = imread(DSA_Path);
    vessel_2DLine(1:6,:)=0; %削
    
    %vessel_2DLine=img;

    %%%%%%%%%%%%%%%%%%
    cc = bwconncomp(vessel_2DLine,4); 
    stats = regionprops(cc, 'Area'); 
    idx = find([stats.Area] < 1000); %300
    L=ismember(labelmatrix(cc), idx); 
    vessel_2DLine(L)=0;
    %%%%%%%%%%%%%%%%%%%%%
    %spacing=struct('x',0.305,'z',0.305);
    [z, x] = find(vessel_2DLine == 1);
    z=512-z;
    coordinates = [x,z];
    % figure;
    % plot(x,z,'.','MarkerSize',5);

    img_DT=bwdist(vessel_2DLine);

    CL=bwskel(vessel_2DLine);  %%%vessel_2DLine为照片形式
    [yy,xx]=find(CL);
    Centerline=[xx,512-yy];

    % 构建输出结构体
    VesData2D = struct('node_positions', coordinates,'img_DT',img_DT,'K',K,'DSA_Path',DSA_Path,'Centerline',Centerline,'Map',vessel_2DLine);


    %%PSO
    %parpool('Processes',12);
    fun=@(x)MeasureError(x,VesData3D,VesData2D);

    options = optimoptions('particleswarm','SwarmSize',N,'InitialPoints',InitPoints,'UseParallel',true,'HybridFcn','patternsearch','FunctionTolerance',5e-2);
    lb=[-0.28,-0.3,-0.3,-40,-30,-40]; %0.4会出现较怪的投影
    ub=[0.28,0.3,0.3,40,30,40];
    
    [T,res]=particleswarm(fun,6,lb,ub,options)


    Visualization(T,VesData3D,VesData2D);
    
    Res=[Res,res];
    T_all=[T_all;T];
    %load("T2.mat");
    if res<resmin
        Tmin=T;
        VesData2D_min=VesData2D;
        resmin=res;
        Filemin=DSA_Path;
    end

end

Visualization(Tmin,VesData3D,VesData2D_min);

Structure_Matching(Tmin,VesData3D,VesData2D_min);
toc


% %%fminsearch
% T=[0,0.2,0,-10,0,0];
% options = optimset('Display','iter','MaxIter', 20000, 'TolFun', 50,'Tolx',1e-6);
% fun=@(x)MeasureError(x,VesData3D,VesData2D);
% 
% [x,res]=fminsearch(fun,T,options)
% 
% Visualization(x,VesData3D,VesData2D);
% 
% 





% tic
% res=zeros(N,1);
% T=zeros(N,6);
% A=[eye(6);-eye(6)];
% B=[ub,-lb]';
% parfor i=1:N
%     fun=@(x)MeasureError(x,VesData3D,VesData2D);
%     [T(i,:),res(i)]=fmincon(fun,InitPoints(i,:),A,B);
% end
% [res_min,pos]=min(res)
% T_min=T(pos,:);
% Visualization(T_min,VesData3D,VesData2D);
% 
% toc