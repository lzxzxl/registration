clear,clc;
addpath(genpath(pwd));


%!!!!!要改的量，物理间距参数，dicom文件序号,CTA路径,根节点号
% 有512- 
%!!选择 DICOM 文件
seq_dicom = 5; %为0表示时间最新的

%load('CTA_Centralline_left1231_2.mat','vessel_3DLine');
% load('CTA_Centralline_yqr625850.mat','vessel_3DLine');
load('CTA_Centralline_wyg11739230.mat','vessel_3DLine');
% load('CTA_Centralline.mat','vessel_3DLine');
% load('CTA_Centralline_2_right.mat','vessel_3DLine'); %WANGXUNXIAN
% spacing = struct('x', 0.33, 'y', 0.33, 'z', 0.5);   %%WANGXUNXIAN
% spacing = struct('x', 0.3281, 'y', 0.3281, 'z', 0.5);   
spacing = struct('x', 0.42, 'y', 0.42, 'z', 0.5);  %wang,yqr
% spacing = struct('x', 0.43359, 'y', 0.43359, 'z', 0.4); 
rootpoint=686;  %894 ni   wang you 426 zuo 686   yu zuo 916  WANGXUNXIAN625 873 385

%人工定义二维根节点
root2d_id=164; %123,883,164

iseq=8;



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


% 找最高分支
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
[yy,xx]=find(CL);
img_DT_Centerline=bwdist(CL);
..................................
Centerline=[xx,512-yy];

