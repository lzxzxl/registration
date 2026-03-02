function adjMatrix = buildadj(points)
    % 从点集构建最小生成树邻接矩阵
    % 输入:
    %   points: N x D 矩阵，每行是一个节点的坐标（D维）
    % 输出:
    %   adjMatrix: N x N 邻接矩阵，1表示连接，0表示不连接
    
    N = size(points, 1);    
    % 1. 计算欧氏距离矩阵（N×N）
    distMat = pdist2(points, points);
    
    % 2. 构建无向图（排除自身到自身的边，即对角线）
    % 生成所有非对角线的边索引
    [row, col] = find(triu(true(N), 1)); % 上三角非对角线，避免重复边
    
    % 3. 提取对应边的权重（距离），确保不包括对角线
    weights = distMat(sub2ind([N, N], row, col));
    
    % 4. 创建图对象并计算最小生成树
    G = graph(row, col, weights);       % 基于边和权重创建无向图
    MST = minspantree(G);               % 计算最小生成树
    
    % 5. 构建邻接矩阵（原始节点顺序）
    adjMatrix = zeros(N, N);
    
    % 获取最小生成树的边信息
    edges = MST.Edges;
    
    % 填充邻接矩阵（无向图，双向置1）
    for i = 1:height(edges)
        n1 = edges.EndNodes(i, 1);
        n2 = edges.EndNodes(i, 2);
        adjMatrix(n1, n2) = 1;
        adjMatrix(n2, n1) = 1; % 对无向图，需要设置两个方向的边
    end
end
