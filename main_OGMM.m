
clear;clc;
addpath(genpath(pwd));

%!!!!!要改的量，物理间距参数，dicom文件序号,CTA路径,根节点号

%!!CTA切片路径
CTA_folder='F:\MatlabProject\MyRegistration\data\bmp_line\9132496\'; 
%!!选择 DICOM 文件
seq_dicom = 1; %为0表示时间最新的
%load('CTA_Centralline_left1231_2.mat','vessel_3DLine');
% load('CTA_Centralline_yqr625850.mat','vessel_3DLine');
%load('CTA_Centralline_wyg11739230.mat','vessel_3DLine');
load('CTA_Centralline.mat','vessel_3DLine');
% load('CTA_Centralline_2_right.mat','vessel_3DLine'); %WANGXUNXIAN
% spacing = struct('x', 0.33, 'y', 0.33, 'z', 0.5);   %%WANGXUNXIAN
% spacing = struct('x', 0.3281, 'y', 0.3281, 'z', 0.5);   
%spacing = struct('x', 0.42, 'y', 0.42, 'z', 0.5);  %wang,yqr
spacing = struct('x', 0.43359, 'y', 0.43359, 'z', 0.4); 
rootpoint=688;  %894 ni   wang you 426 zuo 686   yu zuo 916  WANGXUNXIAN625 873 385


%人工定义二维根节点
root2d_id=123;  %123,883,164
iseq=2;
load('DL/LAD_truematch1.mat');
VesData2D_truematch(:,2)=512-VesData2D_truematch(:,2);
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

%source变换后的基坐标

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
VesData3D.adj=adj_3d;
deg3d=sum(VesData3D.adj,2);
VesData3D_Seg=Segm(VesData3D.node_positions,adj_3d,1);

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
VesData2D = struct('node_positions', coordinates,'img_DT',img_DT,'K',K, ...
    'DSA_Path',DSA_Path,'Centerline',Centerline,'Map',vessel_2DLine);

%去掉小分量,给根节点位置还变了
VesData2D.Centerline=clear_smallbatch(VesData2D.Centerline);
VesData2D.adj=buildadj(VesData2D.Centerline);

%联通一些点
VesData2D.adj=connect_2dgraph(VesData2D.Centerline,VesData2D.adj);
[VesData2D.Centerline,VesData2D.adj]=clear_brancheslen(VesData2D.Centerline,VesData2D.adj,20);


VesData2D.adj=break_cycles(VesData2D.adj,root2d_id);

%重排索引
[VesData2D.Centerline,VesData2D.adj]=dfs_reorder_2d(VesData2D.Centerline,VesData2D.adj,root2d_id);
root2d_id=1;

VesData2D_Seg=Segm(VesData2D.Centerline,VesData2D.adj);



% 保存初始位姿
% VesData3D_Trans=Trans(zeros(6,1),VesData3D);
% VesData3D_Proj=Proj(VesData3D_Trans,VesData3D.K);
% 
% figure;
% num_file=regexp(VesData2D.DSA_Path, '\d+', 'match');
% num_file=str2double(num_file{end}); 
% %%原始DSA路径
% DSA_OriPath=['F:\Registration\SequenceFile\seq_',num2str(newSeqNum),'\frame_',sprintf('%04d',num_file),'.png'];
% I=imread(DSA_OriPath);
% imshow(I);
% hold on
% for i=1:numel(VesData2D_Seg)
%     temp=VesData2D_Seg(i).positions;
%     plot(temp(:,1),temp(:,2),'Color',[83/255,214/255,0/255],'LineWidth',1.5);
% end
% for i=1:numel(VesData3D_Seg)
%     temp=VesData3D_Seg(i).idx;
%     plot(VesData3D_Proj(temp,1),VesData3D_Proj(temp,2),'Color',[247/255,10/255,18/255],'LineWidth',1.5);
% end
% 
% x=round(VesData3D_Proj(:,1));y=round(VesData3D_Proj(:,2));
% lg=length(x);
% inx=x<1|x>512|y<1|y>512;
% x(inx)=[];y(inx)=[];
% disterr=img_DT_Centerline(y+512*(x-1));
% Err=sum(disterr)/length(x)+floor((lg-length(x))/20);
% text(12,480,['Score:',num2str(Err)],'FontSize',20,'Color',[233/255,144/255,0]);
% ax = gca;
% ax.Visible = 'off';
% exportgraphics(ax,'C:\Users\Lzx\Desktop\配准\paper_miccai\experiment_picture\Rigid\RAW_left1.png');
% 

