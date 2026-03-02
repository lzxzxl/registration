function [VesData2D_Match,weight_solve] = DenseMatching_exp(VesData3D_Seg,VesData2D,N,VesData3D_Proj,w)
Num_seg=size(VesData3D_Seg,2);
VesData2D_Match=VesData3D_Proj; %%解决了向零点拉扯的问题
vessel_2D=VesData2D.Centerline; %DSA分割血管
img_DT=VesData2D.img_DT; 
m=size(img_DT,1);
NN=size(vessel_2D,1);


projdist=sqrt(sum((VesData3D_Proj-VesData3D_Proj(1,:)).^2,2));
maxprojdist=max(projdist);
%
weight_solve=ones(size(VesData3D_Proj,1),1);


% 这里要取消注释
% figure;
% plot(vessel_2D(:,1),vessel_2D(:,2),'g.');
% hold on;
% plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'r.');
% % plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'b.');
% axis equal


%%%找到子树 new
child_tree=cell(Num_seg,1);
parent=zeros(Num_seg,1);
for i=1:Num_seg
    child_tree{i}=i;
    endid=VesData3D_Seg(i).idx(end);
    for j=i+1:Num_seg
        startid=VesData3D_Seg(j).idx(1);
        if startid==endid
            parent(j)=i;
        end
    end
end
for i=Num_seg:-1:2
    par=parent(i);
    child_tree{par}=[child_tree{par};child_tree{i}];
end
%%%