% 构建输出结构体
VesData2D = struct('node_positions', coordinates,'img_DT',img_DT, ...
    'K',K, 'img_DT_Centerline',img_DT_Centerline,...
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
deg2d=sum(VesData2D.adj,2);
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


% [~,idx_seq]=mink(Res,4)



%% 非刚性配准
load('./Experiment/CTO1_data.mat');


folder=fullfile(outpath,'\');

VesData3D_Trans=data;
[Resort,VesData3D.adj]=reconstruct_centerline_dfs(VesData3D_Trans,VesData3D.rootpoint);
VesData3D_Trans=VesData3D_Trans(Resort,:);
VesData3D_Seg=Segm(VesData3D_Trans,VesData3D.adj);
VesData3D_Proj=Proj(VesData3D_Trans',VesData3D.K);
deg3d=sum(VesData3D.adj,2);
%处理二维
[Ves_tree_2d,par_2d]=extract_feature_tree(VesData2D.adj,1);
pf_2d = par_2d(Ves_tree_2d);
%处理三维
[Ves_tree_3d,par_3d]=extract_feature_tree(VesData3D.adj,1);
pf_3d = par_3d(Ves_tree_3d);
G=digraph(pf_3d,Ves_tree_3d);
Traverseorder=bfsearch(G,1);%遍历顺序

%将叶子节点排到分岔点后
isLeaf = (deg3d(Traverseorder) == 1);
isLeaf(1) = false;  
Traverseorder= [Traverseorder(~isLeaf);Traverseorder(isLeaf)];


Nodes(1).FeaturePair=[1,1]; 
level=6;%找level层内的对应点 
for i=1:length(pf_3d) 
    
    Idx_3D=Traverseorder(i+1); 
    Idx_3D_parent=par_3d(Idx_3D); %pf(find(Ves_tree==Idx_3D)); 
    
    if i>=5 %通过误差剪枝
        Num_nodes_temp=size(Nodes,2); 
        delete_id=[];
        Err_frechet=zeros(Num_nodes_temp,1);
        for j=1:Num_nodes_temp
            id3d=Nodes(j).FeaturePair(:,1);
            id2d=Nodes(j).FeaturePair(:,2);

            Err_temp=[];
            for k=2:length(id3d)
                if id2d(k)==0, continue;end %无对应 是否要加权重
                [branch_3d,branch_2d]=PointPair(k,id3d,id2d,VesData3D_Seg,VesData2D_Seg,par_3d,par_2d); %frechet距离
                dist=frechet_distance(VesData3D_Proj(branch_3d,:),VesData2D.Centerline(branch_2d,:));
                Err_temp(end+1)=dist;
            end
            Err_frechet(j)=mean(Err_temp);
      
        end
        if Num_nodes_temp>1000
            [~,idx_err]=mink(Err_frechet,600);
            Nodes=Nodes(idx_err);
        end
    end
    %端点不参与匹配 

    Num_nodes_temp=size(Nodes,2); 
    if deg3d(Idx_3D)==1
        level=4;
    else
        level=6;
    end
    for j=1:Num_nodes_temp 
        %找父节点的对应点
        Idx_2D_parent=Nodes(j).FeaturePair(Nodes(j).FeaturePair(:,1)==Idx_3D_parent,2); 
        %找level层内所有孩子
        if deg3d(Idx_3D)==1
            node_childs=[0];
        else
            node_childs=[];
        end
        father=Idx_2D_parent; 
        for k=1:level 
            child=find(ismember(par_2d,father)); %孩子索引 
            if isempty(child), break; end %找不到孩子就退出 
            %孩子不能包含兄弟对应的,孩子不能是叶子节点
            if deg3d(Idx_3D)~=1
                child(deg2d(child)==1)=[]; 
            end
            child(ismember(child,Nodes(j).FeaturePair(:,2)))=[]; 
            node_childs=[node_childs;child]; 
            father=child; 
        end 
        %形成点对应 
        if isempty(node_childs), continue;end
        for k=1:length(node_childs) 
            Nodes(end+1).FeaturePair=[Nodes(j).FeaturePair;Idx_3D,node_childs(k)]; 
        end 
    end 
    Nodes(1:Num_nodes_temp)=[]; %for j=1:Num_nodes_temp Nodes(j)=[]; end 删了这语句快了几十秒!!!!
end

Err=zeros(size(Nodes,2),1);
for i=1:size(Nodes,2)
    id3d=Nodes(i).FeaturePair(:,1);
    id2d=Nodes(i).FeaturePair(:,2);
    Num_notmatch=length(find(id2d==0));
    Err_temp=[];
    for j=2:length(id3d)
        if id2d(j)==0, continue;end
        [branch_3d,branch_2d]=PointPair(j,id3d,id2d,VesData3D_Seg,VesData2D_Seg,par_3d,par_2d); %frechet距离
        dist=frechet_distance(VesData3D_Proj(branch_3d,:),VesData2D.Centerline(branch_2d,:));
        Err_temp(end+1)=dist;
    end
    Err(i)=mean(Err_temp);
end
[res,idx]=min(Err);
FeaturePair=Nodes(idx).FeaturePair;
Err=res;






% figure;
% plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'g.');
% hold on
% plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'r.');
% 
% xx=FeaturePair(:,1);yy=FeaturePair(:,2);
% xx(yy==0)=[];yy(yy==0)=[];
% XX=[VesData3D_Proj(xx,1)';VesData2D.Centerline(yy,1)'];
% YY=[VesData3D_Proj(xx,2)';VesData2D.Centerline(yy,2)'];
% 
% line(XX,YY);

%对未对应的端点找周围点，根据DTW判断最优，若最近点距离较小，则不找周围点
%其他对应点判断距离，如果较大则重新按最近点来找
VesData2D_Match=zeros(size(VesData3D_Proj,1),2);
NS=createns(VesData2D.Centerline,'NSMethod','kdtree');
[idxs,~]=knnsearch(NS,VesData3D_Proj,'k',1);
vessel_2Dmatch=VesData2D.Centerline(idxs,:);   %投影点在DSA分割血管中的最近对应点
VesData2D=Clean_vessel2d(VesData2D,VesData3D_Proj);


for i=2:size(FeaturePair,1) 
    
    id_3d=FeaturePair(i,1);id_2d=FeaturePair(i,2);
    id_3d_parent=par_3d(id_3d);
    id_parent=find(FeaturePair(:,1)==id_3d_parent);
    id_2d_parent=FeaturePair(id_parent,2);
    path_3did=[];

    for j=1:numel(VesData3D_Seg)
        temp=VesData3D_Seg(j).idx;
        if(temp(1)==id_3d_parent&&temp(end)==id_3d)
            path_3did=temp;
            break;
        end
    end

    vestemp_proj2=round(VesData3D_Proj(path_3did,:));
    Projimg=zeros(512,512);
    for j=1:size(vestemp_proj2,1)
        x=vestemp_proj2(j,1); %!!新增
        y=512-vestemp_proj2(j,2);%!!新增
        x = min(max(x, 1), 511);%!!新增
        y = min(max(y, 1), 511);%!!新增
        Projimg(y,x)=1;%!!新增
    end
    Projimg_DT=bwdist(Projimg);


    if id_2d==0
        corr_closest=vessel_2Dmatch(id_3d,:);
        inx=find(ismember(VesData2D.Centerline,corr_closest,'rows'));
        if norm(VesData3D_Proj(id_3d,:)-corr_closest)>20
            VesData2D_Match(path_3did(2:end),:)=NaN;
        else
            startpot=VesData2D.Centerline(id_2d_parent,:);
            endpot=VesData2D.Centerline(inx,:);
            [xs,ys,f]=shortestway2d(VesData2D.Map,[startpot(1),endpot(1)],[512-startpot(2),512-endpot(2)],1,2,Projimg_DT,VesData2D.img_DT);
            if f==0
                VesData2D_Match(path_3did(2:end),:)=NaN;
                continue;
            end
            vestemp_2d=[xs',512-ys'];

            n3 = numel(path_3did);
            n2 = numel(xs);
            
            % 生成恰好 n3 个、落在 [1,n2] 的 2D 索引（允许重复）
            idx2 = round(linspace(1, n2, n3));
            idx2 = max(1, min(n2, idx2));   % 防越界
            
            VesData2D_Match(path_3did, :) = vestemp_2d(idx2,:); 
        end
        continue;
    end

    if norm(VesData3D_Proj(id_3d,:)-VesData2D.Centerline(id_2d,:))<10
        %确定每个点对应
        % path_2did=path_between_nodes(VesData2D.adj,id_2d_parent,id_2d);
        % n3 = numel(path_3did);
        % n2 = numel(path_2did);
        % 
        % % 生成恰好 n3 个、落在 [1,n2] 的 2D 索引（允许重复）
        % idx2 = round(linspace(1, n2, n3));
        % idx2 = max(1, min(n2, idx2));   % 防越界
        % 
        % VesData2D_Match(path_3did, :) = VesData2D.Centerline(path_2did(idx2), :);
        startpot=VesData2D.Centerline(id_2d_parent,:);
        endpot=VesData2D.Centerline(id_2d,:);
        [xs,ys,f]=shortestway2d(VesData2D.Map,[startpot(1),endpot(1)],[512-startpot(2),512-endpot(2)],1,2,Projimg_DT,VesData2D.img_DT);
        if f==0
            VesData2D_Match(path_3did(2:end),:)=NaN;
            continue;
        end
        vestemp_2d=[xs',512-ys'];

        n3 = numel(path_3did);
        n2 = numel(xs);
        
        % 生成恰好 n3 个、落在 [1,n2] 的 2D 索引（允许重复）
        idx2 = round(linspace(1, n2, n3));
        idx2 = max(1, min(n2, idx2));   % 防越界
        
        VesData2D_Match(path_3did, :) = vestemp_2d(idx2,:); 
    else
        corr_closest=vessel_2Dmatch(id_3d,:);
        inx=find(ismember(VesData2D.Centerline,corr_closest,'rows'));
        if norm(VesData3D_Proj(id_3d,:)-corr_closest)>10
            VesData2D_Match(path_3did(2:end),:)=NaN;
        else
            % path_2did=path_between_nodes(VesData2D.adj,id_2d_parent,inx);
            % n3 = numel(path_3did);
            % n2 = numel(path_2did);
            % 
            % % 生成恰好 n3 个、落在 [1,n2] 的 2D 索引（允许重复）
            % idx2 = round(linspace(1, n2, n3));
            % idx2 = max(1, min(n2, idx2));   % 防越界
            % 
            % VesData2D_Match(path_3did, :) = VesData2D.Centerline(path_2did(idx2), :);
            startpot=VesData2D.Centerline(id_2d_parent,:);
            endpot=VesData2D.Centerline(inx,:);
            [xs,ys,f]=shortestway2d(VesData2D.Map,[startpot(1),endpot(1)],[512-startpot(2),512-endpot(2)],1,2,Projimg_DT,VesData2D.img_DT);
            if f==0
                VesData2D_Match(path_3did(2:end),:)=NaN;
                continue;
            end
            vestemp_2d=[xs',512-ys'];

            n3 = numel(path_3did);
            n2 = numel(xs);
            
            % 生成恰好 n3 个、落在 [1,n2] 的 2D 索引（允许重复）
            idx2 = round(linspace(1, n2, n3));
            idx2 = max(1, min(n2, idx2));   % 防越界
            
            VesData2D_Match(path_3did, :) = vestemp_2d(idx2,:); 
            FeaturePair(i,2)=inx;
        end
    end
    
end

tps = tps_fit_2d(VesData3D_Proj, VesData2D_Match, 20); % lambda平滑度
VesData3D_Proj = tps_warp_2d(tps, VesData3D_Proj);

figure;
num_file=regexp(VesData2D.DSA_Path, '\d+', 'match');
num_file=str2double(num_file{end}); 
%%原始DSA路径
DSA_OriPath=['F:\Registration\SequenceFile\seq_',num2str(newSeqNum),'\frame_',sprintf('%04d',num_file),'.png'];
I=imread(DSA_OriPath);
imshow(I);
hold on
plot(VesData2D.Centerline(:,1),512-VesData2D.Centerline(:,2),'.','Color',[83/255,214/255,0/255],'MarkerSize',3);

for i=1:numel(VesData3D_Seg)
    temp=VesData3D_Seg(i).idx;
    plot(VesData3D_Proj(temp,1),512-VesData3D_Proj(temp,2),'Color',[247/255,10/255,18/255],'LineWidth',1.5);
end

x=round(VesData3D_Proj(:,1));y=512-round(VesData3D_Proj(:,2));
lg=length(x);
inx=x<1|x>512|y<1|y>512;
x(inx)=[];y(inx)=[];
disterr=img_DT_Centerline(y+512*(x-1));
Err=sum(disterr)/length(x)+floor((lg-length(x))/20);
text(12,480,['Score:',num2str(Err)],'FontSize',25,'Color',[233/255,144/255,0]);
ax = gca;
ax.Visible = 'off';
exportgraphics(ax,'C:\Users\Lzx\Desktop\配准\paper_miccai\experiment_picture\NonRigid\CARNet_CTO1.png');


%%






% pyExe    = "C:/Users/Lzx/.conda/envs/carnet/python.exe";
% inferPy  = "F:/Pyproject/CAR-Net/infer_mat.py";
% ckptPath = "F:/Pyproject/CAR-Net/carnet.pt";
% 
% K = VesData3D.K;
% 
% VesData3D_proj_final = zeros(N,2);
% % ooo='F:/Registration/func/Car-Net/test.npz';
% figure;
% plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'g.');
% hold on
% plot(VesData2D_Match(:,1),VesData2D_Match(:,2),'b.')
% axis equal