%% OGMM刚性
tic
[scene.D2, scene.w2] = ComputeTangent2D(VesData2D.Centerline, VesData2D.adj);

alpha = 0.2;               % downweight self-overlap in 2D-3D (projection may overlap)
sigmas = [20, 10, 5, 3];   % multi-scale kernel widths in pixels (coarse->fine)
maxIterPerScale = 200;

sigma_ori = 0.45;            % 方向核尺度（建议 0.25~0.6，见下方解释）
beta_ori  = 1.0;             % 方向项权重（1.0 表示按核自然融合；也可调大更依赖方向）

T=zeros(6,1);
hist = [];
opts = optimoptions('fminunc', ...
        'Algorithm', 'quasi-newton', ...
        'MaxIterations', maxIterPerScale, ...
        'SpecifyObjectiveGradient', true); % (we use numeric gradient)

for s = 1:numel(sigmas)
    sigma = sigmas(s);

    fun = @(x)MeasureError_OGMM(x, VesData3D, VesData2D, scene, sigma, alpha, sigma_ori, beta_ori);

    [T, fval] = fminunc(fun, T, opts);

end

VesData3D_Trans=Trans(T,VesData3D);
VesData3D_Proj=Proj(VesData3D_Trans,VesData2D.K);

toc

figure;
num_file=regexp(VesData2D.DSA_Path, '\d+', 'match');
num_file=str2double(num_file{end}); 
%%原始DSA路径
DSA_OriPath=['F:\Registration\SequenceFile\seq_',num2str(newSeqNum),'\frame_',sprintf('%04d',num_file),'.png'];
I=imread(DSA_OriPath);
imshow(I);
hold on
plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'.','Color',[83/255,214/255,0/255],'MarkerSize',3);
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
Err=mean(diss);
text(12,480,['Score:',num2str(Err)],'FontSize',25,'Color',[233/255,144/255,0]);

ax = gca;
ax.Visible = 'off';
% exportgraphics(ax,'C:\Users\Lzx\Desktop\配准\paper_miccai\experiment_picture\Rigid\OGMM_CTO1_nontext.png');


Corr = OGMM_soft_correspondence_gated(VesData3D.adj, VesData3D_Proj, VesData2D, scene, ...
                                sigmas(numel(sigmas)), sigma_ori, beta_ori);

% 
% figure;
% plot(VesData2D.Centerline(:,1),512-VesData2D.Centerline(:,2),'g.');
% hold on
% plot(Corr.q_hard(:,1),512-Corr.q_hard(:,2),'r.');