for i=1:Num_seg

    vesidx=VesData3D_Seg(i).idx;
    %vestemp_proj=Proj(vestemp',VesData2D.K); %该段的投影
    vestemp_proj=VesData3D_Proj(vesidx,:); %3D投影点

    num_pot=length(vesidx);%这一段的点数量
    %起点和终点的id号
    
    startid=VesData3D_Seg(i).idx(2);endid=VesData3D_Seg(i).idx(end);
    if i==1, startid=VesData3D_Seg(i).idx(1);end
    
    if i~=1, vestemp_proj(1,:)=[];end %bug!!!
    
    NS=createns(vessel_2D,'NSMethod','kdtree');
    [idxs,~]=knnsearch(NS,vestemp_proj,'k',1);
    vessel_2Dmatch=vessel_2D(idxs,:);   %投影点在DSA分割血管中的最近对应点
    
    %%%%算误差
    vestemp_proj1=double(round(vestemp_proj));%专门算距离
    x=vestemp_proj1(:,1);
    y=vestemp_proj1(:,2);
    x = min(max(x, 1), 511);%！！新增
    y = min(max(y, 1), 511);%！！新增

    disterr=img_DT(y+m*(x-1));
    vestemp_err=mean(disterr);
    %%%%
    

    %求投影的img_DT
    vestemp_proj2=expand_points(vestemp_proj);%%扩充为它周围的四个点
    Projimg=zeros(m,m);
    for j=1:size(vestemp_proj2,1)
        x=vestemp_proj2(j,1); %!!新增
        y=vestemp_proj2(j,2);%!!新增
        x = min(max(x, 1), 511);%!!新增
        y = min(max(y, 1), 511);%!!新增
        Projimg(y,x)=1;%!!新增
    end
    Projimg_DT=bwdist(Projimg);


    
    %起点和终点对应点的坐标
    %startpot=vessel_2Dmatch(1,:);
    startpot=round([vestemp_proj(1,1),vestemp_proj(1,2)]); %起点改为自身
    endpot=vessel_2Dmatch(end,:);

    if length(child_tree{i}) == 1  %是端点
        if vestemp_err<0.25
            [xs,ys,f]=shortestway2d(VesData2D.Map,[startpot(1),endpot(1)],[startpot(2),endpot(2)],1,2,Projimg_DT,img_DT);
            if f==0,continue;end
            vestemp_2d=[xs',ys'];
            [~,path]=DTW(vestemp_proj,vestemp_2d);
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
    
                % if norm(VesData2D_Match(j,:)-round(VesData3D_Proj(j,:)))<2
                %     weight_solve(j)=0;
                % end
            end
    
            X=[vestempproj(:,1)';vestemp2d(:,1)'];
            Y=[vestempproj(:,2)';vestemp2d(:,2)'];
            % line(X,Y);
        else

            %找终点周围25距离内的中心线上的所有点
            endproj=vestemp_proj(end,:);
    
            dist_search=30;
            inx=vecnorm(VesData2D.Centerline-repmat(endproj,[size(VesData2D.Centerline,1),1]),2,2)<dist_search;
            ves2d_seg_all=VesData2D.Centerline(inx,:);
            
            val_dtw=[];
            path_all={};
            vestemp_2d_all={};
            for k=1:size(ves2d_seg_all,1)
                [xs,ys,f]=shortestway2d(VesData2D.Map,[startpot(1),ves2d_seg_all(k,1)],[startpot(2),ves2d_seg_all(k,2)],1,2,Projimg_DT,img_DT);
                if f==0,continue;end
    
                vestemp_2d=[xs',ys'];
                [dist,path]=DTW(vestemp_proj,vestemp_2d);
                val_dtw=[val_dtw,dist/size(path,1)];
                path_all{end+1}=path;
                vestemp_2d_all{end+1}=vestemp_2d;
            end
    
            [~,idxx]=min(val_dtw);
    
            if isempty(idxx)||val_dtw(idxx)>200 %周围找不到对应点，或找不到最短路
                [xs,ys,f]=shortestway2d(VesData2D.Map,[startpot(1),round(endproj(1))],[startpot(2),round(endproj(2))],1,2,Projimg_DT,img_DT);
                if f==0
                    disp('problem');
                    continue;
                end
                vestemp_2d=[xs',ys'];
                [~,path]=DTW(vestemp_proj,vestemp_2d);
    
                path_all{end+1}=path;
                vestemp_2d_all{end+1}=vestemp_2d;
                idxx=size(path_all,1);
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
    
                % if norm(VesData2D_Match(j,:)-round(VesData3D_Proj(j,:)))<2
                %     weight_solve(j)=0;
                % end
                if idxx==1
                    weight_solve(j)=0;
                end
    
            end

            X=[vestempproj(:,1)';vestemp2d(:,1)'];
            Y=[vestempproj(:,2)';vestemp2d(:,2)'];
            % line(X,Y);
        end
    else
        endproj=vestemp_proj(end,:);
        scope_search=norm(endproj-VesData3D_Proj(1,:))/maxprojdist*20;
        inx=vecnorm(vessel_2D-repmat(endproj,[NN,1]),2,2)<scope_search;
        ves2d_seg_all=vessel_2D(inx,:);
        
        ves2d_seg_all(end+1,:)=endproj; %加入自身
        ds=ves2d_seg_all-endproj;
        err_child=zeros(size(ves2d_seg_all,1),1);
        %求子树
        points_idx=[];
        for j=child_tree{i}(2:end)'
            points_idx=[points_idx,VesData3D_Seg(j).idx(2:end)]; %子树所有索引
        end
        %求误差
        for j=1:size(ves2d_seg_all,1)
            err_child(j)=MeasureError_2d(img_DT,VesData3D_Proj(points_idx,:) ...
                +ds(j,:),w(points_idx))+0.8*norm(ds(j,:))/scope_search;
        end
        [~,idxx]=min(err_child); %存在找不到的可能性,加入自身后，应该不存在这种可能了
        if isempty(idxx)
            ds=0;
            idxx=1;
        end
        %子树追踪
        
        VesData3D_Proj(points_idx,:)=VesData3D_Proj(points_idx,:)+ds(idxx,:);
        %找对应点
        endproj_new=endproj+ds(idxx,:);
        [xs,ys,f]=shortestway2d(VesData2D.Map,[startpot(1),endproj_new(1)],[startpot(2),endproj_new(2)],1,2,Projimg_DT,img_DT);
        if f==0,continue;end  %有隐患！！！
        vestemp_2d=[xs',ys'];
        [~,path]=DTW(vestemp_proj,vestemp_2d);
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

            % if norm(VesData2D_Match(j,:)-round(VesData3D_Proj(j,:)))<2
            %     weight_solve(j)=0;
            % end
        end

        X=[vestempproj(:,1)';vestemp2d(:,1)'];
        Y=[vestempproj(:,2)';vestemp2d(:,2)'];
        % line(X,Y);
        
    end

end

end