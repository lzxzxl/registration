%%%
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

num_simdata=62;
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
    Ves3D_sph = Add_anglenoise(Ves3D_sph,parent,para_d); %对三维点生成形变
    Ves3D_euc = Trans_euc(Ves3D_sph,parent); 

    Ves_Proj_True=Proj(Ves3D_euc',VesData3D.K); %真实投影

    %tracking实验
    Ves_Proj_True_seq=cell(5,1);
    Ves_Proj_True_seq{1}=Ves_Proj_True;
    for jj=2:5
        Ves3D_sph = Add_anglenoise(Ves3D_sph,parent,para_d); %对三维点生成形变
        Ves3D_euc = Trans_euc(Ves3D_sph,parent); 
        Ves_Proj_True_seq{jj}=Proj(Ves3D_euc',VesData3D.K); %真实投影
    end


    %% 
    %插值
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
    para_m=2; %缺失 1,2,3,4,5
    para_t=2; %位姿 1 2 3 4 5

    rng_noise=i*100+para_t*10+para_n+para_m;%噪声幅度和种子


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
    Simulate_Data(i).Ves_Proj_True=Ves_Proj_True;
    Simulate_Data(i).VesData2D=VesData2D;
    Simulate_Data(i).T_True=T_True;
end
% save('F:/Registration/Experiment/simdata_t/Simdata_deform5.mat','Simulate_Data');
% load('F:/Registration/Experiment/simdata_20/Simdata_miss3.mat');

% 
% for i=1:num_simdata
%     VesData3D=Simulate_Data(i).VesData3D;
%     VesData2D=Simulate_Data(i).VesData2D;
%     ttt=Trans(Simulate_Data(i).T_True,VesData3D);
%     ttt=Trans(zeros(6,1),VesData3D);
%     ppp=Proj(ttt,K);
%     figure;
%     plot(Simulate_Data(i).Ves_Proj_True(:,1),Simulate_Data(i).Ves_Proj_True(:,2),'g.');
%     hold on
%     % plot(ppp(:,1),ppp(:,2),'r.');
%     plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'r*');
%     x=ppp(:,1);y=ppp(:,2);x=round(x);y=round(y);
%     disterr=VesData2D.img_DT(y+512*(x-1));
%     sum(disterr)/length(x);
% end


% %% ICP+Deformable
% t_ICP=zeros(num_simdata,1);
% mTRE_ICP=zeros(num_simdata,1);
% mR_ICP=zeros(num_simdata,1);
% mt_ICP=zeros(num_simdata,1);
% 
% t_Def=zeros(num_simdata,1);
% mTRE_Def=zeros(num_simdata,1);
% 
% for i=1:num_simdata
%     tic
%     VesData3D=Simulate_Data(i).VesData3D;
%     VesData2D=Simulate_Data(i).VesData2D;
%     T_True=Simulate_Data(i).T_True;
%     Ves_Proj_True=Simulate_Data(i).Ves_Proj_True;
%     %% 
% 
%     VesData3D_Trans=Trans(zeros(6,1),VesData3D);
%     VesData3D_Proj=Proj(VesData3D_Trans,VesData3D.K);
%     % figure;
%     % plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'g.');
%     % hold on
%     % plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'r.');
% 
%     N=size(VesData3D_Proj,1);
%     %KDtree 找最近点
%     NS=createns(VesData2D.Centerline,'NSMethod','kdtree');
%     [idxs,~]=knnsearch(NS,VesData3D_Proj,'k',1);
%     vessel_2Dmatch=VesData2D.Centerline(idxs,:);
%     VesData3D_Trans=VesData3D_Trans';
%     steps=100;
%     Err1=10000;
%     for i_step=1:steps
%         [R,t,~]=myPnP(VesData3D_Trans,vessel_2Dmatch,VesData3D.K,'myPnP');
%         VesData3D_Trans=R*VesData3D_Trans'+t;
%         VesData3D_Proj=Proj(VesData3D_Trans,VesData3D.K);
%         VesData3D_Trans=VesData3D_Trans';
%         x=round(VesData3D_Proj(:,1));y=round(VesData3D_Proj(:,2));
%         lg=length(x);
%         inx=x<1|x>512|y<1|y>512;
%         x(inx)=[];y(inx)=[];
%         disterr=VesData2D.img_DT(y+512*(x-1));
%         Err2=sum(disterr)/length(x)+floor((lg-length(x))/20);
% 
%         if abs(Err2-Err1)<0.005
%             break;
%         end
%         Err1=Err2;
%         %找新的对应点
%         [idxs,~]=knnsearch(NS,VesData3D_Proj,'k',1);
%         vessel_2Dmatch=VesData2D.Centerline(idxs,:);
% 
%     end        
%     %% 计算误差
%     t_ICP(i)=toc;
%     dis=sqrt(sum((VesData3D_Proj-Ves_Proj_True).^2,2));
%     mTRE_ICP(i)=mean(dis);
%     VesData3D_reg=(VesData3D.trans_base*VesData3D_Trans'+repmat(VesData3D.Sourcepoint',1,N))';
%     [R_reg,t_reg,~]=rigid_align_3d(VesData3D.node_positions,VesData3D_reg);
%     R_true=genR(T_True(1:3)); %欧拉角变成旋转矩阵
%     t_true=T_True(4:6).'; %3*1
%     Rerr = R_reg' * R_true;
%     Omega = logm(Rerr);
%     theta = norm(Omega, 'fro') / sqrt(2);    % rad
%     mR_ICP(i) = real(theta) * 180/pi;
%     mt_ICP(i)=norm(t_reg-t_true);
%     %% Deformable
%     tic
%     opts = struct('nOuter',8,'nInner',150,'alphaLen',1,'beta0',0.01,...
%     'gamma',0.95,'R0',80,'Rmin',20);
% 
%     % softassign 超参数
%     opts.softassign = struct('T_init',500,'T_final',1,'T_update',0.93,...
%         'nNormIters',60,'sigma2',-1,'slackAff',1e-3,'epsMass',0.01,'Kcand',7,'Kout',5);
%     [phi, out] = Nonrigid_deform(VesData3D.adj, VesData2D.Centerline, VesData3D_Trans, VesData3D.K, opts);
% 
%     X_def = VesData3D_Trans + phi;
%     VesData3D_Proj=Proj(X_def',VesData3D.K);
%     %% 计算误差
%     t_Def(i)=toc;
%     dis=sqrt(sum((VesData3D_Proj-Ves_Proj_True).^2,2));
%     mTRE_Def(i)=mean(dis);
% 
% end
% 
% mTRE_ICP=mean(mTRE_ICP);
% mt_ICP=mean(mt_ICP);
% mR_ICP=mean(mR_ICP);
% t_ICP=mean(t_ICP);
% mTRE_Def=mean(mTRE_Def);
% t_Def=mean(t_Def);
% 
% sprintf("ICP----- mTRE:%f,mR:%f,mt:%f,t:%f",mTRE_ICP,mR_ICP,mt_ICP,t_ICP)
% sprintf("Def----- mTRE:%f,t:%f",mTRE_Def,t_Def) 

% %% OGMM+TPS
% t_OGMM=zeros(num_simdata,1);
% mTRE_OGMM=zeros(num_simdata,1);
% mR_OGMM=zeros(num_simdata,1);
% mt_OGMM=zeros(num_simdata,1);
% t_TPS=zeros(num_simdata,1);
% mTRE_TPS=zeros(num_simdata,1);
% for i=1:num_simdata
%     tic
%     VesData3D=Simulate_Data(i).VesData3D;
%     VesData2D=Simulate_Data(i).VesData2D;
%     T_True=Simulate_Data(i).T_True;
%     Ves_Proj_True=Simulate_Data(i).Ves_Proj_True;
%     %% 
% 
%     VesData3D_Trans=Trans(zeros(6,1),VesData3D);
%     VesData3D_Proj=Proj(VesData3D_Trans,VesData3D.K);
%     N=size(VesData3D_Proj,1);
% 
% 
%     [scene.D2, scene.w2] = ComputeTangent2D(VesData2D.Centerline, VesData2D.adj);
% 
%     alpha = 0.2;               % downweight self-overlap in 2D-3D (projection may overlap)
%     sigmas = [20, 10, 5, 3];   % multi-scale kernel widths in pixels (coarse->fine)
%     maxIterPerScale = 200;
% 
%     sigma_ori = 0.45;            % 方向核尺度（建议 0.25~0.6，见下方解释）
%     beta_ori  = 1.0;             % 方向项权重（1.0 表示按核自然融合；也可调大更依赖方向）
% 
%     T=zeros(6,1);
%     hist = [];
%     opts = optimoptions('fminunc', ...
%             'Display','off',...
%             'Algorithm', 'quasi-newton', ...
%             'MaxIterations', maxIterPerScale, ...
%             'SpecifyObjectiveGradient', true); % (we use numeric gradient)
%     for s = 1:numel(sigmas)
%         sigma = sigmas(s);
%         fun = @(x)MeasureError_OGMM(x, VesData3D, VesData2D, scene, sigma, alpha, sigma_ori, beta_ori);
%         [T, fval] = fminunc(fun, T, opts);
%     end
%     VesData3D_Trans=Trans(T,VesData3D);
%     VesData3D_Proj=Proj(VesData3D_Trans,VesData2D.K);
% 
%     %% 计算误差
%     t_OGMM(i)=toc;
%     dis=sqrt(sum((VesData3D_Proj-Ves_Proj_True).^2,2));
%     mTRE_OGMM(i)=mean(dis);
%     R_true=genR(T_True(1:3)); %欧拉角变成旋转矩阵
%     R_reg=genR(T(1:3));
%     t_true=T_True(4:6).'; %3*1
%     t_reg=T(4:6).';
%     Rerr = R_reg' * R_true;
%     Omega = logm(Rerr);
%     theta = norm(Omega, 'fro') / sqrt(2);    % rad
%     mR_OGMM(i) = real(theta) * 180/pi;
%     mt_OGMM(i)=norm(t_reg-t_true);
%     %% 
%     % figure;
%     % plot(Ves_Proj_True(:,1),Ves_Proj_True(:,2),'y.');
%     % hold on
%     % plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'g.');
%     % plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'b*');
%     %% 非刚性
%     tic
%     Corr = OGMM_soft_correspondence_gated(VesData3D.adj, VesData3D_Proj, ...
%         VesData2D, scene, sigmas(numel(sigmas)), sigma_ori, beta_ori);
%     VesData2D_Match=Corr.q_hat;
%     tps = tps_fit_2d(VesData3D_Proj, VesData2D_Match, 1e-2); % lambda平滑度
%     VesData3D_Proj = tps_warp_2d(tps, VesData3D_Proj);
%     %% 计算误差
%     t_TPS(i)=toc;
%     dis=sqrt(sum((VesData3D_Proj-Ves_Proj_True).^2,2));
%     mTRE_TPS(i)=mean(dis);
% 
% end
% mTRE_OGMM=mean(mTRE_OGMM);
% mt_OGMM=mean(mt_OGMM);
% mR_OGMM=mean(mR_OGMM);
% t_OGMM=mean(t_OGMM);
% t_TPS=mean(t_TPS);
% mTRE_TPS=mean(mTRE_TPS);
% sprintf("OGMM----- mTRE:%f,mR:%f,mt:%f,t:%f",mTRE_OGMM,mR_OGMM,mt_OGMM,t_OGMM)
% sprintf("TPS----- mTRE:%f,t:%f",mTRE_TPS,t_TPS)