%% 非刚性配准TPS
% % 固定输入
% % load('./Experiment/CTO1_data.mat');
% % 
% % VesData3D_Trans=data;
% % [Resort,VesData3D.adj]=reconstruct_centerline_dfs(VesData3D_Trans,VesData3D.rootpoint);
% % VesData3D_Trans=VesData3D_Trans(Resort,:);
% % VesData3D_Seg=Segm(VesData3D_Trans,VesData3D.adj);
% % 
% % VesData3D_Proj=Proj(VesData3D_Trans',VesData3D.K);
% % VesData3D_Proj(:,2)=512-VesData3D_Proj(:,2);

Corr = OGMM_soft_correspondence_gated(VesData3D.adj, VesData3D_Proj, VesData2D, scene, ...
                                sigmas(3), sigma_ori, beta_ori);
VesData2D_Match=Corr.q_hat;

tps = tps_fit_2d(VesData3D_Proj, VesData2D_Match, 1e-2); % lambda平滑度
VesData3D_Proj = tps_warp_2d(tps, VesData3D_Proj);


figure;
num_file=regexp(VesData2D.DSA_Path, '\d+', 'match');
num_file=str2double(num_file{end}); 
%%原始DSA路径
DSA_OriPath=['F:\Registration\SequenceFile\seq_',num2str(newSeqNum),'\frame_',sprintf('%04d',num_file),'.png'];
I=imread(DSA_OriPath);
imshow(I);
hold on
plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'.','Color',[83/255,214/255,0/255],'MarkerSize',3);

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
Err=mean(diss);
text(12,480,['Score:',num2str(Err)],'FontSize',25,'Color',[233/255,144/255,0]);

ax = gca;
ax.Visible = 'off';
% exportgraphics(ax,'C:\Users\Lzx\Desktop\配准\paper_miccai\experiment_picture\NonRigid\TPS_CTO1_ori_nontext.png');







% figure;
% plot(VesData2D.Centerline(:,1),512-VesData2D.Centerline(:,2),'g.');
% hold on
% plot(Corr.q_hard(:,1),512-Corr.q_hard(:,2),'r.');








function [E, g] = MeasureError_OGMM(T, VesData3D, VesData2D, scene, sigma, alpha, sigma_ori, beta_ori)
% Computes:  E = alpha * (1/N^2) sum_ij exp(-||zi-zj||^2/(4σ^2))
%            - 2 * (1/(NM)) sum_ij exp(-||zi-yj||^2/(4σ^2))
% where zi are 2D projections of transformed 3D points.

VesData3D_Trans=Trans(T,VesData3D);%转化为DSA坐标
VesData3D_Proj=Proj(VesData3D_Trans,VesData2D.K); %横


VesData2D_Centerline=VesData2D.Centerline;

N = size(VesData3D_Proj,1);
M = size(VesData2D_Centerline,1);

[D3, w3] = ComputeTangent2D(VesData3D_Proj, VesData3D.adj);
D2 = scene.D2;  w2 = scene.w2;


% % Handle sign ambiguity: allow +/- for directions
% D3p = D3;  D3n = -D3;
% D2p = D2;  D2n = -D2;


