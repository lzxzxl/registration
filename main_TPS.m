clear;clc;
addpath(genpath(pwd));

tic
%!!!!!要改的量，物理间距参数，dicom文件序号,CTA路径,根节点号

%!!CTA切片路径
CTA_folder='F:\MatlabProject\MyRegistration\data\bmp_line\9132496\'; 
%!!选择 DICOM 文件
seq_dicom = 1; %为0表示时间最新的




%% 根据DICOM文件导出帧
dicomFile = 'DICOMFile'; 
files = dir(fullfile(dicomFile));
files = files(~ismember({files.name}, {'.', '..'}));
%按时间排序
[~, order] = sort([files.datenum], 'ascend');
files_sorted = files(order);
if seq_dicom == 0 || seq_dicom > numel(files_sorted)
    idx = numel(files_sorted);
elseif seq_dicom<0
    error('seq_dicom不能为负数')
else               
    idx = seq_dicom;
end
latestfile = fullfile(dicomFile, files_sorted(idx).name);

%读取 DICOM 信息和图像数据
info = dicominfo(latestfile);
img  = dicomread(latestfile); 
[rows, cols, numFrames] = size(img);
%导出一个序列图片
SequenceFolder = 'SequenceFile'; 
if ~exist(SequenceFolder, 'dir')
    mkdir(SequenceFolder);
end
newSeqNum = idx;% idx表示dicom文件顺序了
outDir = fullfile(SequenceFolder, ['seq_' num2str(newSeqNum)]);  %导出帧路径
if exist(outDir, 'dir')
    fprintf('文件夹已存在，不执行导出操作: %s\n', outDir);
else
    % 文件夹不存在，创建并导出帧
    mkdir(outDir);
    fprintf('创建文件夹: %s\n', outDir);
    % 一般情况：灰度多帧 [rows, cols, numFrames]
    [rows, cols, numFrames] = size(img);
    for k = 1:numFrames 
        frame = img(:, :, k);
        % 简单归一化到 [0,255] 再保存为 PNG
        frameNorm = mat2gray(double(frame));  % 到 [0,1]
        frameUint8 = im2uint8(frameNorm);     % 到 [0,255] uint8
        %输出帧命名
        outName = fullfile(outDir, sprintf('frame_%04d.png', k));
        imwrite(frameUint8, outName);
    end
    disp('全部帧已导出完成！');
end

%% 导出帧后，执行分割
% 虚拟环境里的 python 路径
pyexec = 'C:\Users\Lzx\.conda\envs\deepsa\python.exe';
py_dir = 'pyprogram';
old_dir = pwd;
py_seg = 'test.py';
input_path = fullfile(pwd, outDir);
output_path = fullfile(pwd, 'SegmentFile', ['Seg_' num2str(newSeqNum)]);  %分割结果路径
outpath = fullfile('SegmentFile', ['S_' num2str(newSeqNum)]); %DSA路径（一个心动周期）
outpath_VM = fullfile('SegmentFile',['VM_' num2str(newSeqNum)]); %形变场输入路径
mkdir(outpath_VM);
mkdir(outpath);
res_path = fullfile('Result', ['Reg_' num2str(newSeqNum)]); %存放结果
mkdir(res_path);
if exist(output_path, 'dir')
    fprintf('文件夹已存在，不执行分割操作: %s\n', output_path);
