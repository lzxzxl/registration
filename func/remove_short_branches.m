function filtered_points = remove_short_branches(points, min_length)
    % 输入：
    % points: N*2 矩阵，表示二维中心线点集
    % min_length: 分支长度阈值，长度小于该值的分支将被删除
    
    % 初始化
    num_points = size(points, 1);
    adjacency_matrix = zeros(num_points, num_points);
    
    % 创建邻接矩阵（假设点之间的连接是基于距离的）
    for i = 1:num_points
        for j = i+1:num_points
            % 假设距离小于某个阈值则认为两个点相连
            if norm(points(i,:) - points(j,:)) < 2  % 可以根据需要调整阈值
                adjacency_matrix(i,j) = 1;
                adjacency_matrix(j,i) = 1;
            end
        end
    end

    % 寻找每个分支并计算长度
    visited = false(num_points, 1);  % 标记每个点是否已访问
    filtered_points = [];
    
    for i = 1:num_points
        if ~visited(i)
            % 如果点未访问，开始深度优先搜索（DFS）找分支
            branch_points = [];
            stack = i;
            while ~isempty(stack)
                current = stack(end);
                stack(end) = [];  % 弹出栈顶元素
                if visited(current)
                    continue;
                end
                visited(current) = true;
                branch_points = [branch_points; points(current,:)];  % 添加当前点
                neighbors = find(adjacency_matrix(current, :) == 1);
                stack = [stack, neighbors(~visited(neighbors))];  % 推入未访问的邻居
            end
            
            % 如果分支的长度（点数）大于或等于min_length，则保留该分支
            if size(branch_points, 1) >= min_length
                filtered_points = [filtered_points; branch_points];
            end
        end
    end
end
