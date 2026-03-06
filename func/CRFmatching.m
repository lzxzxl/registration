function [VesData2D_Match,match] = CRFmatching(VesData3D_Seg, VesData2D, VesData3D_Proj, params)
Num_seg=size(VesData3D_Seg,2); %段数
vessel_2D=VesData2D.Centerline;
img_DT=VesData2D.img_DT_Centerline;
m=size(img_DT,1);
NN=size(vessel_2D,1);
N=size(VesData3D_Proj,1);

VesData2D_Match=zeros(N,2);

params.tau = 30;  %2 100
params.eta = 10;  %0.8 
params.epsNull = 20; 
params.phiEnd = 5;
params.nuNull = 200;%2 200



projdist=sqrt(sum((VesData3D_Proj-VesData3D_Proj(1,:)).^2,2));
maxprojdist=max(projdist);

%kd tree
ns = createns(vessel_2D, 'NSMethod', 'kdtree');

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

% figure;
% plot(VesData2D.Centerline(:,1),VesData2D.Centerline(:,2),'g.');
% hold on
% plot(VesData3D_Proj(:,1),VesData3D_Proj(:,2),'r.');


for i=1:Num_seg
    vesidx=VesData3D_Seg(i).idx;
    if i~=1, vesidx(1)=[];end
    vestemp_proj=VesData3D_Proj(vesidx,:); %3D投影点

    len_seg=size(vestemp_proj,1);

    %确定候选集(逐段)
    Candidate_set=cell(len_seg,1);
    for j=1:len_seg
        p=vestemp_proj(j,:);

        scope_search=20+norm(p-VesData3D_Proj(1,:))/maxprojdist*20;  %%%!!!
        idxCell = rangesearch(ns, p, scope_search);
        ids=idxCell{1};
        if isempty(ids)
            C=p;
        else
            C=vessel_2D(ids,:);
            C=[C;p];
        end
        Candidate_set{j} = C;

        % inx=vecnorm(vessel_2D-repmat(vestemp_proj(j,:),[NN,1]),2,2)<scope_search;
        % Candidate_set{j}=vessel_2D(inx,:);
        % if isempty(Candidate_set{j})
        %     % Candidate_set{j}=[NaN NaN];
        %     Candidate_set{j}=vestemp_proj(j,:);
        % else
        %     % Candidate_set{j}(end+1,:)=[NaN NaN]; %加入空集
        %     Candidate_set{j}(end+1,:)=vestemp_proj(j,:); %加入本身
        % end
    end

    dp=cell(len_seg,1);
    back=cell(len_seg,1);
    unary=cell(len_seg,1);

    %确定子树
    points_idx=[];
    j=child_tree{i}(2:end)';
    if ~isempty(j)
        for j=child_tree{i}(2:end)'
            points_idx=[points_idx,VesData3D_Seg(j).idx(2:end)]; %子树所有索引
        end    
        subtree=VesData3D_Proj(points_idx,:);
    else
        subtree=[];
    end


    %% unary cost
    for j=1:len_seg
        if j==len_seg
            unary{j}=unary_cost(img_DT,vestemp_proj(j,:),Candidate_set{j},1,subtree,params);
        else
            unary{j}=unary_cost(img_DT,vestemp_proj(j,:),Candidate_set{j},0,[],params);
        end
    end

    %% 
    dp{1}=unary{1};
    back{1}=zeros(size(dp{1}));

    for j=2:len_seg
        Qprev=Candidate_set{j-1};
        Qcurr=Candidate_set{j};
        dpprev=dp{j-1};

        % len_canprev=size(Qprev,1);len_cancurr=size(Qcurr,1);

        dpv=vestemp_proj(j-1,:)-vestemp_proj(j,:);
        X = Qprev - dpv;  % Kp×2
        costMat = pdist2(X, Qcurr, 'euclidean'); % Kp×Kc        
        % if addNull
        %     % any NaN in either candidate -> nuNull
        %     prevNull = isnan(Qprev(:,1));  % Kp×1 (null row)
        %     currNull = isnan(Qcurr(:,1));  % 1×Kc (null col)
        %     if any(prevNull)
        %         costMat(prevNull,:) = nuNull;
        %     end
        %     if any(currNull)
        %         costMat(:,currNull) = nuNull;
        %     end
        %     % pdist2 could also produce NaN if any NaN slipped in
        %     costMat(isnan(costMat)) = nuNull;
        % end

        vals = dpprev + params.tau * costMat;  % Kp×Kc

        [bestVal, bestIdx] = min(vals, [], 1); % per column k

        dp{j} = unary{j} + bestVal(:);
        back{j} = bestIdx(:);        

        % % old-ver
        % dpcurr=inf(len_cancurr,1);
        % backcurr=zeros(len_cancurr,1);
        % 
        % for k=1:len_cancurr
        %    ttt=zeros(len_canprev,1);
        %     for kk=1:len_canprev
        %         ttt(kk)=params.tau*pairwise_cost(vestemp_proj(j-1,:),vestemp_proj(j,:), ...
        %             Qprev(kk,:),Qcurr(k,:),params);
        %     end   
        %     [bestVal,bestIdx]=min(dpprev+ttt);
        %     dpcurr(k)=unary{j}(k)+bestVal;
        %     backcurr(k)=bestIdx;
        % end
        % 
        % dp{j}=dpcurr;
        % back{j}=backcurr;
    end

    % ---- backtrack ----
    [Ebest, uN] = min(dp{len_seg});
    uBest = zeros(len_seg,1);
    uBest(len_seg) = uN;
    for j = len_seg:-1:2
        uBest(j-1) = back{j}(uBest(j));
    end

    qBest = NaN(len_seg,2);
    isNull = false(len_seg,1);
    for j = 1:len_seg
        qj = Candidate_set{j}(uBest(j),:);
        qBest(j,:) = qj;
        isNull(j) = any(isnan(qj));
    end

    match = struct();
    match.uBest  = uBest;
    match.qBest  = qBest;
    match.isNull = isNull;
    match.energy = Ebest;

    % plot(match.qBest(:,1),match.qBest(:,2),'b.');

    VesData2D_Match(vesidx,:)=match.qBest;
    
