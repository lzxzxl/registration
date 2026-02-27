%%%
%跟踪实验！！！
%导入数据
%做不同程度非刚性形变
%设置不同程度噪声/不同程度缺失
%做初始位姿扰动
clear,clc;
addpath(genpath(pwd));
rootPath = 'F:\NativeData\Dataset-of-vascular-tree-point-set-main\data\data';
subs = dir(rootPath);
subs = subs([subs.isdir] & ~ismember({subs.name},{'.','..'}));
allDirs = dir(fullfile(rootPath, "**"));
allDirs = allDirs([allDirs.isdir] & ~ismember({allDirs.name},{'.','..'}));

num_simdata=10;
Simulate_Data(num_simdata,1) = struct();

for i = 1:num_simdata
    folderPath = fullfile(allDirs(i).folder, allDirs(i).name);
    mats = dir(fullfile(folderPath, "*.mat"));
    [~, idx] = sort({mats.name});
    firstMat = mats(idx(1));
    matPath = fullfile(folderPath, firstMat.name);
    S = load(matPath);
    Ves3D=S.X;
    [Resort,adj_3d]=reconstruct_centerline_dfs(Ves3D,1);
    Ves3D=Ves3D(Resort,:);
    deg3d=sum(adj_3d,2);
    endIdx = find(deg3d == 1);        
    [~, k]  = max(Ves3D(endIdx, 3));   
    idx = endIdx(k);                   % 找Z坐标最高的端点作为根节点
    %根据找到的根节点重排索引
    [Resort,adj_3d]=reconstruct_centerline_dfs(Ves3D,idx);
    Ves3D=Ves3D(Resort,:);
    deg3d=sum(adj_3d,2);
    Display=(max(Ves3D)+min(Ves3D))/2;
    Ves3D_move=Ves3D-repmat(Display,size(Ves3D,1),1);

    %% 设定照相机位姿变换
    K=[3570,0,256;0,3570,256;0,0,1];
    dx=0.335;
    Angle_Z=0;Angle_X=0;
    a=Angle_Z*pi/180;b=Angle_X*pi/180;
    dxc=765;
    p_base=sqrt(1+tan(a)^2+tan(b)^2);
    p_x=dxc*tan(a)/p_base;
    p_y=-dxc/p_base;
    p_z=dxc*tan(b)/p_base;
    p=[p_x,p_y,p_z];
    z_axis=-p./dxc;
    y_axis=[0,-p_z/sqrt(p_z^2+p_y^2),p_y/sqrt(p_z^2+p_y^2)];
    x_base=sqrt((p_y^2+p_z^2)^2+p_x^2*p_y^2+p_x^2*p_z^2);
    x_axis=[(p_y^2+p_z^2)/x_base,-p_x*p_y/x_base,-p_x*p_z/x_base];
    trans_base=[x_axis',y_axis',z_axis'];
    w=ones(size(Ves3D_move,1),1);
    VesData3D = struct('node_positions', Ves3D_move,'trans_base',trans_base, ...
    'Sourcepoint',p,'rootpoint',1,'K',K,'dx',dx,'w',w,'adj',adj_3d);
    N=size(Ves3D_move,1);


    %% 形变
    para_d=0.1; %0.1,0.2,0.25,0.3,0.4
    Ves_Trans=Trans(zeros(6,1),VesData3D);
    [Ves3D_sph,parent]=Trans_spherical(Ves_Trans',VesData3D.adj,1);


    % Ves3D_sph = Add_anglenoise(Ves3D_sph,parent,para_d); %对三维点生成形变
    % Ves3D_euc = Trans_euc(Ves3D_sph,parent); 
    % 
    % Ves_Proj_True=Proj(Ves3D_euc',VesData3D.K); %真实投影

    %tracking实验
    Ves_Proj_True_seq=cell(5,1);
    VesData2D_seq=cell(5,1);
    for jj=1:5
        Ves3D_sph = Add_anglenoise(Ves3D_sph,parent,para_d); %对三维点生成形变
        Ves3D_euc = Trans_euc(Ves3D_sph,parent); 
        Ves_Proj_True=Proj(Ves3D_euc',VesData3D.K); %真实投影
        Ves_Proj_True_seq{jj}=Ves_Proj_True;


        %% 插值
        temp=Ves_Proj_True(1,:);
        for j=2:N
            p=parent(j);
            d=norm(Ves_Proj_True(j,:)-Ves_Proj_True(p,:));
            if d>1
                n = ceil(d);
                t = (1:n-1)'/n;               % 只取内部节点，避免重复端点
                ins = Ves_Proj_True(p,:) + t .* (Ves_Proj_True(j,:)-Ves_Proj_True(p,:));            % 均匀插值点
                temp = [temp; ins; Ves_Proj_True(j,:)];
            else
                temp = [temp;Ves_Proj_True(j,:)];
            end
        end
        Ves2D=temp;
        %% 增加噪声
        para_n=400; %噪声 200 400 600 800 1000
        para_m=5; %缺失 1,2,3,4,5
        para_t=2; %位姿 1 2 3 4 5

        rng_noise=i*100+para_t*10+para_n+para_m*20+jj;%噪声幅度和种子

        [pts,~]=gen_points_chain(para_n,rng_noise);
        Ves2D=[Ves2D;pts];
        %% 构建VesData2D
        cols=round(Ves2D(:,1));
        rows=round(Ves2D(:,2));

        Map=zeros(512,512);
        idx = sub2ind([512 512], rows, cols);
        Map(idx) = 1;
        Map = imdilate(Map, true(3));

        img_DT=bwdist(Map);

        VesData2D = struct('img_DT',img_DT,'K',K,'Centerline',Ves2D,'Map',Map);
        root2d_id=1;
        %去掉小分量,给根节点位置还变了
        VesData2D.Centerline=clear_smallbatch(VesData2D.Centerline);
        VesData2D.adj=buildadj(VesData2D.Centerline);

        %联通一些点
        % VesData2D.adj=connect_2dgraph(VesData2D.Centerline,VesData2D.adj);
        % [VesData2D.Centerline,VesData2D.adj]=clear_brancheslen(VesData2D.Centerline,VesData2D.adj,5); 
        VesData2D.adj=break_cycles(VesData2D.adj,root2d_id);

        %重排索引
        [VesData2D.Centerline,VesData2D.adj]=dfs_reorder_2d(VesData2D.Centerline,VesData2D.adj,root2d_id);
        root2d_id=1; 
        %% 制造缺失
        deg_2d=sum(VesData2D.adj,2);
        inx_endpot=find(deg_2d==1);
        inx_endpot(inx_endpot==1)=[];
        dd=sum((VesData2D.Centerline(inx_endpot,:)-VesData2D.Centerline(1,:)).^2,2);
        [~,idx_select]=maxk(dd,para_m);

        inx_del=[];
        for j=1:length(idx_select)
            start=inx_endpot(idx_select(j));
            inx_temp=start;
            for k=1:para_m*20
                if deg_2d(start-1)>2
                    break;
                end
                inx_temp=[inx_temp,start-1];
                start=start-1;
            end
            inx_del=[inx_del,inx_temp];
        end
        VesData2D.Centerline(inx_del,:)=[];

        %%
        VesData2D.adj=buildadj(VesData2D.Centerline);

        %联通一些点
        % VesData2D.adj=connect_2dgraph(VesData2D.Centerline,VesData2D.adj);
        VesData2D.adj=break_cycles(VesData2D.adj,root2d_id);
        %重排索引
        [VesData2D.Centerline,VesData2D.adj]=dfs_reorder_2d(VesData2D.Centerline,VesData2D.adj,root2d_id);
        root2d_id=1; 
        VesData2D_Seg=Segm(VesData2D.Centerline,VesData2D.adj);

        VesData2D_seq{jj}=VesData2D;
    end


    %% 设置位姿干扰
    R=(rand(100000,1) - 0.5) * (0.1+para_t/10);
    yu=0.5*(0.1+(para_t-1)/10);
    if para_t~=1
        R(R>-yu&R<yu)=[];
    end
    R=[R(1),R(2),R(3)];

    t=(rand(100000,1) - 0.5) * 12*para_t; 
    yu=0.5*12*(para_t-1);
    t(t>-yu&t<yu)=[];
    t=[t(1),t(2),t(3)];

    T=[R,t];
    %估计真值
    T_True=Get_True_T(T);
    VesData3D_Trans=Trans(T,VesData3D); %DSA坐标

    VesData3D.node_positions=(VesData3D.trans_base*VesData3D_Trans+repmat(VesData3D.Sourcepoint',1,N))';

    %% 初始位姿


    %%      
    Simulate_Data(i).VesData3D=VesData3D;
    Simulate_Data(i).Ves_Proj_True_seq=Ves_Proj_True_seq;
    Simulate_Data(i).VesData2D_seq=VesData2D_seq;
    Simulate_Data(i).T_True=T_True;
end
save('F:/Registration/Experiment/simdata_track/Simdata_miss5.mat','Simulate_Data');

load('F:/Registration/Experiment/simdata_track/Simdata_trans1.mat');

% t_OURS=zeros(num_simdata,1);
% t_OURS_NR=zeros(num_simdata,1);
% mTRE_OURS=zeros(num_simdata,1);
% mTRE_OURS_NR=zeros(num_simdata,1);
% 
% 
% %设置初始点
% pitch=[-0.15,0,0.15];
% % yaw=-0.3:0.2:0.3;
% % roll=-0.3:0.2:0.3;
% yaw=[-0.15,0,0.15];
% roll=[-0.15,0,0.15];
% t_x=-10:20:10;
% t_y=[-10,10];
% t_z=-10:20:10; %20间距
% 
% N=length(pitch)*length(yaw)*length(roll)*length(t_x)*length(t_y)*length(t_z);
% InitPoints=zeros(N,6);
% i=1;
% for t1=pitch
%     for t2=yaw
%         for t3=roll
%             for t4=t_x
%                 for t5=t_y
%                     for t6=t_z
%                         InitPoints(i,:)=[t1,t2,t3,t4,t5,t6];
%                         i=i+1;
%                     end
%                 end
%             end
%         end
%     end
% end
% %%%%%%
% 
% lb=[-0.13,-0.25,-0.25,-40,-30,-40];
% ub=[0.13,0.25,0.25,40,30,40];
% options = optimoptions('particleswarm','SwarmSize',N,'InitialPoints',InitPoints,...
% 'UseParallel',true,'HybridFcn','patternsearch','FunctionTolerance',5e-2);
% 
% u0=256;dx=0.3;f=dx*3570;
% 
% for i=1:num_simdata
%     tic
%     VesData3D=Simulate_Data(i).VesData3D;
%     VesData2D_seq=Simulate_Data(i).VesData2D_seq;
%     T_True=Simulate_Data(i).T_True;
%     Ves_Proj_True_seq=Simulate_Data(i).Ves_Proj_True_seq;
% 
%     for jj=1:5
%         Ves_Proj_True=Ves_Proj_True_seq{jj};
%         %% 刚性
%         VesData2D=VesData2D_seq{jj};
%         VesData3D_Trans=Trans(zeros(6,1),VesData3D);
%         VesData3D_Proj=Proj(VesData3D_Trans,VesData3D.K);
%         N=size(VesData3D_Proj,1);
%         fun=@(x)MeasureError_exp(x,VesData3D,VesData2D);
%         [T,res]=particleswarm(fun,6,lb,ub,options);
%         %% 计算误差
%         VesData3D_Trans=Trans(T,VesData3D);
%         VesData3D_Proj=Proj(VesData3D_Trans,VesData3D.K);
% 
%         % dis=sqrt(sum((VesData3D_Proj-Ves_Proj_True).^2,2));
%         % mTRE_OURS(i)=mean(dis);
% 
% 
%         %% 非刚性
%         VesData3D_Trans=VesData3D_Trans';
%         VesData3D_Seg=Segm(VesData3D_Trans,VesData3D.adj);
%         [VesData2D_Match,~]=DenseMatching_exp(VesData3D_Seg,VesData2D,N,VesData3D_Proj,VesData3D.w);
%         VesData2D_Match=(VesData2D_Match-u0)*dx;
%         VesData3D_Match=[VesData2D_Match(:,1),VesData2D_Match(:,2),repmat(f,[N,1])];
%         k=0.4; %0.16
%         Q=zeros(3,3,N);
%         VesData3D_Match_nt=VesData3D_Match./vecnorm(VesData3D_Match,2,2);
%         VesData3D_Match_n=VesData3D_Match_nt';
%         for j=1:N
%             Q(:,:,j)=VesData3D_Match_n(:,j)*VesData3D_Match_nt(j,:)-eye(3);
%         end
% 
%         VesData3D_Init=VesData3D_Trans;
%         for step=1:100
%             grad=zeros(N,3);
%             for I=1:N
%                 number_adj=find(VesData3D.adj(I,:));
%                 grad(I,:)=2*k*VesData3D_Trans(I,:)*Q(:,:,I)*Q(:,:,I);%*weight_solve(i);
%                 for j=number_adj
%                     grad(I,:)=grad(I,:)+2*(VesData3D_Trans(I,:)-VesData3D_Trans(j,:)-(VesData3D_Init(I,:)-VesData3D_Init(j,:)));
%                 end
%             end
%             VesData3D_Trans=VesData3D_Trans-0.05*grad;
%             VesData3D_Proj=Proj(VesData3D_Trans',VesData2D.K);
%             if mean(vecnorm(grad,2,2))<0.1 
%                 break;
%             end
% 
%         end
%         VesData3D.node_positions=(VesData3D.trans_base*VesData3D_Trans'+repmat(VesData3D.Sourcepoint',1,N))';
% 
%         %% 计算误差
%         dis=sqrt(sum((VesData3D_Proj-Ves_Proj_True).^2,2));
%         mTRE_OURS_NR(i)=mTRE_OURS_NR(i)+mean(dis);
% 
%         % figure;
%         % plot(Ves_Proj_True(:,1),Ves_Proj_True(:,2),'y.');
%         % hold on
%         % plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'g.');
%         % plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'r.');
%         % xlim([0,520]);
%         % ylim([0,520]);
%         % axis equal
%     end
% 
% t_OURS(i)=toc;
% mTRE_OURS_NR(i)=mTRE_OURS_NR(i)/5;
% 
% 
%     %%
%     % figure;
%     % plot(Ves_Proj_True(:,1),Ves_Proj_True(:,2),'y.');
%     % hold on
%     % plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'g.');
%     % plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'r.');
% 
% end
% 
% % mTRE_OURS=mean(mTRE_OURS);
% t_OURS=mean(t_OURS);
% mTRE_OURS_NR=mean(mTRE_OURS_NR);
% % t_OURS_NR=mean(t_OURS_NR);
% % sprintf("OURS----- mTRE:%f,mR:%f,mt:%f,t:%f",mTRE_OURS,mR_OURS,mt_OURS,t_OURS)
% sprintf("OURS----- mTRE_NR:%f,t:%f",mTRE_OURS_NR,t_OURS)