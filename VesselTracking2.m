function [] = VesselTracking2(VesData3D,adj_matrix,Number_seq,Ves2D,dir,Num,outDir,VesData3D_Seg)

if dir==1
    seq_list=Number_seq+1:1:Num;
else
    seq_list=Number_seq:-1:1;
end

u0=256;v0=256;
K=VesData3D.K;
dx=VesData3D.dx;
f=VesData3D.f;


%% 刚性变换设置
%设置初始点
pitch=0;yaw=0;roll=0;
t_x=-5:5:5; %可否更精确一点
t_y=-5:5:5;
t_z=-5:5:5;

Num_ip=length(pitch)*length(yaw)*length(roll)*length(t_x)*length(t_y)*length(t_z);
InitPoints=zeros(Num_ip,6);
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

options = optimoptions('particleswarm','SwarmSize',Num_ip,'InitialPoints',InitPoints,'UseParallel',true,'HybridFcn','patternsearch','FunctionTolerance',5e-2);
lb=[-0.05,-0.07,-0.07,-8.5,-8.5,-8.5]; %!!!
ub=[0.05,0.07,0.07,8.5,8.5,8.5];

%% 追踪
for Number_seq=seq_list
    tic
    %读二维图
    VesData2D=Ves2D{Number_seq};

    fun=@(x)MeasureError(x,VesData3D,VesData2D);
    [T,res]=particleswarm(fun,6,lb,ub,options)
    % Visualization(T,VesData3D,VesData2D);
    

    N=size(VesData3D.node_positions,1);
    VesData3D_Trans=Trans(T,VesData3D);
    VesData3D_Trans=VesData3D_Trans';
    VesData3D_Init=VesData3D_Trans;
    VesData3D_Proj=Proj(VesData3D_Trans',VesData2D.K);

    %点对应

    [VesData2D_Match,weight_solve]=DenseMatching(VesData3D_Seg,VesData2D,N,VesData3D_Proj,VesData3D.w);
    VesData2D_Match=(VesData2D_Match-u0)*dx;
    % VesData3D_Match=[VesData2D_Match(:,1),repmat(f,[N,1]),VesData2D_Match(:,2)];%改投影前！！！！
    VesData3D_Match=[VesData2D_Match(:,1),VesData2D_Match(:,2),repmat(f,[N,1])];

    k=0.18; %0.16
    Q=zeros(3,3,N);
    VesData3D_Match_nt=VesData3D_Match./vecnorm(VesData3D_Match,2,2);
    VesData3D_Match_n=VesData3D_Match_nt';
    for i=1:N
        Q(:,:,i)=VesData3D_Match_n(:,i)*VesData3D_Match_nt(i,:)-eye(3);
    end
    
    
    for step=1:100%steps
        grad=zeros(N,3);
        for i=1:N
            number_adj=find(adj_matrix(i,:));
            grad(i,:)=2*k*VesData3D_Trans(i,:)*Q(:,:,i)*Q(:,:,i);%*weight_solve(i);
            for j=number_adj
                grad(i,:)=grad(i,:)+2*(VesData3D_Trans(i,:)-VesData3D_Trans(j,:)-(VesData3D_Init(i,:)-VesData3D_Init(j,:)));
            end
        end
        VesData3D_Trans=VesData3D_Trans-0.05*grad;
        VesData3D_Proj=Proj(VesData3D_Trans',VesData2D.K);
        if mean(vecnorm(grad,2,2))<0.05
            break;
        end

    end

    toc
    %%%画非刚性结构图
    figure;
    num_file=regexp(VesData2D.DSA_Path, '\d+', 'match');
    num_file=str2double(num_file{end}); 
    DSA_OriPath=[outDir,'\',sprintf('frame_%04d',num_file),'.png'];
    I=imread(DSA_OriPath);
    imshow(I);
    hold on  
    % plot(VesData2D.Centerline(:,1),512-VesData2D.Centerline(:,2),'.','Color',[83/255,214/255,0/255],'MarkerSize',3);
    for i=1:numel(VesData3D_Seg)
        temp=VesData3D_Seg(i).idx;
        plot(VesData3D_Proj(temp,1),512-VesData3D_Proj(temp,2),'Color',[247/255,10/255,18/255],'LineWidth',1.5);
    end

    x=round(VesData3D_Proj(:,1));y=512-round(VesData3D_Proj(:,2));
    lg=length(x);
    inx=x<1|x>512|y<1|y>512;
    x(inx)=[];y(inx)=[];
    disterr=VesData2D.img_DT_Centerline(y+512*(x-1));
    Err=sum(disterr)/length(x)+floor((lg-length(x))/20);
    % text(12,480,['Score:',num2str(Err)],'FontSize',25,'Color',[233/255,144/255,0]);
    ax = gca;
    ax.Visible = 'off';
    exportgraphics(ax,['Result\OURS_left_',num2str(num_file),'.png']);
    % 



    % figure;
    % num_file=regexp(VesData2D.DSA_Path, '\d+', 'match');
    % num_file=str2double(num_file{end}); 
    % DSA_OriPath=[outDir,'\',sprintf('frame_%04d',num_file),'.png'];
    % I=imread(DSA_OriPath);
    % imshow(I);
    % 
    % hold on;
    % plot(VesData3D_Proj(:,1),512-VesData3D_Proj(:,2),'r.');
    % axis equal
    filenum = regexp(outDir, '\d+', 'match');
    filenum = filenum{end};
    % saveas(gcf,['Result\','Reg_',filenum,'\',num2str(num_file),'.png']);
    % saveas(gcf,['Result_test\','Reg_',filenum,'\',num2str(num_file),'.png']);
    VesData3D.node_positions=(VesData3D.trans_base*VesData3D_Trans'+repmat(VesData3D.Sourcepoint',1,N))';
end


end
