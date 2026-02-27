clear;clc;
addpath(genpath(pwd));

%!!!!!要改的量，物理间距参数，dicom文件序号,CTA路径,根节点号
%无512-
 
%!!选择 DICOM 文件
seq_dicom = 1; %为0表示时间最新的
%load('CTA_Centralline_left1231_2.mat','vessel_3DLine');
% load('CTA_Centralline_yqr625850.mat','vessel_3DLine');
%load('CTA_Centralline_wyg11739230.mat','vessel_3DLine');
load('CTA_Centralline.mat','vessel_3DLine');
% load('CTA_Centralline_2_right.mat','vessel_3DLine'); %WANGXUNXIAN
% spacing = struct('x', 0.33, 'y', 0.33, 'z', 0.5);   %%WANGXUNXIAN
% spacing = struct('x', 0.3281, 'y', 0.3281, 'z', 0.5);   
% spacing = struct('x', 0.42, 'y', 0.42, 'z', 0.5);  %wang,yqr
spacing = struct('x', 0.43359, 'y', 0.43359, 'z', 0.4); 
rootpoint=688;  %894 ni   wang you 426 zuo 686   yu zuo 916  WANGXUNXIAN625 873 385

%人工定义二维根节点
root2d_id=123;  %123,883,164

dele_id=93;  %93,266,94
load('DL/LAD_truematch1.mat');
VesData2D_truematch(:,2)=512-VesData2D_truematch(:,2);
iseq=2;
%% 根据DICOM文件导出帧
dicomFile = 'DICOMFile';
files = dir(dicomFile);
files = files(~ismember({files.name},{'.','..'}));