Cff = abs(D3 * D3.');     % NxN
Cfg = abs(D3 * D2.');     % NxM
Dff_ori = 2 * (1 - Cff);
Dfg_ori = 2 * (1 - Cfg);

Wff = w3 * w3.';          % gate bifurcations
Wfg = w3 * w2.';
Dff_ori = Wff .* Dff_ori;
Dfg_ori = Wfg .* Dfg_ori;

% % 4) orientation distances (use unit vectors; squared Euclidean in R^2)
% % For sign ambiguity, we take the BEST match among +/- (or average—see note below).
% Dff_ori_pp = pdist2(D3p, D3p, 'squaredeuclidean');  % NxN
% Dff_ori_pn = pdist2(D3p, D3n, 'squaredeuclidean');  % NxN (equiv sign flip)
% % For self term, directions are from same set; using min(pp, pn) makes it sign-invariant.
% Dff_ori = min(Dff_ori_pp, Dff_ori_pn);
% W = w3 * w3.';
% Dff_ori = W .* Dff_ori;
% 
% Dfg_ori_pp = pdist2(D3p, D2p, 'squaredeuclidean');  % NxM
% Dfg_ori_pn = pdist2(D3p, D2n, 'squaredeuclidean');  % NxM
% Dfg_ori = min(Dfg_ori_pp, Dfg_ori_pn);
% W = w3 * w2.';
% Dfg_ori = W .* Dfg_ori;


kori_ff = exp(-beta_ori * Dff_ori / (4*sigma_ori*sigma_ori));
kori_fg = exp(-beta_ori * Dfg_ori / (4*sigma_ori*sigma_ori));


% pairwise squared distances
Dff = pdist2(VesData3D_Proj, VesData3D_Proj, 'squaredeuclidean');   
Dfg = pdist2(VesData3D_Proj, VesData2D_Centerline, 'squaredeuclidean');     

kpos_ff = exp(-Dff / (4*sigma*sigma));
kpos_fg = exp(-Dfg / (4*sigma*sigma));


kff = kpos_ff.*kori_ff;
kfg = kpos_fg.*kori_fg;

selfOverlap  = sum(kff(:)) / (N*N);
crossOverlap = sum(kfg(:)) / (N*M);

E = alpha * selfOverlap - 2.0 * crossOverlap;


% dE/dZ for position part, treating kori as constant wrt P3
% cross: -2/(NM) sum_ij kfg_ij
% grad_cross_i = (1/(NM*sigma^2)) * sum_j kfg_ij * (z_i - y_j)
sumWfg = sum(kfg, 2);          % Nx1
termY  = kfg * VesData2D_Centerline;             % Nx2
grad_cross_Z = ( (VesData3D_Proj .* sumWfg) - termY ) / (N*M*sigma*sigma);  % Nx2

% self: alpha/(N^2) sum_ij kff_ij
% grad_self_i = -(alpha/(N^2*sigma^2)) * sum_j kff_ij * (z_i - z_j)
sumWff = sum(kff, 2);          % Nx1
termZ  = kff * VesData3D_Proj;             % Nx2
grad_self_Z = -(alpha / (N*N*sigma*sigma)) * ( (VesData3D_Proj .* sumWff) - termZ ); % Nx2

gradZ = grad_self_Z + grad_cross_Z;   % Nx2

% chain rule: dE/dT = (dE/dProj)*dProj/dT
% NOTE: VesData3D_Trans inside ProjJacobian_T is recomputed via Trans(T,..),
% so call ProjJacobian_T here to be consistent.
Jproj = ProjJacobian_T(T, VesData3D, VesData2D.K);  % 2N x 6

gradZ_vec = reshape(gradZ.', [], 1); % [dx1;dy1;dx2;dy2;...]
g = Jproj.' * gradZ_vec;             % 6x1

end


function [D, w] = ComputeTangent2D(P,adj)
% Compute unit tangents for an ordered 2D polyline P (Nx2).
% Use central difference; endpoints use forward/backward.
N = size(P,1);
D = zeros(N,2);

degree = sum(adj,2);
w = ones(N,1);

for i = 1:N
    if degree(i)==1
        neighbor = find(adj(i,:)==1);
        D(i,:) = P(neighbor(1),:) - P(i,:);
    elseif degree(i)>=3 || degree(i)==0
        w(i) = 0;
        D(i,:)=[0 0];%!!新加
    else
        neighbor = find(adj(i,:)==1);
        D(i,:) = P(neighbor(1),:) - P(neighbor(2),:);
    end
end

% normalize
nrm = sqrt(sum(D.^2,2)) + 1e-12;
D = D ./ nrm;

% optional: smooth tangents a bit (helps noisy 2D centerlines)
% D = smoothdata(D, 1, 'movmean', 5);
% renormalize
% nrm = sqrt(sum(D.^2,2)) + 1e-12;
% D = D ./ nrm;
end



% function Corr = OGMM_soft_correspondence(adj, VesData3D_Proj, VesData2D, scene, sigma, sigma_ori, beta_ori)
% 
% P2 = VesData2D.Centerline;
% 
% [D3,w3] = ComputeTangent2D(VesData3D_Proj, adj);
% D2 = scene.D2; w2 = scene.w2;
% 
% Dfg = pdist2(VesData3D_Proj, P2, 'squaredeuclidean');
% kpos_fg = exp(-Dfg/(4*sigma*sigma));
% 
% Cfg = abs(D3*D2.');
% Dfg_ori = 2*(1-Cfg);
% Dfg_ori = (w3*w2.') .* Dfg_ori;
% kori_fg = exp(-beta_ori*Dfg_ori/(4*sigma_ori*sigma_ori));
% 
% K = kpos_fg .* kori_fg;              % NxM
% W = K ./ (sum(K,2)+1e-12);           % NxM
% 
% Corr.W = W;                          % soft weights
% Corr.q_hat = W * P2;                 % expected correspondences Nx2
% [~, Corr.idx] = max(W,[],2);         % optional hard index
% Corr.q_hard = P2(Corr.idx,:);        % optional hard points
% Corr.P3 = VesData3D_Proj;            % projected 3D points
% end
% function Corr = OGMM_soft_correspondence_gated(adj, P3, VesData2D, scene, sigma, sigma_ori, beta_ori)
% P3: Nx2 projected points
% 输出：
%   Corr.W: NxM soft weights (for inliers; outliers rows are all 0)
%   Corr.q_hat: Nx2 expected 2D match (outliers -> NaN)
%   Corr.idx: Nx1 hard match index (outliers -> NaN)
%   Corr.inlier: Nx1 logical
%   Corr.score: Nx1 matching quality score (sumK in probability scale)

% P2 = VesData2D.Centerline;
% N  = size(P3,1);
% M  = size(P2,1);
% 
% [D3,w3] = ComputeTangent2D(P3, adj);
% D2 = scene.D2; w2 = scene.w2;
% 
% % distances
% Dfg = pdist2(P3, P2, 'squaredeuclidean');
% 
% % orientation distance in [0,2]
% Cfg = abs(D3*D2.');
% Dfg_ori = 2*(1 - Cfg);
% Dfg_ori = (w3*w2.') .* Dfg_ori;
% 
% % --- compute logK to avoid underflow ---
% logK = -Dfg/(4*sigma*sigma) + (-beta_ori * Dfg_ori/(4*sigma_ori*sigma_ori)); % NxM
% 
% % log-sum-exp per row
% mx = max(logK, [], 2);
% Kstable = exp(logK - mx);              % NxM in [0,1]
% sumKstable = sum(Kstable, 2);          % Nx1
% W = Kstable ./ (sumKstable + 1e-12);   % NxM
% 
% % Convert back to a "score" in original scale (optional)
% % sumK = exp(mx) .* sumKstable;  % Nx1  (may overflow if extremely large; usually fine)
% 
% % --- gating criteria ---
% % 1) based on distance: nearest 2D point too far => outlier
% dmin = sqrt(min(Dfg, [], 2));          % Nx1 pixel distance
% 
% % 2) based on sharpness
% wmax = max(W, [], 2);
% 
% % You can tune these thresholds:
% tau_dist = 3*sigma;     % e.g. 3*sigma pixels
% tau_wmax = 0.03;        % e.g. require at least 3% mass on best match
% 
% inlier = (dmin <= tau_dist) & (wmax >= tau_wmax);
% 
% % output
% Corr.W = zeros(N,M);
% Corr.W(inlier,:) = W(inlier,:);
% 
% Corr.q_hat = nan(N,2);
% Corr.q_hat(inlier,:) = Corr.W(inlier,:) * P2;
% 
% Corr.idx = nan(N,1);
% [~, idx] = max(W, [], 2);
% Corr.idx(inlier) = idx(inlier);
% 
% Corr.q_hard = nan(N,2);
% Corr.q_hard(inlier,:) = P2(Corr.idx(inlier),:);
% 
% Corr.P3 = P3;
% Corr.inlier = inlier;
% Corr.dmin = dmin;
% Corr.wmax = wmax;
% end