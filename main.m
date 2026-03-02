clear;clc;
addpath(genpath(pwd));

load('VesData3D.mat');
[Resort,adj_3d]=reconstruct_centerline_dfs(VesData3D.node_positions,VesData3D.rootpoint);%根节点695！！！/625
VesData3D.node_positions=VesData3D.node_positions(Resort,:);
VesData3D.rootpoint=1;  %重构后根节点变为1
VesData3D.adj=adj_3d;

deg3d=sum(VesData3D.adj,2);
VesData3D_Seg=Segm(VesData3D.node_positions,adj_3d,1);

%% 刚性配准
tic
File_name=dir(fullfile('Ves2D','*.mat'));
Num = length(File_name);
   
Res=zeros(Num,1);
T_all=zeros(Num,6);
VesData2D_all=cell(Num,1);

%%%%%%
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

lb=[-0.13,-0.25,-0.25,-40,-30,-40];
ub=[0.13,0.25,0.25,40,30,40];


%
Ves2D=cell(Num,1);
for i=1:Num
    load(['Ves2D/VesData2D_',num2str(i),'.mat']);
    Ves2D{i}=VesData2D;
end


parfor iseq=1:Num %1:Num
    VesData2D=Ves2D{iseq};
    fun=@(x)MeasureError(x,VesData3D,VesData2D);
      
    options = optimoptions('particleswarm','SwarmSize',N,'InitialPoints',InitPoints,...
    'UseParallel',false,'HybridFcn','patternsearch','FunctionTolerance',5e-2);

    [T,res]=particleswarm(fun,6,lb,ub,options);

    % Visualization(T,VesData3D,VesData2D,newSeqNum,VesData3D_Seg);
    
    T_all(iseq,:)=T;
    Res(iseq)=res;
    VesData2D_all{iseq}=VesData2D;

end

[~,idx_seq]=min(Res);
Number_seq=idx_seq;
VesData2D_min=VesData2D_all{idx_seq};


VesData2D_min.Centerline=clear_smallbatch(VesData2D_min.Centerline);
VesData2D_min.adj=buildadj(VesData2D_min.Centerline);
%联通一些点
VesData2D_min.adj=connect_2dgraph(VesData2D_min.Centerline,VesData2D_min.adj);
[VesData2D_min.Centerline,VesData2D_min.adj]=clear_brancheslen(VesData2D_min.Centerline,VesData2D_min.adj,20);



Tmin=T_all(idx_seq,:);
T=Tmin;

VesData3D_Trans=Trans(T,VesData3D);
VesData3D_Proj=Proj(VesData3D_Trans,VesData3D.K);


figure;
num_file=regexp(VesData2D_min.DSA_Path, '\d+', 'match');
num_file=str2double(num_file{end}); 
%%原始DSA路径
DSA_OriPath=['SequenceFile\seq_',num2str(1),'\frame_',sprintf('%04d',num_file),'.png'];
I=imread(DSA_OriPath);
imshow(I);
hold on
plot(VesData2D_min.Centerline(:,1),512-VesData2D_min.Centerline(:,2),'.','Color',[83/255,214/255,0/255],'MarkerSize',3);
for i=1:numel(VesData3D_Seg)
    temp=VesData3D_Seg(i).idx;
    plot(VesData3D_Proj(temp,1),512-VesData3D_Proj(temp,2),'Color',[247/255,10/255,18/255],'LineWidth',1.5);
end
x=round(VesData3D_Proj(:,1));y=512-round(VesData3D_Proj(:,2));
lg=length(x);
inx=x<1|x>512|y<1|y>512;
x(inx)=[];y(inx)=[];
disterr=VesData2D_min.img_DT_Centerline(y+512*(x-1));
Err=sum(disterr)/length(x)+floor((lg-length(x))/20);

text(12,480,['Score:',num2str(Err)],'FontSize',25,'Color',[233/255,144/255,0]);

ax = gca;
ax.Visible = 'off';


%% 非刚性配准




VesData3D_Trans=VesData3D_Trans';
N=size(VesData3D_Trans,1);

VesData3D.node_positions=(VesData3D.trans_base*VesData3D_Trans'+repmat(VesData3D.Sourcepoint',1,N))';
%将投影落在外面的点去除
VesData3D_Proj=Proj(VesData3D_Trans',VesData3D.K);
x=VesData3D_Proj(:,1);y=VesData3D_Proj(:,2);
inx=x<1|x>size(VesData2D_min.img_DT,2)|y<1|y>size(VesData2D_min.img_DT,1);
VesData3D.node_positions(inx,:)=[];

%去除后adj_matrix矩阵产生变化，因此再作一次重构顺序
[Resort,VesData3D.adj]=reconstruct_centerline_dfs(VesData3D.node_positions,VesData3D.rootpoint);
VesData3D.node_positions=VesData3D.node_positions(Resort,:);

VesData3D_Trans=Trans(zeros(6,1),VesData3D);
VesData3D_Seg=Segm(VesData3D_Trans',VesData3D.adj);

VesData3D.w=Calc_weight(size(VesData3D.node_positions,1),VesData2D_min,VesData3D_Seg);

outDir='SequenceFile\seq_1';
dir=-1;
VesselTracking2(VesData3D,VesData3D.adj,Number_seq,Ves2D,dir,Num,outDir,VesData3D_Seg);
dir=1;
VesselTracking2(VesData3D,VesData3D.adj,Number_seq,Ves2D,dir,Num,outDir,VesData3D_Seg);

res_path='Result/';
images_to_gif(res_path,fullfile(res_path,'reg.gif'),1/8);

%%播放gif
gifFile = fullfile(res_path,'reg.gif');
[im, map] = imread(gifFile, 'gif', 'Frames', 'all');

figure;
while true
    for k = 1:size(im, 4)
        if isempty(map)
            imshow(im(:,:,:,k));
        else
            imshow(im(:,:,k), map);
        end
        drawnow;
        pause(1/8);   % 控制播放速率（秒）
    end
end