% function VesData3D_Seg = Segm(VesData3D, adj_matrix)
% %SEGMENT_TREE_FROM_ADJ
% % 输入:
% %   P : N×3 点坐标
% %   A : N×N 无向邻接矩阵（0/1 或权重都可，非零视为有边）
% %
% % 输出:
% %   segments(k).id     : 段号（从1开始）
% %   segments(k).idx    : 该段的点索引（按路径顺序）
% %   segments(k).coords : 该段的点坐标（size = numel(idx) × 3）
% 
%     N = size(VesData3D,1);
%     if nargin < 2 || isempty(adj_matrix)
%         VesData3D_Seg = struct('id',{},'idx',{},'positions',{});
%         return;
%     end
% 
%     % —— 规范无向邻接（去掉自环，变成0/1）——
%     adj_matrix = adj_matrix | adj_matrix.';              % 对称
%     adj_matrix(1:N+1:end) = 0;         % 去自环
%     adj_matrix = adj_matrix ~= 0;               % 只保留连通性
% 
%     % —— 提取无向边列表（上三角）——
%     [r,c] = find(triu(adj_matrix,1));
%     e = [r, c];
%     m = size(e,1);
% 
%     % 若没有边，直接返回
%     if m == 0
%         VesData3D_Seg = struct('id',{},'idx',{},'positions',{});
%         return;
%     end
% 
%     % —— 度统计 & 关键点（度≠2）——
%     deg = full(sum(adj_matrix,2));
%     isKey = (deg ~= 2);
%     keyNodes = find(isKey);
% 
%     % —— 邻接表（便于沿路径行走）——
%     adj = cell(N,1);
%     for i = 1:N
%         adj{i} = find(adj_matrix(i,:));
%     end
% 
%     % —— 用稀疏矩阵当“边到索引”的哈希表 + 访问标记 —— 
%     Emap = sparse(e(:,1), e(:,2), 1:m, N, N);  % 只存上三角
%     Emap = Emap + Emap.';                      % 对称化，方便查
%     visitedEdge = false(m,1);
% 
%     VesData3D_Seg = struct('id',{},'idx',{},'positions',{});
%     sid = 0;
% 
%     % —— 从每个关键点出发，沿每条未访问的边延伸到下一个关键点 —— 
%     for u = keyNodes.'
%         nbrs = adj{u};
%         for v = nbrs
%             eid = getEdgeId(Emap, u, v);
%             if visitedEdge(eid), continue; end
% 
%             % 以 u -> v 方向延伸
%             path = u;
%             prev = u;
%             cur  = v;
% 
%             visitedEdge(eid) = true;
% 
%             while ~isKey(cur)
%                 % cur 是度==2的“中间点”，继续走向另一侧
%                 path(end+1) = cur; %#ok<AGROW>
%                 nb = adj{cur};
%                 next = nb(nb ~= prev);   % 只剩一个
%                 next = next(1);
% 
%                 eid2 = getEdgeId(Emap, cur, next);
%                 if visitedEdge(eid2)
%                     % 理论上树不会重复访问；若图里有环，用此保护避免死循环
%                     break;
%                 end
%                 visitedEdge(eid2) = true;
% 
%                 prev = cur;
%                 cur  = next;
%             end
% 
%             % 到达下一个关键点（或因环保护提前终止）
%             path(end+1) = cur; %#ok<AGROW>
% 
%             % 记录一段
%             sid = sid + 1;
%             VesData3D_Seg(sid).id     = sid;
%             VesData3D_Seg(sid).idx    = path(:).';
%             VesData3D_Seg(sid).positions = VesData3D(path, :);
%         end
%     end
% 
%     % —— 边缘情况：整条链也会由两端关键点（度1）覆盖，无需额外处理 —— 
% 
%     % 可选：按首点索引排序并重排段号，便于复现
%     if ~isempty(VesData3D_Seg)
%         [~, order] = sort(arrayfun(@(s) s.idx(1), VesData3D_Seg));
%         VesData3D_Seg = VesData3D_Seg(order);
%         for k = 1:numel(VesData3D_Seg), VesData3D_Seg(k).id = k; end
%     end
% end
% 
% % ===== 工具函数 =====
% function eid = getEdgeId(Emap, a, b)
%     % 返回边(a,b)在边列表中的索引（1-based）
%     eid = full(Emap(a,b));
%     if eid == 0
%         error('Edge (%d,%d) not found. 请确保 A 是无向连通的正确邻接矩阵。', a, b);
%     end
% end
function VesData3D_Seg = Segm(VesData3D, adj_matrix, rootId)
%SEGMENT_TREE_FROM_ADJ
% VesData3D : N×3 点坐标
% adj_matrix: N×N 无向邻接矩阵
% rootId    : 根节点索引（默认1）

    if nargin < 3 || isempty(rootId)
        rootId = 1;
    end

    N = size(VesData3D,1);
    if nargin < 2 || isempty(adj_matrix)
        VesData3D_Seg = struct('id',{},'idx',{},'positions',{});
        return;
    end

    % —— 规范无向邻接（去掉自环，变成0/1）——
    adj_matrix = adj_matrix | adj_matrix.';
    adj_matrix(1:N+1:end) = 0;
    adj_matrix = adj_matrix ~= 0;

    % —— 提取无向边列表（上三角）——
    [r,c] = find(triu(adj_matrix,1));
    e = [r, c];
    m = size(e,1);
    if m == 0
        VesData3D_Seg = struct('id',{},'idx',{},'positions',{});
        return;
    end

    % —— 度统计 & 关键点（度≠2）——
    deg = full(sum(adj_matrix,2));
    isKey = (deg ~= 2);

    % ✅ 修正1：强制根节点是关键点（即使 deg(root)==2 也在这里断开）
    isKey(rootId) = true;

    keyNodes = find(isKey);

    % —— 邻接表 —— 
    adj = cell(N,1);
    for i = 1:N
        adj{i} = find(adj_matrix(i,:));
    end

    % ✅ 修正2：从根做 BFS 距离，用于统一段方向（靠近根的一端作为起点）
    dist = bfsDist(adj, rootId);

    % —— 边到索引 + 访问标记 —— 
    Emap = sparse(e(:,1), e(:,2), 1:m, N, N);
    Emap = Emap + Emap.';
    visitedEdge = false(m,1);

    VesData3D_Seg = struct('id',{},'idx',{},'positions',{});
    sid = 0;

    % —— 从每个关键点出发，沿每条未访问的边延伸到下一个关键点 —— 
    for u = keyNodes.'
        nbrs = adj{u};
        for v = nbrs
            eid = getEdgeId(Emap, u, v);
            if visitedEdge(eid), continue; end

            path = u;
            prev = u;
            cur  = v;
            visitedEdge(eid) = true;

            while ~isKey(cur)
                path(end+1) = cur; %#ok<AGROW>
                nb = adj{cur};
                next = nb(nb ~= prev);
                next = next(1);

                eid2 = getEdgeId(Emap, cur, next);
                if visitedEdge(eid2)
                    break; % 有环保护
                end
                visitedEdge(eid2) = true;

                prev = cur;
                cur  = next;
            end
            path(end+1) = cur; %#ok<AGROW>

            % ✅ 统一方向：离根更近的一端作为起点（防止出现 74..1 这种反向）
            if dist(path(1)) > dist(path(end))
                path = fliplr(path);
            end

            sid = sid + 1;
            VesData3D_Seg(sid).id = sid;
            VesData3D_Seg(sid).idx = path(:).';
            VesData3D_Seg(sid).positions = VesData3D(path, :);
        end
    end

    % 可选：按首点索引排序并重排段号
    if ~isempty(VesData3D_Seg)
        [~, order] = sort(arrayfun(@(s) s.idx(1), VesData3D_Seg));
        VesData3D_Seg = VesData3D_Seg(order);
        for k = 1:numel(VesData3D_Seg)
            VesData3D_Seg(k).id = k;
        end
    end
end

% ===== 工具函数 =====
function eid = getEdgeId(Emap, a, b)
    eid = full(Emap(a,b));
    if eid == 0
        error('Edge (%d,%d) not found.', a, b);
    end
end

function dist = bfsDist(adj, rootId)
    N = numel(adj);
    dist = inf(N,1);
    dist(rootId) = 0;

    q = zeros(N,1);
    head = 1; tail = 1;
    q(tail) = rootId;

    while head <= tail
        u = q(head); head = head + 1;
        du = dist(u);
        for v = adj{u}
            if isinf(dist(v))
                dist(v) = du + 1;
                tail = tail + 1;
                q(tail) = v;
            end
        end
    end
end
