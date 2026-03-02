% function [A,B] = clear_brancheslen(A, B, k)
% % A: N×2 点集
% % B: N×N 无向邻接矩阵（0/1或非零表示连边）
% % k: 每条叶子分支要减少的点个数（>=0），从叶子端往分岔点方向删
% % 根节点固定为 1
% 
%     root = 1;
%     k = round(k);
%     if k < 0, error('k 必须是非负整数'); end
% 
%     N = size(A,1);
%     if size(B,1) ~= N || size(B,2) ~= N
%         error('A 与 B 尺寸不匹配');
%     end
% 
%     % 规范无向邻接（0/1）
%     B = (B ~= 0);
%     B = B | B.';
%     B(1:N+1:end) = 0;
% 
%     deg = sum(B,2);
% 
%     % 关键点：deg~=2 或 root（用于定义“分岔点处截止”）
%     isKey = (deg ~= 2);
%     isKey(root) = true;
% 
%     % 叶子（端点），不包含 root
%     leaves = find(deg == 1);
%     leaves(leaves == root) = [];
% 
%     % 邻接表
%     adj = cell(N,1);
%     for i = 1:N
%         adj{i} = find(B(i,:));
%     end
% 
%     % 先在原图上确定所有要删除的点，避免顺序影响
%     removeMask = false(N,1);
% 
%     for t = 1:numel(leaves)
%         leaf = leaves(t);
% 
%         % 追踪 leaf -> 最近关键点（分岔点/根）的路径： [leaf ... key]
%         path = traceLeafToKey(leaf, adj, isKey, root);
% 
%         if numel(path) <= 1
%             continue;
%         end
% 
%         removable = path(1:end-1);     % 分岔点/根(最后一个)保留
%         nCut = min(k, numel(removable));
%         removeMask(removable(1:nCut)) = true;
%     end
% 
%     removeMask(root) = false; % 根节点永不删除
% 
%     % 保留索引，并重新编号：root 仍为 1
%     keepIdx = find(~removeMask);
%     keepIdx(keepIdx == root) = [];
%     keepIdx = [root; keepIdx];
% 
%     A = A(keepIdx, :);
%     B = B(keepIdx, keepIdx);
% end
% 
% % 从叶子追踪到最近关键点（不穿过分岔点/根），返回 [leaf ... key]
% function path = traceLeafToKey(leaf, adj, isKey, root)
%     path = leaf;
%     prev = 0;
%     cur  = leaf;
% 
%     visited = false(numel(adj),1);
%     visited(cur) = true;
% 
%     while true
%         if (isKey(cur) && cur ~= leaf) || cur == root
%             break;
%         end
% 
%         nb = adj{cur};
%         if prev ~= 0
%             nb(nb == prev) = [];
%         end
%         if isempty(nb)
%             break;
%         end
% 
%         % 在树上这里应当唯一；若有环/噪声，取第一个以避免报错
%         next = nb(1);
% 
%         prev = cur;
%         cur  = next;
%         path(end+1) = cur; %#ok<AGROW>
% 
%         if visited(cur)
%             break; % 有环保护
%         end
%         visited(cur) = true;
%     end
% end
function [A, B] = clear_brancheslen(A, B, k)
% A: N×2 点集
% B: N×N 无向邻接矩阵（0/1 或 非零表示连边）
% k: 每条分支要减少的点个数（>=0），从叶子端往分岔点方向删
%
% 不考虑根节点：对所有叶子分支都裁剪

    k = round(k);
    if k < 0, error('k 必须是非负整数'); end

    N = size(A,1);
    if size(B,1) ~= N || size(B,2) ~= N
        error('A 与 B 尺寸不匹配');
    end

    % 规范无向邻接（0/1）
    B = (B ~= 0);
    B = B | B.';
    B(1:N+1:end) = 0;

    deg = sum(B,2);

    % 关键点：deg ~= 2（包括分岔点deg>=3、端点deg==1、孤立deg==0）
    % “删减至分岔点处”这里用最近关键点（通常是deg>=3，若整段是链则可能到另一端点）
    isKey = (deg ~= 2);

    % 叶子端点
    leaves = find(deg == 1);

    % 邻接表
    adj = cell(N,1);
    for i = 1:N
        adj{i} = find(B(i,:));
    end

    % 先在原图上确定所有要删除的点（避免顺序影响）
    removeMask = false(N,1);

    for t = 1:numel(leaves)
        leaf = leaves(t);

        % 路径: [leaf ... key]，key 是遇到的第一个关键点(且不等于leaf)
        path = traceLeafToKey(leaf, adj, isKey);

        if numel(path) <= 1
            continue;
        end

        % 最后一个关键点保留，其他都属于“可删范围”
        removable = path(1:end-1);
        nCut = min(k, numel(removable));
        removeMask(removable(1:nCut)) = true;  % 从叶子端开始删
    end

    % 保护：避免某个连通分量被删空（删空会导致A,B为空或丢失该分量）
    comps = connectedComponents(adj);
    for c = 1:numel(comps)
        nodes = comps{c};
        if all(removeMask(nodes))
            % 至少保留一个点：保留该分量里最小索引的点
            [~, ii] = min(nodes);
            removeMask(nodes(ii)) = false;
        end
    end

    % 保留并输出（保持原始索引升序的相对顺序）
    keepIdx = find(~removeMask);
    A = A(keepIdx, :);
    B = B(keepIdx, keepIdx);
end

% 从叶子追踪到最近关键点（不包含叶子自身作为终止关键点）
function path = traceLeafToKey(leaf, adj, isKey)
    path = leaf;
    prev = 0;
    cur  = leaf;

    visited = false(numel(adj),1);
    visited(cur) = true;

    while true
        % 到达关键点（但不把起始叶子算作终点）
        if isKey(cur) && cur ~= leaf
            break;
        end

        nb = adj{cur};
        if prev ~= 0
            nb(nb == prev) = [];
        end
        if isempty(nb)
            break;
        end

        % 在“树/无环链”上这里应当唯一；若有环/噪声，取第一个避免崩
        next = nb(1);

        prev = cur;
        cur  = next;
        path(end+1) = cur; %#ok<AGROW>

        if visited(cur)
            break; % 环保护
        end
        visited(cur) = true;
    end
end

% 求连通分量（用于防止删空某个分量）
function comps = connectedComponents(adj)
    N = numel(adj);
    vis = false(N,1);
    comps = {};

    for s = 1:N
        if vis(s), continue; end

        % BFS/DFS
        stack = s;
        vis(s) = true;
        nodes = [];

        while ~isempty(stack)
            u = stack(end); stack(end) = [];
            nodes(end+1) = u; %#ok<AGROW>
            for v = adj{u}
                if ~vis(v)
                    vis(v) = true;
                    stack(end+1) = v; %#ok<AGROW>
                end
            end
        end

        comps{end+1} = nodes; %#ok<AGROW>
    end
end