% %% Tree
% t_TREE=zeros(num_simdata,1);
% mTRE_TREE=zeros(num_simdata,1);
% mR_TREE=zeros(num_simdata,1);
% mt_TREE=zeros(num_simdata,1);
% t_CAR_NR=zeros(num_simdata,1);
% mTRE_CAR_NR=zeros(num_simdata,1);
% for i=1:num_simdata
%     tic
%     VesData3D=Simulate_Data(i).VesData3D;
%     VesData2D=Simulate_Data(i).VesData2D;
%     T_True=Simulate_Data(i).T_True;
%     Ves_Proj_True=Simulate_Data(i).Ves_Proj_True;
%     %% 
%     VesData3D_Trans=Trans(zeros(6,1),VesData3D);
%     VesData3D_Proj=Proj(VesData3D_Trans,VesData3D.K);
%     N=size(VesData3D_Proj,1);
% 
%     [VesData3D_Proj,VesData3D_Trans,FeaturePair,par_3d]=POINTCORR_TREE(VesData3D,VesData2D);
%     if any(VesData3D_Proj(:)==0) && i~=1
%         t_TREE(i)=t_TREE(i-1);
%         t_CAR_NR(i)=t_CAR_NR(i-1);
%         mTRE_CAR_NR(i)=mTRE_CAR_NR(i-1);
%         mTRE_TREE(i)=mTRE_TREE(i-1);
%         mt_TREE(i)=mR_TREE(i-1);
%         mR_TREE(i)=mR_TREE(i-1);
%         continue;
%     elseif any(VesData3D_Proj(:)==0) && i==1
%         t_TREE(i)=1;
%         t_CAR_NR(i)=1;
%         mTRE_CAR_NR(i)=NaN;
%         mTRE_TREE(i)=NaN;
%         mt_TREE(i)=NaN;
%         mR_TREE(i)=NaN;
%         continue;
%     end    
% 
%     %% 计算误差
%     t_TREE(i)=toc;
%     dis=sqrt(sum((VesData3D_Proj-Ves_Proj_True).^2,2));
%     mTRE_TREE(i)=mean(dis);
%     VesData3D_reg=(VesData3D.trans_base*VesData3D_Trans+repmat(VesData3D.Sourcepoint',1,N))';
%     [R_reg,t_reg,~]=rigid_align_3d(VesData3D.node_positions,VesData3D_reg);
%     R_true=genR(T_True(1:3)); %欧拉角变成旋转矩阵
%     t_true=T_True(4:6).'; %3*1
%     Rerr = R_reg' * R_true;
%     Omega = logm(Rerr);
%     theta = norm(Omega, 'fro') / sqrt(2);    % rad
%     mR_TREE(i) = real(theta) * 180/pi;
%     mt_TREE(i)=norm(t_reg-t_true);    
% 
%     %%
%     % figure;
%     % plot(Ves_Proj_True(:,1),Ves_Proj_True(:,2),'y.');
%     % hold on
%     % plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'g.');
%     % plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'b*');
%     %% 非刚性
%     tic
%     VesData3D_Seg=Segm(VesData3D_Trans',VesData3D.adj,1);
%     VesData2D_Match=POINTCORR_ALL(FeaturePair,VesData3D_Proj,VesData3D_Seg,par_3d,VesData2D);
%     tps = tps_fit_2d(VesData3D_Proj, VesData2D_Match, 2); % lambda平滑度
%     VesData3D_Proj = tps_warp_2d(tps, VesData3D_Proj);
% 
%     %% 计算误差 
%     t_CAR_NR(i)=toc;
%     dis=sqrt(sum((VesData3D_Proj-Ves_Proj_True).^2,2));
%     mTRE_CAR_NR(i)=mean(dis);
%     % figure;
%     % plot(Ves_Proj_True(:,1),Ves_Proj_True(:,2),'y.');
%     % hold on
%     % plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'g.');
%     % plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'b*');
% end
% mTRE_TREE=mean(mTRE_TREE);
% mt_TREE=mean(mt_TREE);
% mR_TREE=mean(mR_TREE);
% t_TREE=mean(t_TREE);
% mTRE_CAR_NR=mean(mTRE_CAR_NR);
% t_CAR_NR=mean(t_CAR_NR);
% sprintf("TREE----- mTRE:%f,mR:%f,mt:%f,t:%f",mTRE_TREE,mR_TREE,mt_TREE,t_TREE)
% sprintf("CARNET-----mTRE:%f,t:%f",mTRE_CAR_NR,t_CAR_NR)

