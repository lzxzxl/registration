% function ordered_indices = reconstruct_centerline_dfs(points)
%     % points: N x 3 matrix, each row is a 3D coordinate of a node
%     N = size(points, 1);
% 
%     % 1. Compute Euclidean distance matrix
%     distMat = pdist2(points, points);
% 
%     % 2. Create complete graph and find Minimum Spanning Tree (MST)
%     % 使用三角矩阵避免重复边
%     distMat = triu(distMat, 1) + triu(distMat, 1)';
%     [row, col] = find(triu(true(size(distMat)), 1));
%     weights = distMat(sub2ind(size(distMat), row, col));
% 
%     % 创建图对象并计算MST
%     G = graph(row, col, weights);
%     MST = minspantree(G);
% 
%     % 3. Find root node (endpoint with degree 1)
%     deg = degree(MST);
%     root = 715;  % Select first endpoint found
% 
%     % 4. 获取邻接列表
%     % 使用edges函数获取所有边
%     edges = MST.Edges;
%     adjList = cell(N, 1);
% 
%     % 填充邻接列表
%     for i = 1:size(edges, 1)
%         n1 = edges.EndNodes(i, 1);
%         n2 = edges.EndNodes(i, 2);
%         adjList{n1} = [adjList{n1}, n2];
%         adjList{n2} = [adjList{n2}, n1];
%     end
% 
%     % 5. Prepare for DFS
%     visited = false(1, N);
%     ordered_indices = [];
% 
%     % Recursive DFS traversal
%     function dfs(current, parent)
%         visited(current) = true;
%         ordered_indices(end+1) = current;
% 
%         % Get neighbors excluding parent
%         neighborNodes = adjList{current};
%         if ~isempty(parent)
%             neighborNodes = setdiff(neighborNodes, parent);
%         end
% 
%         if isempty(neighborNodes)
%             return;
%         end
% 
%         % Sort neighbors by distance to current node (ascending)
%         [~, idx] = sort(distMat(current, neighborNodes));
%         sorted_neighbors = neighborNodes(idx);
% 
%         % Visit each neighbor in sorted order
%         for i = 1:length(sorted_neighbors)
%             neighbor = sorted_neighbors(i);
%             if ~visited(neighbor)
%                 dfs(neighbor, current);
%             end
%         end
%     end
% 
%     % Start DFS from root node (no parent)
%     dfs(root, []);
%     ordered_indices = ordered_indices(:); % Ensure column vector
% end

function [ordered_indices, adjMatrix_dfs] = reconstruct_centerline_dfs(points,root)
    % points: N x 3 matrix, each row is a 3D coordinate of a node
    % ordered_indices: DFS顺序的节点索引
    % adjMatrix_dfs: 按DFS顺序排列的邻接矩阵
    
    N = size(points, 1);
    
    % 1. 计算欧氏距离矩阵
    distMat = pdist2(points, points);
    
    % 2. 创建图并计算最小生成树
    distMat = triu(distMat, 1) + triu(distMat, 1)';
    [row, col] = find(triu(true(size(distMat)), 1));
    weights = distMat(sub2ind(size(distMat), row, col));
    
    G = graph(row, col, weights);
    MST = minspantree(G);
    
    % 3. 查找根节点（度为1的端点）
    deg = degree(MST);

    
    % 4. 获取邻接列表
    edges = MST.Edges;
    adjList = cell(N, 1);
    
    % 填充邻接列表（原始节点顺序）
    for i = 1:size(edges, 1)
        n1 = edges.EndNodes(i, 1);
        n2 = edges.EndNodes(i, 2);
        
        % 添加到邻接列表
        adjList{n1} = [adjList{n1}, n2];
        adjList{n2} = [adjList{n2}, n1];
    end
    
    % 5. 准备DFS遍历
    visited = false(1, N);
    ordered_indices = [];
    
    % 递归DFS遍历
    function dfs(current, parent)
        visited(current) = true;
        ordered_indices(end+1) = current;
        
        % 获取邻居（排除父节点）
        neighborNodes = adjList{current};
        if ~isempty(parent)
            neighborNodes = setdiff(neighborNodes, parent);
        end
        
        if isempty(neighborNodes)
            return;
        end
        
        % 按距离排序邻居节点
        [~, idx] = sort(distMat(current, neighborNodes));
        sorted_neighbors = neighborNodes(idx);
        
        % 按顺序访问每个邻居
        for i = 1:length(sorted_neighbors)
            neighbor = sorted_neighbors(i);
            if ~visited(neighbor)
                dfs(neighbor, current);
            end
        end
    end

    % 从根节点开始DFS遍历
    dfs(root, []);
    ordered_indices = ordered_indices(:); % 确保是列向量
    
    % 6. 构建按DFS顺序排列的邻接矩阵
    % 创建一个映射：原始索引 -> DFS顺序索引
    [~, reverse_map] = sort(ordered_indices);
    
    % 初始化邻接矩阵（DFS顺序）
    adjMatrix_dfs = zeros(N);
    
    % 填充邻接矩阵
    for i = 1:N
        % 当前节点在DFS顺序中的位置
        dfs_idx_i = reverse_map(i);
        
        % 遍历当前节点的所有邻居
        for neighbor = adjList{i}
            % 邻居节点在DFS顺序中的位置
            dfs_idx_j = reverse_map(neighbor);
            
            % 在邻接矩阵中标记连接关系
            adjMatrix_dfs(dfs_idx_i, dfs_idx_j) = 1;
            adjMatrix_dfs(dfs_idx_j, dfs_idx_i) = 1; % 对称性
        end
    end
    
    % 可选：转换为稀疏矩阵以节省空间
    % adjMatrix_dfs = sparse(adjMatrix_dfs);
end