% for i = 1:numel(VesData3D_Seg)
%     idx = VesData3D_Seg(i).idx;
% 
%     c3d = VesData3D_Trans(idx,:);
% 
%     % 你的“起点对齐”逻辑保留
%     % if i ~= 1
%     %     deltx = VesData3D_def(idx(1),:) - VesData3D_Trans(idx(1),:);
%     %     c3d = c3d + deltx;
%     % end
% 
%     c2d = VesData2D_Match(idx,:);
%     inx=find(c2d==0);
%     if ~isempty(inx)
%         continue;
%     end
% 
%     c3d_final=resample_polyline(c3d,100);
%     c2d_final=resample_polyline(c2d,100);
% 
% 
% 
%     out = infer_segment_system(pyExe, inferPy, ckptPath, c3d_final, c2d_final, K);
% 
%     N_final=size(c3d_final,1);
%     idx_c=round(linspace(1,N_final,size(c3d,1)));
%     idx_c(1)=1;idx_c(end)=N_final;
%     VesData3D_def(idx,:) = out.c3d_def(idx_c,:);
%     VesData3D_proj_final(idx,:)=out.c2d_proj(idx_c,:);
%     % plot(out.c2d_proj(:,1),out.c2d_proj(:,2),'r.');
% 
% end




% pyenv("Version","C:/Users/Lzx/.conda/envs/carnet/python.exe",'ExecutionMode','InProcess');
% 
% 
% % py.importlib.import_module("_ctypes")
% % 
% sys = py.importlib.import_module("sys");
% sys.path.insert(int32(0), "F:/Pyproject/CAR-Net"); % 让 Python 能找到 model.py 等
% 
% np = py.importlib.import_module("numpy");
% bridge = py.importlib.import_module("carnet_bridge");
% 
% dev = bridge.init("carnet.pt");  % 模型加载一次
% disp(dev);
% 
% % % 每段推理
% % c3d_py = np.asarray(single(c3d));  % c3d: N×3
% % c2d_py = np.asarray(single(c2d));  % c2d: N×2
% % K_py   = np.asarray(single(K));    % 3×3
% % 
% % out = bridge.infer_segment(c3d_py, c2d_py, K_py);
% % 
% % defl    = double(out{"defl"});
% % c3d_def = double(out{"c3d_def"});
% % c2d_proj= double(out{"c2d_proj"});
% 
% K_py=py.numpy.array(single(VesData3D.K));
% 
% % VesData3D_euc=Trans_spherical(VesData3D_Trans,adj_matrix,1);
% VesData3D_def=zeros(N,3);
% for i=1:size(VesData3D_Seg,2)
%     temp=VesData3D_Seg(i).idx;
%     c3d=VesData3D_Trans(temp,:);
%     if i~=1
%         deltx=VesData3D_def(temp(1),:)-VesData3D_Trans(temp(1),:);
%         c3d=c3d+deltx;
%     end
% 
%     c2d=VesData2D_Match(temp,:);
%     c3d_py = py.numpy.array(single(c3d));  % c3d: N×3
%     c2d_py = py.numpy.arrayy(single(c2d));  % c2d: N×2    
%     out = bridge.infer_segment(c3d_py, c2d_py, K_py);
%     c3d_def = double(out{"c3d_def"}); %!!
%     VesData3D_def(temp,:)=c3d_def;
% end