else
    cd(py_dir);
    cmd = sprintf('"%s" "%s" --input "%s" --output "%s"', pyexec, py_seg, input_path, output_path);   
    [status, result] = system(cmd)  % status==0 表示成功
    cd(old_dir);

    %选取一个心跳周期
    seg_name = dir(fullfile(output_path,'*.png'));
    Num = length(seg_name);
    area=[];
    for i = 1:Num
        seg_path = fullfile(output_path, seg_name(i).name);
        img = imread(seg_path);
        vessel_2DLine = img>0;
        area = [area, sum(vessel_2DLine(:))];
    end
    [~, idx_seg] = maxk(area, 8);

    %融合frangi和分割的结果，将新结果写入到S_文件夹并重命名
    for i = min(idx_seg):max(idx_seg) 
        pic = imread(fullfile(output_path, seg_name(i).name));
        pic_frangi = double(imread(fullfile(outDir, seg_name(i).name)));
        pic_frangi = FrangiFilter2D(pic_frangi);
        pic_frangi = pic_frangi>0.02;
        pic_fuse = pic|pic_frangi;

        pic_VM = pic_fuse;

        % se=strel('disk',1);
        % vessel_2DLine=imopen(pic_VM,se);
        % vessel_2DLine=imclose(pic_VM,se);
        %%%%%%%%%%%%%%%%%%
        cc = bwconncomp(pic_VM,4); 
        stats = regionprops(cc, 'Area'); 
        idx = find([stats.Area] < 300); %300
        L=ismember(labelmatrix(cc), idx); 
        pic_VM(L)=0;
        %%%%%%%%%%%%%%%%%%%%%
        
        seqnum = regexp(seg_name(i).name, '\d+', 'match', 'once');
        seqnum = num2str(str2double(seqnum));     
        out_name = fullfile(outpath, ['x_' seqnum '.png']);
        imwrite(pic_fuse, out_name);
        
        out_vmname = fullfile(outpath_VM, ['f_' seqnum '.png']);
        imwrite(pic_VM, out_vmname);
    end
end

toc

%% 刚性配准

f=info.DistanceSourceToDetector;
f=f*cols/512;
dx=info.ImagerPixelSpacing(1);dy=info.ImagerPixelSpacing(2);
u0=256;v0=256; %主点
%内置参数K
K=[f/dx,0,u0;
0,f/dy,v0;
0,0,1];


%% 导入三维模型


%load('CTA_Centralline_left1231_2.mat','vessel_3DLine');
% load('CTA_Centralline_yqr625850.mat','vessel_3DLine');
%load('CTA_Centralline_wyg11739230.mat','vessel_3DLine');
load('CTA_Centralline.mat','vessel_3DLine');
% 根节点
% rootpoint=688;%695，688

% 找最高分支
% branchMask = bwmorph3(vessel_3DLine,'branchpoints');
% idx_branch = find(branchMask);
% [yb,xb,zb]=ind2sub(size(vessel_3DLine),idx_branch);
% [~,idxk]=max(zb);
% rootpoint=find(x==xb(idxk)&y==yb(idxk)&z==zb(idxk),1);

% 物理间距参数

%spacing = struct('x', 0.33, 'y', 0.33, 'z', 0.5);   %%1 0.42
% spacing = struct('x', 0.3281, 'y', 0.3281, 'z', 0.5);   
% spacing = struct('x', 0.42, 'y', 0.42, 'z', 0.5);  %wang,yqr
spacing = struct('x', 0.43359, 'y', 0.43359, 'z', 0.4); 
[y,x,z] = ind2sub(size(vessel_3DLine), find(vessel_3DLine == 1));


rootpoint=688;  %894 ni   wang you 426 zuo 686   yu zuo 916

% XYZ坐标计算 细节要交换
coordinates = [ (x-1)*spacing.x,(y-1)*spacing.y,(z-1)*spacing.z];  
%平移到中心
Display=(max(coordinates)+min(coordinates))/2;
coordinates_move=coordinates-repmat(Display,size(coordinates,1),1);


%考虑source变换后，CTA的坐标变换
Angle_Z=-33.34;Angle_X=-20.97999; %序列1
Angle_Z=info.PositionerPrimaryAngle;Angle_X=info.PositionerSecondaryAngle;
a=Angle_Z*pi/180;b=Angle_X*pi/180;
dxc=765;%sourcetopatient光源到病人距离
dxc=info.DistanceSourceToPatient;
p_base=sqrt(1+tan(a)^2+tan(b)^2);
p_x=dxc*tan(a)/p_base;
p_y=-dxc/p_base;
p_z=dxc*tan(b)/p_base;
p=[p_x,p_y,p_z];
%source变换后的基坐标

