function VesData2D_Match = DenseMatching2(VesData3D_Seg,VesData2D,N,VesData3D_Proj,degree3d)
Num_seg=size(VesData3D_Seg,2);
VesData2D_Match=VesData3D_Proj; %%解决了向零点拉扯的问题
vessel_2D=VesData2D.node_positions; %DSA分割血管
img_DT=VesData2D.img_DT; 
m=size(img_DT,1);
NN=size(vessel_2D,1);

% NS=createns(vessel_2D,'NSMethod','kdtree');
% [idxs,~]=knnsearch(NS,VesData3D_Proj,'k',1);
% vessel_2Dmatch=vessel_2D(idxs,:);   %投影点在DSA分割血管中的最近对应点


VesData2D.Centerline=remove_short_branches(VesData2D.Centerline,11);
% 这里要取消注释
figure;
plot(vessel_2D(:,1),vessel_2D(:,2),'g.');
hold on;
plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'r.');
% plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'b.');
axis equal


adj_ves2d=buildadj(VesData2D.Centerline);
degree=sum(adj_ves2d,2);


for i=1:Num_seg
    vestemp=VesData3D_Seg(i).positions;
    vesidx=VesData3D_Seg(i).idx;
    %vestemp_proj=Proj(vestemp',VesData2D.K); %该段的投影
    vestemp_proj=VesData3D_Proj(vesidx,:);
    veslen_proj=getveslen(vestemp_proj); %长度

    num_pot=size(vestemp,1);%这一段的点数量
    %起点和终点的id号
    startid=VesData3D_Seg(i).idx(1);endid=VesData3D_Seg(i).idx(num_pot);

    vestemp_proj_before=vestemp_proj;

    %找到该段与之前段的邻接点，并整体漂移
    if i~=1
        startid=VesData3D_Seg(i).idx(2);
        ap=vesidx(1);
        ds=VesData2D_Match(ap,:)-vestemp_proj(1,:);
        ds=0;
        vestemp_proj(2:num_pot,:)=vestemp_proj(2:num_pot,:)+ds;
        vestemp_proj(1,:)=[];
        vestemp_proj_before(1,:)=[];
    end

    
    NS=createns(vessel_2D,'NSMethod','kdtree');
    [idxs,~]=knnsearch(NS,vestemp_proj,'k',1);
    vessel_2Dmatch=vessel_2D(idxs,:);   %投影点在DSA分割血管中的最近对应点

    %%%%算误差
    vestemp_proj1=double(round(vestemp_proj));%专门算距离
    x=vestemp_proj1(:,1);
    y=512-vestemp_proj1(:,2);
    x = min(max(x, 1), 511);%！！新增
    y = min(max(y, 1), 511);%！！新增

    disterr=img_DT(y+m*(x-1));
    vestemp_err=mean(disterr);
    %%%%
    

    %！！整体漂移完，虽然误差小，但也要把对应点更新
    % if vestemp_err<0.2
    %     for j=startid:endid
    %         VesData2D_Match(j,:)=vestemp_proj(j-startid+1,:);
    %     end
    %     continue;
    % end  
    
    %求投影的img_DT
    vestemp_proj2=expand_points(vestemp_proj);%%扩充为它周围的四个点
    Projimg=zeros(m,m);
    for j=1:size(vestemp_proj2,1)
        x=vestemp_proj2(j,1); %!!新增
        y=512-vestemp_proj2(j,2);%!!新增
        x = min(max(x, 1), 511);%!!新增
        y = min(max(y, 1), 511);%!!新增
        Projimg(y,x)=1;%!!新增
        % Projimg(m-vestemp_proj2(j,2),vestemp_proj2(j,1))=1;
    end
    
    % vestemp_proj2_before=expand_points(vestemp_proj_before);
    % for j=1:size(vestemp_proj2_before,1)
    %     x=vestemp_proj2_before(j,1);
    %     y=512-vestemp_proj2_before(j,2);
    %     x = min(max(x, 1), 511);%!!新增
    %     y = min(max(y, 1), 511);%!!新增
    %     Projimg(y,x)=1;%!!新增
    % end


    Projimg_DT=bwdist(Projimg);

    seq1 = shapedis(vestemp_proj);
    
    %起点和终点对应点的坐标
    startpot=vessel_2Dmatch(1,:);
    endpot=vessel_2Dmatch(end,:);

    if degree3d(endid)>=3 &&num_pot<2 %若分岔点且长度不长
        [xs,ys,f]=shortestway2d(VesData2D.Map,[startpot(1),endpot(1)],[512-startpot(2),512-endpot(2)],1,2,Projimg_DT);
        if f==0,continue;end
        vestemp_2d=[xs',512-ys'];
        [dist,path]=DTW(vestemp_proj,vestemp_2d);
        if dist>300,continue;end
        path1=path(:,1);
        path2=path(:,2);
        vestempproj=vestemp_proj(path1,:);
        vestemp2d=vestemp_2d(path2,:);

        pair_diff = vestempproj-vestemp2d;
        pair_d2 = sum(pair_diff.^2, 2);     % 欧氏距离平方即可比较大小，省一次 sqrt

        % 对每个 proj 点选最小距离的 2D 匹配
        for j = startid:endid
            rows = find(path1 == j-startid+1);
            if isempty(rows), continue; end
            [~, rel_min_pos] = min(pair_d2(rows));
            best_row = rows(rel_min_pos);        % path 中的最佳行
            VesData2D_Match(j,:) = vestemp_2d(path2(best_row),:);
        end

        X=[vestempproj(:,1)';vestemp2d(:,1)'];
        Y=[vestempproj(:,2)';vestemp2d(:,2)'];
        line(X,Y);
    else
        %找终点周围25距离内的中心线上的所有点
        endproj=vestemp_proj(end,:);
        if num_pot<20
            dist_search=27;
        else
            dist_search=27;
        end
        inx=vecnorm(VesData2D.Centerline-repmat(endproj,[size(VesData2D.Centerline,1),1]),2,2)<dist_search;
        ves2d_seg_all=VesData2D.Centerline(inx,:);
        ves2d_seg_all(end+1,:)=[endproj(1),endproj(2)];
        % plot(ves2d_seg_all(:,1),ves2d_seg_all(:,2),'y*');
        [xs,ys,f]=shortestway2d(VesData2D.Map,[startpot(1),endpot(1)],[512-startpot(2),512-endpot(2)],1,2,Projimg_DT);
        
        val_bif=[];
        val_dtw=[];
        val_sd=[];
        val_len=[];
        val_id=[];
        path_all={};
        vestemp_2d_all={};
    
        if f~=0
            vestemp_2d=[xs',512-ys']; %DSA分割图像中的对应路径
            veslen_2d=getveslen(vestemp_2d);
            seq2=shapedis(vestemp_2d);
            [dist1,~]=DTW_1d(seq1,seq2);
            [dist,path]=DTW(vestemp_proj,vestemp_2d);
            val_dtw=dist;
            val_sd=dist1;
            val_len=abs(floor(num_pot/20)+veslen_proj-veslen_2d);
            val_id=0;
            path_all{end+1}=path;
            vestemp_2d_all{end+1}=vestemp_2d;
            val_bif=0;
        end
        for k=1:size(ves2d_seg_all,1)
    
            [xs,ys,f]=shortestway2d(VesData2D.Map,[startpot(1),ves2d_seg_all(k,1)],[512-startpot(2),512-ves2d_seg_all(k,2)],1,2,Projimg_DT);
            if f==0,continue;end
    
            %分岔点相关
            % [idx_bif,~]=find(all(bsxfun(@eq,VesData2D.Centerline,ves2d_seg_all(k,:)),2));
            % if degree(idx_bif)>=3 && degree3d(endid)>=3
            %     val_bif=[val_bif,-0.2];
            %     scatter(ves2d_seg_all(k,1),ves2d_seg_all(k,2));
            %     % disp("找到分岔点！！！");
            % else
            %     val_bif=[val_bif,0];
            % end
    
            vestemp_2d=[xs',512-ys'];
            veslen_2d=getveslen(vestemp_2d);
            seq2=shapedis(vestemp_2d);
            [dist1,~]=DTW_1d(seq1,seq2);
            [dist,path]=DTW(vestemp_proj,vestemp_2d);
            val_dtw=[val_dtw,dist];
            val_sd=[val_sd,dist1];
            val_len=[val_len,abs(num_pot/10+veslen_proj-veslen_2d)];
            val_id=[val_id,k];
            path_all{end+1}=path;
            vestemp_2d_all{end+1}=vestemp_2d;
        end
        

        val_dtw_norm=(val_dtw-min(val_dtw))/(max(val_dtw)-min(val_dtw));
        val_sd_norm=(val_sd-min(val_sd))/(max(val_sd)-min(val_sd));
        val_len_norm=(val_len-min(val_len))/(max(val_len)-min(val_len));
        % weights=[0.6,0.23,0.36,0];
        weights=[0.77,0.23,0];

        if size(val_dtw_norm,1)==0 %周围找不到对应点，或找不到最短路
            for j=startid:endid
                VesData2D_Match(j,:)=vestemp_proj(j-startid+1,:);
            end
            continue;
        end


        % VAL=sum(weights.*[val_dtw_norm',val_sd_norm',val_len_norm',val_bif'],2);
        VAL=sum(weights.*[val_dtw_norm',val_sd_norm',val_len_norm'],2);
        [~,idxx]=min(VAL);
        if val_dtw(idxx)>5000
            for j=startid:endid
                VesData2D_Match(j,:)=vestemp_proj(j-startid+1,:);
            end
            continue;
        end

        minpath=path_all{idxx};
        minvestemp_2d=vestemp_2d_all{idxx};
    
        path1=minpath(:,1);
        path2=minpath(:,2);
        vestempproj=vestemp_proj(path1,:);
        vestemp2d=minvestemp_2d(path2,:);
        pair_diff = vestempproj-vestemp2d;
        pair_d2 = sum(pair_diff.^2,2);

    
        for j = startid:endid
            rows = find(path1 == j-startid+1);
            if isempty(rows), continue; end
            [~ , rel_min_pos] = min(pair_d2(rows));
            best_row = rows(rel_min_pos);
            VesData2D_Match(j,:) = minvestemp_2d(path2(best_row),:);
        end

        % if val_bif(idxx)~=0 %选到分岔点了
        %     VesData2D_Match(j,:)=ves2d_seg_all(val_id(idxx),:);
        % end

        X=[vestempproj(:,1)';vestemp2d(:,1)'];
        Y=[vestempproj(:,2)';vestemp2d(:,2)'];
        line(X,Y);
    end


end

end