% %% MCTS
% t_MCTS=zeros(num_simdata,1);
% t_MCTS_NR=zeros(num_simdata,1);
% mTRE_MCTS=zeros(num_simdata,1);
% mTRE_MCTS_NR=zeros(num_simdata,1);
% mR_MCTS=zeros(num_simdata,1);
% mt_MCTS=zeros(num_simdata,1);
% 
% for i=1:num_simdata
%     tic
%     VesData3D_temp=Simulate_Data(i).VesData3D;
%     VesData2D_temp=Simulate_Data(i).VesData2D;
%     T_True=Simulate_Data(i).T_True;
%     Ves_Proj_True=Simulate_Data(i).Ves_Proj_True;
%     %% 准备3D数据接口
%     VesData3D_Trans=Trans(zeros(6,1),VesData3D_temp);
%     VesData3D_Proj=Proj(VesData3D_Trans,VesData3D_temp.K);
%     VesData3D_Trans=VesData3D_Trans';
%     N=size(VesData3D_Proj,1);
% 
%     adj_3d=VesData3D_temp.adj;
%     adj_3d_directed = adj_3d;
%     adj_3d_directed(tril(true(size(adj_3d)), -1)) = 0;   %有向矩阵
%     NodeType=zeros(1,N);
%     deg3d=sum(adj_3d,2);
%     NodeType(deg3d == 1) = 1;
%     NodeType(deg3d == 2) = 2;
%     NodeType(deg3d == 3) = 3; %特征点种类        
%     [Ves_tree_3d,par_3d]=extract_feature_tree(adj_3d,1);
%     pf_3d = par_3d(Ves_tree_3d);
%     NodeIdxs=[1,Ves_tree_3d']; %特征点索引
%     NodeIdxs_par=[0,pf_3d'];
%     [Graph_Sparse,Graph_Sparse_Directed]=buildadj_full(NodeIdxs,NodeIdxs_par);%特征点索引的邻接矩阵和有向矩阵
%     VesselPoints_Sparse=VesData3D_Trans(NodeIdxs,:);%特征点坐标
%     VesData3D_Seg=Segm(VesData3D_Trans,adj_3d,1);
%     BranchesCell=cell(size(VesData3D_Seg,2),1);
%     for j=1:size(VesData3D_Seg,2)    
%         EdgePointsIDs=VesData3D_Seg(j).idx;
%         [tf, IDs] = ismember(EdgePointsIDs([1 end]), NodeIdxs);
%         EdgePoints=VesData3D_Seg(j).positions;
%         BranchesCell{j}=struct('IDs',IDs,'EdgePointsIDs',EdgePointsIDs,'EdgePoints',EdgePoints);
%     end
%     VesData3D=struct('Graph_Directed',adj_3d_directed,'Graph',adj_3d,'NodeType',NodeType,'NodeIdxs',NodeIdxs ...
%         ,'VesselPoints', VesData3D_Trans,'Graph_Sparse',Graph_Sparse,'Graph_Sparse_Directed',Graph_Sparse_Directed ...
%         ,'VesselPoints_Sparse',VesselPoints_Sparse,'BranchesCell',{BranchesCell} ...
%         ,'quaternionPara',zeros(1,7));
%     PriorModel=struct('VesselDataRef',VesData3D);
%     VesData3D.PriorModel=PriorModel;
%     %% 准备2D数据接口
%     K=VesData3D_temp.K;
%     adj_2d=VesData2D_temp.adj;
%     Centerline=VesData2D_temp.Centerline;
%     VesData2D_Seg=Segm(Centerline,adj_2d);
%     N=size(adj_2d,1);
%     adj_2d_directed = adj_2d;
%     adj_2d_directed(tril(true(size(adj_2d)), -1)) = 0;   %有向矩阵
%     deg2d=sum(adj_2d,2);
%     %处理二维
%     [Ves_tree_2d,par_2d]=extract_feature_tree(adj_2d,1);
%     pf_2d = par_2d(Ves_tree_2d);
% 
%     NodeType=zeros(1,N);
%     NodeType(deg2d == 1) = 1;
%     NodeType(deg2d == 2) = 2;
%     NodeType(deg2d == 3) = 3; %特征点种类
%     NodeIdxs=[1,Ves_tree_2d']; %特征点索引
%     NodeIdxs_par=[0,pf_2d']; 
%     [Graph_Sparse,Graph_Sparse_Directed]=buildadj_full(NodeIdxs,NodeIdxs_par);
%     VesselPoints_Sparse=Centerline(NodeIdxs,:);
% 
%     BranchesCell=cell(size(VesData2D_Seg,2),1);
%     for j=1:size(VesData2D_Seg,2)
%         EdgePointsIDs=VesData2D_Seg(j).idx;
%         [tf, IDs] = ismember(EdgePointsIDs([1 end]), NodeIdxs);
%         EdgePoints=VesData2D_Seg(j).positions;
%         BranchesCell{j}=struct('IDs',IDs,'EdgePointsIDs',EdgePointsIDs,'EdgePoints',EdgePoints);
%     end
%     VesData2D=struct('Graph_Directed',adj_2d_directed,'Graph',adj_2d,'NodeType',NodeType ...
%     ,'NodeIdxs',NodeIdxs,'VesselPoints',Centerline,'Graph_Sparse',Graph_Sparse ...
%     ,'Graph_Sparse_Directed',Graph_Sparse_Directed,'VesselPoints_Sparse',VesselPoints_Sparse ...
%     ,'BranchesCell',{BranchesCell},'K',K);
% 
%     %% 刚性配准
% 
%     if ~isfield(VesData2D,'img_DT')
%         img_centerline = centerlineToImage(VesData2D.VesselPoints,[2500,2500]);
%         VesData2D.img_DT = bwdist(img_centerline);
%     end
%     config=makeconfigMC;
%     config.VesData3D=VesData3D;
%     config.VesData2D=VesData2D;
%     tic
%     VesData3DReg=MCTSR(config);
%     VesData3D_Proj=Proj(VesData3DReg.VesselPoints',VesData2D.K);
%     % figure;
%     % plot(Ves_Proj_True(:,1),Ves_Proj_True(:,2),'y.');
%     % hold on
%     % plot(VesData2D_temp.Centerline(:,1),VesData2D_temp.Centerline(:,2),'g.');
%     % plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'b*');
%     %% 计算误差
%     t_MCTS(i)=toc;
%     dis=sqrt(sum((VesData3D_Proj-Ves_Proj_True).^2,2));
%     mTRE_MCTS(i)=mean(dis);
% 
%     N=size(VesData3D_Proj,1); 
%     VesData3D_Trans=VesData3DReg.VesselPoints'; 
%     VesData3D_reg=(VesData3D_temp.trans_base*VesData3D_Trans+repmat(VesData3D_temp.Sourcepoint',1,N))';
%     [R_reg,t_reg,~]=rigid_align_3d(VesData3D_temp.node_positions,VesData3D_reg);%%%关键
%     R_true=genR(T_True(1:3)); %欧拉角变成旋转矩阵
%     t_true=T_True(4:6).'; %3*1
%     Rerr = R_reg' * R_true;
%     Omega = logm(Rerr);
%     theta = norm(Omega, 'fro') / sqrt(2);    % rad
%     mR_MCTS(i) = real(theta) * 180/pi;
%     mt_MCTS(i)=norm(t_reg-t_true);    
% 
%     %% 非刚性
%     tic
%     VesData3DReg = ManifoldRegularized(VesData3DReg,VesData2D,config);
%     VesData3D_Proj=Proj(VesData3DReg.VesselPoints',VesData2D.K);
%     %% 计算误差
%     t_MCTS_NR(i)=toc;
%     dis=sqrt(sum((VesData3D_Proj-Ves_Proj_True).^2,2));
%     mTRE_MCTS_NR(i)=mean(dis);
%     %%
% 
% 
% end
% mTRE_MCTS=mean(mTRE_MCTS);
% mTRE_MCTS_NR=mean(mTRE_MCTS_NR);
% mt_MCTS=mean(mt_MCTS);
% mR_MCTS=mean(mR_MCTS);
% t_MCTS=mean(t_MCTS);
% t_MCTS_NR=mean(t_MCTS_NR);
% sprintf("MCTS-----mTRE:%f,mR:%f,mt:%f,t:%f",mTRE_MCTS,mR_MCTS,mt_MCTS,t_MCTS)
% sprintf("MCTS-----mTRE_NR:%f,t_NR:%f",mTRE_MCTS_NR,t_MCTS_NR)

% %% OURS
% 
% t_OURS=zeros(num_simdata,1);
% t_OURS_NR=zeros(num_simdata,1);
% mTRE_OURS=zeros(num_simdata,1);
% mTRE_OURS_NR=zeros(num_simdata,1);
% mR_OURS=zeros(num_simdata,1);
% mt_OURS=zeros(num_simdata,1);
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
%     VesData2D=Simulate_Data(i).VesData2D;
%     T_True=Simulate_Data(i).T_True;
%     Ves_Proj_True=Simulate_Data(i).Ves_Proj_True;
%     %% 刚性
%     VesData3D_Trans=Trans(zeros(6,1),VesData3D);
%     VesData3D_Proj=Proj(VesData3D_Trans,VesData3D.K);
%     N=size(VesData3D_Proj,1);
%     fun=@(x)MeasureError_exp(x,VesData3D,VesData2D);
%     [T,res]=particleswarm(fun,6,lb,ub,options);
% 
%     %% 计算误差
%     t_OURS(i)=toc;
%     VesData3D_Trans=Trans(T,VesData3D);
%     VesData3D_Proj=Proj(VesData3D_Trans,VesData3D.K);
%     dis=sqrt(sum((VesData3D_Proj-Ves_Proj_True).^2,2));
%     mTRE_OURS(i)=mean(dis);
%     R_true=genR(T_True(1:3)); %欧拉角变成旋转矩阵
%     R_reg=genR(T(1:3));
%     t_true=T_True(4:6).'; %3*1
%     t_reg=T(4:6).';
%     Rerr = R_reg' * R_true;
%     Omega = logm(Rerr);
%     theta = norm(Omega, 'fro') / sqrt(2);    % rad
%     mR_OURS(i) = real(theta) * 180/pi;
%     mt_OURS(i)=norm(t_reg-t_true);
%     figure;
%     plot(Ves_Proj_True(:,1),Ves_Proj_True(:,2),'y.');
%     hold on
%     plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'g.');
%     plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'r.');
%     %% 非刚性
%     tic
%     VesData3D_Trans=VesData3D_Trans';
%     VesData3D_Seg=Segm(VesData3D_Trans,VesData3D.adj);
%     [VesData2D_Match,~]=DenseMatching_exp(VesData3D_Seg,VesData2D,N,VesData3D_Proj,VesData3D.w);
%     VesData2D_Match=(VesData2D_Match-u0)*dx;
%     VesData3D_Match=[VesData2D_Match(:,1),VesData2D_Match(:,2),repmat(f,[N,1])];
%     k=0.2; %0.16
%     Q=zeros(3,3,N);
%     VesData3D_Match_nt=VesData3D_Match./vecnorm(VesData3D_Match,2,2);
%     VesData3D_Match_n=VesData3D_Match_nt';
%     for j=1:N
%         Q(:,:,j)=VesData3D_Match_n(:,j)*VesData3D_Match_nt(j,:)-eye(3);
%     end
% 
%     VesData3D_Init=VesData3D_Trans;
%     for step=1:100
%         grad=zeros(N,3);
%         for I=1:N
%             number_adj=find(VesData3D.adj(I,:));
%             grad(I,:)=2*k*VesData3D_Trans(I,:)*Q(:,:,I)*Q(:,:,I);%*weight_solve(i);
%             for j=number_adj
%                 grad(I,:)=grad(I,:)+2*(VesData3D_Trans(I,:)-VesData3D_Trans(j,:)-(VesData3D_Init(I,:)-VesData3D_Init(j,:)));
%             end
%         end
%         VesData3D_Trans=VesData3D_Trans-0.05*grad;
%         VesData3D_Proj=Proj(VesData3D_Trans',VesData2D.K);
%         if mean(vecnorm(grad,2,2))<0.1 
%             break;
%         end
% 
%     end
% 
%     %% 计算误差
%     t_OURS_NR(i)=toc;
%     dis=sqrt(sum((VesData3D_Proj-Ves_Proj_True).^2,2));
%     mTRE_OURS_NR(i)=mean(dis);
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
% mTRE_OURS=mean(mTRE_OURS);
% mt_OURS=mean(mt_OURS);
% mR_OURS=mean(mR_OURS);
% t_OURS=mean(t_OURS);
% mTRE_OURS_NR=mean(mTRE_OURS_NR);
% t_OURS_NR=mean(t_OURS_NR);
% sprintf("OURS----- mTRE:%f,mR:%f,mt:%f,t:%f",mTRE_OURS,mR_OURS,mt_OURS,t_OURS)
% sprintf("OURS----- mTRE_NR:%f,t_NR:%f",mTRE_OURS_NR,t_OURS_NR)