% 改投影前！！！！
% y_axis=-p./dxc;
% z_axis=[0,p_z/sqrt(p_z^2+p_y^2),-p_y/sqrt(p_z^2+p_y^2)];
% x_base=sqrt((p_y^2+p_z^2)^2+p_x^2*p_y^2+p_x^2*p_z^2);
% x_axis=[(p_y^2+p_z^2)/x_base,-p_x*p_y/x_base,-p_x*p_z/x_base];
% 得到CTA相对于新source的坐标
% trans_base=[x_axis',y_axis',z_axis'];

%source变换后的基坐标
%%%!!! 与其他代码仍有区别，y坐标方向没变
z_axis=-p./dxc;
% x_axis=[-p_y/sqrt(p_x^2+p_y^2),p_x/sqrt(p_x^2+p_y^2),0];
% y_base=sqrt((p_x^2+p_y^2)^2+p_x^2*p_z^2+p_y^2*p_z^2);
% y_axis=[-p_x*p_z/y_base,-p_y*p_z/y_base,(p_x^2+p_y^2)/y_base];
y_axis=[0,p_z/sqrt(p_z^2+p_y^2),-p_y/sqrt(p_z^2+p_y^2)];
x_base=sqrt((p_y^2+p_z^2)^2+p_x^2*p_y^2+p_x^2*p_z^2);
x_axis=[(p_y^2+p_z^2)/x_base,-p_x*p_y/x_base,-p_x*p_z/x_base];

%得到CTA相对于新source的坐标
trans_base=[x_axis',y_axis',z_axis'];
%%%!!!

w=ones(size(coordinates_move,1),1);
% 构建输出结构体
VesData3D = struct('node_positions', coordinates_move,'trans_base',trans_base, ...
    'Sourcepoint',p,'rootpoint',rootpoint,'K',K,'dx',dx,'f',f,'w',w);
% figure;
% plot3(VesData3D.node_positions(:,1),VesData3D.node_positions(:,2),VesData3D.node_positions(:,3),'r.');
% hold on
% scatter3(VesData3D.node_positions(rootpoint,1),VesData3D.node_positions(rootpoint,2),VesData3D.node_positions(rootpoint,3));
% xlabel('x');
% ylabel('y');
% zlabel('z');
% axis equal
%重构顺序为DFS顺序 
[Resort,adj_3d]=reconstruct_centerline_dfs(VesData3D.node_positions,VesData3D.rootpoint);%根节点695！！！/625
VesData3D.node_positions=VesData3D.node_positions(Resort,:);
VesData3D.rootpoint=1;  %重构后根节点变为1

   
%% 选取二维DSA
iseq=2;

File_name=dir(fullfile(outpath,'*.png'));
Num = length(File_name);


DSA_Path=[outpath,'\',File_name(iseq).name];

[img, cmap] = imread(DSA_Path);
vessel_2DLine = img>0;
vessel_2DLine(1:6,:)=0; vessel_2DLine(510:512,:)=0; %削
minArea = 100;  % 依分辨率调，DSA 常见 30~100
vessel_2DLine = bwareaopen(vessel_2DLine, minArea);

%去除毛刺
se=strel('disk',1);
vessel_2DLine=imopen(vessel_2DLine,se);
se=strel('disk',3);
vessel_2DLine = imclose(vessel_2DLine, se);


%%%%%%%%%%%%%%%%%%
cc = bwconncomp(vessel_2DLine,4); 
stats = regionprops(cc, 'Area'); 
idx = find([stats.Area] < 1200); %300
L=ismember(labelmatrix(cc), idx); 
vessel_2DLine(L)=0;
%%%%%%%%%%%%%%%%%%%%%

% exskeleton2d(vessel_2DLine);
[z, x] = find(vessel_2DLine == 1);                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   
z=512-z;
coordinates = [x,z];
img_DT=bwdist(vessel_2DLine);

CL=bwskel(vessel_2DLine);  %%%vessel_2DLine为照片形式
[yy,xx]=find(CL);
..................................
Centerline=[xx,512-yy];

% 构建输出结构体
VesData2D = struct('node_positions', coordinates,'img_DT',img_DT,'K',K, ...
    'DSA_Path',DSA_Path,'Centerline',Centerline,'Map',vessel_2DLine);

adj_2d=buildadj(VesData2D.Centerline);
VesData2D.adj=adj_2d;

%% 刚性配准

%设置初始点
pitch=0;
% yaw=-0.3:0.2:0.3;
% roll=-0.3:0.2:0.3;
yaw=[-0.18,0,0.18];
roll=[-0.18,0,0.18];
t_x=-30:20:30;
t_y=[-18,0,18];
t_z=-30:20:30; %20间距


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
%%%%%%
% InitPoints(end+1,:)=[0.02,0.11,-0.25,-36.9,29.1,-16.39];
lb=[-0.13,-0.25,-0.25,-40,-30,-40];
ub=[0.13,0.25,0.25,40,30,40];

fun=@(x)MeasureError(x,VesData3D,VesData2D);


options = optimoptions('particleswarm','SwarmSize',N,'InitialPoints',InitPoints,...
'UseParallel',false,'HybridFcn','patternsearch','FunctionTolerance',5e-2);

[T,res]=particleswarm(fun,6,lb,ub,options)
VesData3D_Trans=Trans(T,VesData3D);
VesData3D_Proj=Proj(VesData3D_Trans,VesData3D.K);
figure;
plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'g.');
hold on
plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'r.');
axis equal

% [~,idx_seq]=mink(Res,4)


toc
%% 非刚性配准



folder=fullfile(outpath,'\');


%变换到DSA坐标系
VesData3D_Trans=Trans(T,VesData3D);
VesData3D_Trans=VesData3D_Trans';



N=size(VesData3D_Trans,1);

VesData3D.node_positions=(VesData3D.trans_base*VesData3D_Trans'+repmat(VesData3D.Sourcepoint',1,N))';
%将投影落在外面的点去除
VesData3D_Proj=Proj(VesData3D_Trans',VesData3D.K);
x=VesData3D_Proj(:,1);y=VesData3D_Proj(:,2);
inx=x<1|x>size(VesData2D.img_DT,2)|y<1|y>size(VesData2D.img_DT,1);
VesData3D.node_positions(inx,:)=[];

%去除后adj_matrix矩阵产生变化，因此再作一次重构顺序
[Resort,adj_matrix]=reconstruct_centerline_dfs(VesData3D.node_positions,VesData3D.rootpoint);
VesData3D.node_positions=VesData3D.node_positions(Resort,:);

VesData3D_Trans=Trans(zeros(6,1),VesData3D);
VesData3D_Seg=Segm(VesData3D_Trans',adj_matrix);

VesData3D.w=Calc_weight(size(VesData3D.node_positions,1),VesData2D,VesData3D_Seg);

VesData3D_Trans=VesData3D_Trans';

VesData3D_Init=VesData3D_Trans;
VesData3D_Proj=Proj(VesData3D_Trans',VesData3D.K);
%针对投影点过滤二维DSA图像
VesData2D=Clean_vessel2d(VesData2D,VesData3D_Proj);
%点对应
[VesData2D_Match,weight_solve]=DenseMatching(VesData3D_Seg,VesData2D,N,VesData3D_Proj,VesData3D.w);

tps = tps_fit_2d(VesData3D_Proj, VesData2D_Match, 1e-2); % lambda平滑度
Q_warp = tps_warp_2d(tps, VesData3D_Proj);

figure;
plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'g.');
hold on
plot(Q_warp(:,1),Q_warp(:,2),'r.');
axis equal