names = {files.name};
numKey = cellfun(@(s) sscanf(regexp(s,'\d+','match','once'),'%f'), names, 'UniformOutput', true);
numKey(isnan(numKey)) = inf;                 % 没数字的排最后
[~, order] = sortrows([numKey(:), (1:numel(names))']);  % 稳定排序
files_sorted = files(order);

if seq_dicom == 0 || seq_dicom > numel(files_sorted)
    idx = numel(files_sorted);
elseif seq_dicom < 0
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

f=info.DistanceSourceToDetector;
f=f*cols/512;
dx=info.ImagerPixelSpacing(1);dy=info.ImagerPixelSpacing(2);
u0=256;v0=256; %主点
%内置参数K
K=[f/dx,0,u0;
0,f/dy,v0;
0,0,1];


%% 选取二维DSA


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
img_DT_Centerline=bwdist(CL);
[yy,xx]=find(CL);
..................................
Centerline=[xx,yy];

% 构建输出结构体
% VesData2D = struct('node_positions', coordinates,'img_DT',img_DT,'K',K, ...
%     'DSA_Path',DSA_Path,'Centerline',Centerline,'Map',vessel_2DLine);
% 


%去掉小分量,给根节点位置还变了
Centerline=clear_smallbatch(Centerline);

adj_2d=buildadj(Centerline);

%联通一些点
adj_2d=connect_2dgraph(Centerline,adj_2d);
[Centerline,adj_2d]=clear_brancheslen(Centerline,adj_2d,20);
adj_2d=break_cycles(adj_2d,root2d_id);


%重排索引
[Centerline,adj_2d]=dfs_reorder_2d(Centerline,adj_2d,root2d_id);
root2d_id=1;



plot_bu=Centerline(2:dele_id,:);   %93,330
Centerline(2:dele_id,:)=[];
adj_2d(2:dele_id,:)=[];
adj_2d(:,2:dele_id)=[];

% %%%测试
% Centerline=VesData2D.VesselPoints;
% adj_2d=buildadj(Centerline);
% root2d_id=1;
% K=VesData2D.K;
% clear VesData2D;
% %%%
[Centerline,adj_2d]=dfs_reorder_2d(Centerline,adj_2d,root2d_id);

VesData2D_Seg=Segm(Centerline,adj_2d);
% figure;
% plot(Centerline(:,1),Centerline(:,2),'g.');
% hold on
% plot(Centerline(1,1),Centerline(1,2),'ro');

N=size(adj_2d,1);
adj_2d_directed = adj_2d;
adj_2d_directed(tril(true(size(adj_2d)), -1)) = 0;   %有向矩阵

deg2d=sum(adj_2d,2);
%处理二维
[Ves_tree_2d,par_2d]=extract_feature_tree(adj_2d,1);
pf_2d = par_2d(Ves_tree_2d);

NodeType=zeros(1,N);
NodeType(deg2d == 1) = 1;
NodeType(deg2d == 2) = 2;
NodeType(deg2d == 3) = 3; %特征点种类

NodeIdxs=[1,Ves_tree_2d']; %特征点索引
NodeIdxs_par=[0,pf_2d']; 
[Graph_Sparse,Graph_Sparse_Directed]=buildadj_full(NodeIdxs,NodeIdxs_par);
VesselPoints_Sparse=Centerline(NodeIdxs,:);


BranchesCell=cell(size(VesData2D_Seg,2),1);
for i=1:size(VesData2D_Seg,2)
    EdgePointsIDs=VesData2D_Seg(i).idx;
    [tf, IDs] = ismember(EdgePointsIDs([1 end]), NodeIdxs);
    EdgePoints=VesData2D_Seg(i).positions;
    BranchesCell{i}=struct('IDs',IDs,'EdgePointsIDs',EdgePointsIDs,'EdgePoints',EdgePoints);
end

VesData2D=struct('Graph_Directed',adj_2d_directed,'Graph',adj_2d,'NodeType',NodeType ...
    ,'NodeIdxs',NodeIdxs,'VesselPoints',Centerline,'Graph_Sparse',Graph_Sparse ...
    ,'Graph_Sparse_Directed',Graph_Sparse_Directed,'VesselPoints_Sparse',VesselPoints_Sparse ...
    ,'BranchesCell',{BranchesCell},'K',K);


%% 导入三维模型


% branchMask = bwmorph3(vessel_3DLine,'branchpoints');
% idx_branch = find(branchMask);
% [yb,xb,zb]=ind2sub(size(vessel_3DLine),idx_branch);
% [~,idxk]=max(zb);
% rootpoint=find(x==xb(idxk)&y==yb(idxk)&z==zb(idxk),1);

[y,x,z] = ind2sub(size(vessel_3DLine), find(vessel_3DLine == 1));


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
% %source变换后的基坐标
% y_axis=-p./dxc;
% z_axis=[0,p_z/sqrt(p_z^2+p_y^2),-p_y/sqrt(p_z^2+p_y^2)];
% x_base=sqrt((p_y^2+p_z^2)^2+p_x^2*p_y^2+p_x^2*p_z^2);
% x_axis=[(p_y^2+p_z^2)/x_base,-p_x*p_y/x_base,-p_x*p_z/x_base];
% %得到CTA相对于新source的坐标
% trans_base=[x_axis',y_axis',z_axis'];

%%%!!!
z_axis=-p./dxc;
% x_axis=[-p_y/sqrt(p_x^2+p_y^2),p_x/sqrt(p_x^2+p_y^2),0];
% y_base=sqrt((p_x^2+p_y^2)^2+p_x^2*p_z^2+p_y^2*p_z^2);
% y_axis=[-p_x*p_z/y_base,-p_y*p_z/y_base,(p_x^2+p_y^2)/y_base];
y_axis=[0,-p_z/sqrt(p_z^2+p_y^2),p_y/sqrt(p_z^2+p_y^2)];
x_base=sqrt((p_y^2+p_z^2)^2+p_x^2*p_y^2+p_x^2*p_z^2);
x_axis=[(p_y^2+p_z^2)/x_base,-p_x*p_y/x_base,-p_x*p_z/x_base];

%得到CTA相对于新source的坐标
trans_base=[x_axis',y_axis',z_axis'];
%%%!!!

w=ones(size(coordinates_move,1),1);
% 构建输出结构体

% figure;
% plot3(coordinates_move(:,1),coordinates_move(:,2),coordinates_move(:,3),'r.');
% hold on
% scatter3(coordinates_move(rootpoint,1),coordinates_move(rootpoint,2),coordinates_move(rootpoint,3));
% xlabel('x');
% ylabel('y');
% zlabel('z');
% axis equal

T=zeros(6,1);
VesData3D_temp = struct('node_positions', coordinates_move,'trans_base',trans_base, ...
    'Sourcepoint',p,'rootpoint',rootpoint,'K',K,'dx',dx,'f',f,'w',w);
VesData3D_Trans=Trans(T,VesData3D_temp);  %变动！！
VesData3D_Trans=VesData3D_Trans';  %DSA坐标系下

% %%% 非刚性！！
% load('F:/Registration/Experiment/CTO1_data.mat');
% VesData3D_Trans=data;
% VesData3D_Trans(:,2)=-VesData3D_Trans(:,2);
% rootpoint=1;

[Resort,adj_3d]=reconstruct_centerline_dfs(VesData3D_Trans,rootpoint);%根节点695！！！/625
VesData3D_Trans=VesData3D_Trans(Resort,:);
rootpoint=1;  %重构后根节点变为1

N=size(adj_3d,1);
adj_3d_directed = adj_3d;
adj_3d_directed(tril(true(size(adj_3d)), -1)) = 0;   %有向矩阵

NodeType=zeros(1,N);
deg3d=sum(adj_3d,2);
NodeType(deg3d == 1) = 1;
NodeType(deg3d == 2) = 2;
NodeType(deg3d == 3) = 3; %特征点种类

[Ves_tree_3d,par_3d]=extract_feature_tree(adj_3d,1);
pf_3d = par_3d(Ves_tree_3d);
NodeIdxs=[1,Ves_tree_3d']; %特征点索引
NodeIdxs_par=[0,pf_3d']; 
[Graph_Sparse,Graph_Sparse_Directed]=buildadj_full(NodeIdxs,NodeIdxs_par);%特征点索引的邻接矩阵和有向矩阵

VesselPoints_Sparse=VesData3D_Trans(NodeIdxs,:);%特征点坐标

VesData3D_Seg=Segm(VesData3D_Trans,adj_3d,1);

BranchesCell=cell(size(VesData3D_Seg,2),1);
for i=1:size(VesData3D_Seg,2)    
    EdgePointsIDs=VesData3D_Seg(i).idx;
    [tf, IDs] = ismember(EdgePointsIDs([1 end]), NodeIdxs);
    EdgePoints=VesData3D_Seg(i).positions;
    BranchesCell{i}=struct('IDs',IDs,'EdgePointsIDs',EdgePointsIDs,'EdgePoints',EdgePoints);
end

VesData3D=struct('Graph_Directed',adj_3d_directed,'Graph',adj_3d,'NodeType',NodeType,'NodeIdxs',NodeIdxs ...
    ,'VesselPoints', VesData3D_Trans,'Graph_Sparse',Graph_Sparse,'Graph_Sparse_Directed',Graph_Sparse_Directed ...
    ,'VesselPoints_Sparse',VesselPoints_Sparse,'BranchesCell',{BranchesCell} ...
    ,'quaternionPara',zeros(1,7));
PriorModel=struct('VesselDataRef',VesData3D);
VesData3D.PriorModel=PriorModel;

if ~isfield(VesData2D,'img_DT')
    img_centerline = centerlineToImage(VesData2D.VesselPoints,[2500,2500]);
    VesData2D.img_DT = bwdist(img_centerline);
end
config=makeconfigMC;
config.VesData3D=VesData3D;
config.VesData2D=VesData2D;

tic
% 刚性
VesData3DReg=MCTSR(config);
VesData3D_Proj=Proj(VesData3DReg.VesselPoints',VesData2D.K);
figure;
num_file=regexp(DSA_Path, '\d+', 'match');
num_file=str2double(num_file{end}); 
%%原始DSA路径
DSA_OriPath=['F:\Registration\SequenceFile\seq_',num2str(newSeqNum),'\frame_',sprintf('%04d',num_file),'.png'];
I=imread(DSA_OriPath);
imshow(I);
hold on
plot(VesData2D.VesselPoints(:,1),VesData2D.VesselPoints(:,2),'.','Color',[83/255,214/255,0/255],'MarkerSize',3);
plot(plot_bu(:,1),plot_bu(:,2),'.','Color',[83/255,214/255,0/255],'MarkerSize',3);
for i=1:numel(VesData3D_Seg)
    temp=VesData3D_Seg(i).idx;
    plot(VesData3D_Proj(temp,1),VesData3D_Proj(temp,2),'Color',[247/255,10/255,18/255],'LineWidth',1.5);
end

x=round(VesData3D_Proj(:,1));y=round(VesData3D_Proj(:,2));
lg=length(x);
inx=x<1|x>512|y<1|y>512;
x(inx)=[];y(inx)=[];
disterr=img_DT_Centerline(y+512*(x-1));
Err=sum(disterr)/length(x)+floor((lg-length(x))/20);

diss=sqrt(sum((VesData3D_Proj-VesData2D_truematch).^2,2));
Err=mean(diss)
% text(12,480,['Score:',num2str(Err)],'FontSize',25,'Color',[233/255,144/255,0]);

ax = gca;
ax.Visible = 'off';
% exportgraphics(ax,'C:\Users\Lzx\Desktop\配准\paper_miccai\experiment_picture\Rigid\MCTS_CTO1_nontext.png');
% 


% VesData3DReg=MCTSR(config);
VesData3DReg = ManifoldRegularized(VesData3DReg,VesData2D,config);
% Display3DA2DVesselData(VesData3DReg,VesData2D.K,VesData2D,'title','manifold');
toc

VesData3D_Proj=Proj(VesData3DReg.VesselPoints',VesData2D.K);


figure;
num_file=regexp(DSA_Path, '\d+', 'match');
num_file=str2double(num_file{end}); 
%%原始DSA路径
DSA_OriPath=['F:\Registration\SequenceFile\seq_',num2str(newSeqNum),'\frame_',sprintf('%04d',num_file),'.png'];
I=imread(DSA_OriPath);
imshow(I);
hold on
plot(VesData2D.VesselPoints(:,1),VesData2D.VesselPoints(:,2),'.','Color',[83/255,214/255,0/255],'MarkerSize',3);
plot(plot_bu(:,1),plot_bu(:,2),'.','Color',[83/255,214/255,0/255],'MarkerSize',3);
for i=1:numel(VesData3D_Seg)
    temp=VesData3D_Seg(i).idx;
    plot(VesData3D_Proj(temp,1),VesData3D_Proj(temp,2),'Color',[247/255,10/255,18/255],'LineWidth',1.5);
end

x=round(VesData3D_Proj(:,1));y=round(VesData3D_Proj(:,2));
lg=length(x);
inx=x<1|x>512|y<1|y>512;
x(inx)=[];y(inx)=[];
disterr=img_DT_Centerline(y+512*(x-1));
Err=sum(disterr)/length(x)+floor((lg-length(x))/20);

diss=sqrt(sum((VesData3D_Proj-VesData2D_truematch).^2,2));
Err=mean(diss)
% text(12,480,['Score:',num2str(Err)],'FontSize',25,'Color',[233/255,144/255,0]);

ax = gca;
ax.Visible = 'off';
% exportgraphics(ax,'C:\Users\Lzx\Desktop\配准\paper_miccai\experiment_picture\NonRigid\MCTS_CTO1_ori_nontext.png');