end

idx=find(any(isnan(VesData2D_Match),2));
VesData2D_Match(idx,:)=VesData3D_Proj(idx,:);


end


function c=unary_cost(img_DT,p,Candidate_set,isEnd,subtree,params)
    len_can=size(Candidate_set,1); 
    c=zeros(len_can,1);

    for i=1:len_can
        q=Candidate_set(i,:);
        if any(isnan(q))
            c(i)=params.epsNull+(isEnd*params.phiEnd);

        else
            c(i)=norm(p-q,2);
            if p==q, c(i)=150;end
            if isEnd && ~isempty(subtree)
                delts=q-p; 
                err_subtree=MeasureError_2d(img_DT,subtree+delts,ones(size(subtree,1),1));
                c(i)=c(i)+params.eta*err_subtree;
            end
        end
    end
end

function c=pairwise_cost(pprev,pcurr,qprev,qcurr,params)
    if any(isnan(qprev))||any(isnan(qcurr))
        c=params.nuNull;
    else
        dp=pprev-pcurr;
        dq=qprev-qcurr;
        c=norm(dp-dq,2);
    end
end


% function [VesData2D_Match, matchAll] = CRFmatching(VesData3D_Seg, VesData2D, VesData3D_Proj, params)
%     Num_seg = numel(VesData3D_Seg);
%     vessel_2D = VesData2D.Centerline;
%     img_DT = VesData2D.img_DT_Centerline;
% 
%     N  = size(VesData3D_Proj,1);
%     NN = size(vessel_2D,1);
% 
%     VesData2D_Match = NaN(N,2);
%     matchAll = repmat(struct('uBest',[],'qBest',[],'isNull',[],'energy',[],'vesidx',[]), Num_seg, 1);
% 
%     % -------- params defaults / keep your values --------
%     if nargin < 4, params = struct(); end
%     params = fill_defaults_local(params);
% 
%     tau    = params.tau;
%     eta    = params.eta;
%     epsNull= params.epsNull;
%     phiEnd = params.phiEnd;
%     nuNull = params.nuNull;
% 
%     % Candidate control
%     Kmax   = params.Kmax;      % limit candidates per point (strongly recommended)
%     addNull= params.addNull;   % whether to add [NaN NaN] as explicit null
%     addSelf= params.addSelf;   % whether to add p itself as fallback candidate
% 
%     % -------- precompute distances from root --------
%     projdist = hypot(VesData3D_Proj(:,1)-VesData3D_Proj(1,1), VesData3D_Proj(:,2)-VesData3D_Proj(1,2));
%     maxprojdist = max(projdist);
%     if maxprojdist <= 0, maxprojdist = 1; end
% 
%     % -------- build KD-tree once --------
%     ns = createns(vessel_2D, 'NSMethod', 'kdtree');
% 
%     % -------- build parent/child_tree faster (O(Num_seg)) --------
%     [parent, child_tree] = build_child_tree_fast(VesData3D_Seg);
% 
%     % -------- main loop over segments --------
%     for si = 1:Num_seg
%         vesidx = VesData3D_Seg(si).idx;
%         if si ~= 1
%             vesidx(1) = []; % same as your original
%         end
%         vestemp_proj = VesData3D_Proj(vesidx,:);  % L×2
%         L = size(vestemp_proj,1);
% 
%         % ---- subtree points (projected) ----
%         subtree = collect_subtree_points(si, child_tree, VesData3D_Seg, VesData3D_Proj);
% 
%         % ---- Candidate set construction (KD-tree + topK) ----
%         Candidate_set = cell(L,1);
%         for j = 1:L
%             p = vestemp_proj(j,:);
%             % your radius design
%             scope_search = 20 + norm(p - VesData3D_Proj(1,:)) / maxprojdist * 20;
% 
%             idxCell = rangesearch(ns, p, scope_search);
%             ids = idxCell{1};
% 
%             if isempty(ids)
%                 C = zeros(0,2);
%             else
%                 C = vessel_2D(ids,:);
%                 % optional: keep nearest Kmax only
%                 if ~isempty(Kmax) && size(C,1) > Kmax
%                     d = hypot(C(:,1)-p(1), C(:,2)-p(2));
%                     [~, ord] = mink(d, Kmax);
%                     C = C(ord,:);
%                 end
%             end
% 
%             if addSelf
%                 C = [C; p];  % keep your behavior (append itself)
%             end
%             if addNull
%                 C = [C; NaN NaN]; % optional explicit null
%             end
% 
%             if isempty(C)
%                 % absolute fallback
%                 C = p;
%                 if addNull, C = [C; NaN NaN]; end
%             end
% 
%             Candidate_set{j} = C;
%         end
% 
%         % ---- unary costs ----
%         unary = cell(L,1);
%         for j = 1:L
%             isEnd = (j == L);
%             if isEnd
%                 unary{j} = unary_cost_fast(img_DT, vestemp_proj(j,:), Candidate_set{j}, true, subtree, eta, epsNull, phiEnd);
%             else
%                 unary{j} = unary_cost_fast(img_DT, vestemp_proj(j,:), Candidate_set{j}, false, [], eta, epsNull, phiEnd);
%             end
%         end
% 
%         % ---- Viterbi DP (vectorized transitions) ----
%         dp   = cell(L,1);
%         back = cell(L,1);
% 
%         dp{1}   = unary{1};
%         back{1} = zeros(size(dp{1}));
% 
%         for j = 2:L
%             Qprev  = Candidate_set{j-1};   % Kp×2
%             Qcurr  = Candidate_set{j};     % Kc×2
%             dpprev = dp{j-1};              % Kp×1
% 
%             Kp = size(Qprev,1);
%             Kc = size(Qcurr,1);
% 
%             % dpv = p_{j-1} - p_j (1×2)
%             dpv = vestemp_proj(j-1,:) - vestemp_proj(j,:);
% 
%             % vectorized cost matrix:
%             % cost(v,k) = || dpv - (Qprev(v,:) - Qcurr(k,:)) ||
%             %          = || (Qprev(v,:) - dpv) - Qcurr(k,:) ||
%             X = Qprev - dpv;  % Kp×2
%             costMat = pdist2(X, Qcurr, 'euclidean'); % Kp×Kc
% 
%             % handle nulls (if you use NaN)
%             if addNull
%                 % any NaN in either candidate -> nuNull
%                 prevNull = isnan(Qprev(:,1));  % Kp×1 (null row)
%                 currNull = isnan(Qcurr(:,1));  % 1×Kc (null col)
%                 if any(prevNull)
%                     costMat(prevNull,:) = nuNull;
%                 end
%                 if any(currNull)
%                     costMat(:,currNull) = nuNull;
%                 end
%                 % pdist2 could also produce NaN if any NaN slipped in
%                 costMat(isnan(costMat)) = nuNull;
%             end
% 
%             % vals = dpprev + tau*costMat  (implicit expansion)
%             vals = dpprev + tau * costMat;  % Kp×Kc
% 
%             [bestVal, bestIdx] = min(vals, [], 1); % per column k
% 
%             dp{j} = unary{j} + bestVal(:);
%             back{j} = bestIdx(:);
%         end
% 
%         % ---- backtrack ----
%         [Ebest, uN] = min(dp{L});
%         uBest = zeros(L,1);
%         uBest(L) = uN;
%         for j = L:-1:2
%             uBest(j-1) = back{j}(uBest(j));
%         end
% 
%         qBest  = NaN(L,2);
%         isNull = false(L,1);
%         for j = 1:L
%             q = Candidate_set{j}(uBest(j),:);
%             qBest(j,:) = q;
%             isNull(j) = any(isnan(q));
%         end
% 
%         matchAll(si).uBest  = uBest;
%         matchAll(si).qBest  = qBest;
%         matchAll(si).isNull = isNull;
%         matchAll(si).energy = Ebest;
%         matchAll(si).vesidx = vesidx;
% 
%         VesData2D_Match(vesidx,:) = qBest;
%     end
% 
%     % ---- fill NaNs once (if any) ----
%     nanRows = any(isnan(VesData2D_Match), 2);
%     VesData2D_Match(nanRows,:) = VesData3D_Proj(nanRows,:);
% end
% 
% 
% % ================= helpers =================
% 
% function params = fill_defaults_local(params)
%     % your values
%     if ~isfield(params,'tau'),     params.tau = 30; end
%     if ~isfield(params,'eta'),     params.eta = 0.8; end
%     if ~isfield(params,'epsNull'), params.epsNull = 20; end
%     if ~isfield(params,'phiEnd'),  params.phiEnd = 5; end
%     if ~isfield(params,'nuNull'),  params.nuNull = 200; end
% 
%     % optimization controls
%     if ~isfield(params,'Kmax'),    params.Kmax = 80; end   % IMPORTANT
%     if ~isfield(params,'addNull'), params.addNull = false; end % keep your current behavior
%     if ~isfield(params,'addSelf'), params.addSelf = true; end  % keep your current behavior
% end
% 
% function [parent, child_tree] = build_child_tree_fast(VesData3D_Seg)
%     Num_seg = numel(VesData3D_Seg);
%     parent = zeros(Num_seg,1);
%     child_tree = cell(Num_seg,1);
%     for i=1:Num_seg
%         child_tree{i} = i;
%     end
% 
%     % map: endid -> seg index
%     endid = zeros(Num_seg,1);
%     startid = zeros(Num_seg,1);
%     for i=1:Num_seg
%         idx = VesData3D_Seg(i).idx;
%         endid(i) = idx(end);
%         startid(i) = idx(1);
%     end
% 
%     mp = containers.Map('KeyType','int32','ValueType','int32');
%     for i=1:Num_seg
%         mp(int32(endid(i))) = int32(i);
%     end
% 
%     for j=2:Num_seg
%         key = int32(startid(j));
%         if isKey(mp, key)
%             parent(j) = double(mp(key));
%         end
%     end
% 
%     for i = Num_seg:-1:2
%         par = parent(i);
%         if par > 0
%             child_tree{par} = [child_tree{par}; child_tree{i}];
%         end
%     end
% end
% 
% function subtree = collect_subtree_points(si, child_tree, VesData3D_Seg, VesData3D_Proj)
%     kids = child_tree{si};
%     if numel(kids) <= 1
%         subtree = [];
%         return;
%     end
%     kids = kids(2:end); % exclude itself
% 
%     idxCells = cell(numel(kids),1);
%     for t=1:numel(kids)
%         segId = kids(t);
%         id = VesData3D_Seg(segId).idx;
%         if numel(id) >= 2
%             idxCells{t} = id(2:end).';
%         else
%             idxCells{t} = [];
%         end
%     end
% 
%     points_idx = vertcat(idxCells{:});
%     if isempty(points_idx)
%         subtree = [];
%     else
%         subtree = VesData3D_Proj(points_idx,:);
%     end
% end
% 
% function c = unary_cost_fast(img_DT, p, C, isEnd, subtree, eta, epsNull, phiEnd)
%     % Vectorized unary for distance part; endpoint subtree term remains per-candidate
%     K = size(C,1);
%     c = zeros(K,1);
% 
%     isNull = isnan(C(:,1));  % if you enabled addNull
%     if any(isNull)
%         c(isNull) = epsNull + (isEnd * phiEnd);
%     end
% 
%     notNull = ~isNull;
%     if any(notNull)
%         dx = C(notNull,1) - p(1);
%         dy = C(notNull,2) - p(2);
%         c(notNull) = hypot(dx, dy);
% 
%         % keep your "p==q => 150" penalty (fixed scalar check)
%         eqMask = notNull & (C(:,1)==p(1)) & (C(:,2)==p(2));
%         c(eqMask) = 150;
% 
%         if isEnd && ~isempty(subtree)
%             % subtree penalty for each non-null candidate
%             ids = find(notNull);
%             for t = 1:numel(ids)
%                 u = ids(t);
%                 delta = C(u,:) - p;
%                 err_subtree = MeasureError_2d(img_DT, subtree + delta, ones(size(subtree,1),1));
%                 c(u) = c(u) + eta * err_subtree;
%             end
%         end
%     end
% end