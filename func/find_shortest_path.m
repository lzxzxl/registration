function shortest_path = find_shortest_path(start_point, end_point, point_set)
    % 输入：
    % start_point：起点坐标，形式为 [x, y]
    % end_point：终点坐标，形式为 [x, y]
    % point_set：点集，N*2 格式，每一行是一个点坐标
    
    % 获取点集的尺寸
    [N, ~] = size(point_set);
    
    % 创建一个空的open list和closed list
    open_list = [];
    closed_list = false(N, 1);
    
    % 启发函数：曼哈顿距离 (考虑8联通)
    heuristic = @(p1, p2) max(abs(p1(1) - p2(1)), abs(p1(2) - p2(2)));
    
    % 初始化起点和终点
    start_idx = find(ismember(point_set, start_point, 'rows'));
    end_idx = find(ismember(point_set, end_point, 'rows'));
    
    % 初始化open list，存储每个点的f值、g值、父节点等信息
    open_list = struct('idx', start_idx, 'g', 0, 'h', heuristic(start_point, end_point), 'f', 0, 'parent', []);
    open_list.f = open_list.g + open_list.h;
    
    % 方向数组：8联通方向
    directions = [-1, 0; 1, 0; 0, -1; 0, 1; -1, -1; -1, 1; 1, -1; 1, 1];
    
    % 循环，直到open list为空或者找到终点
    while ~isempty(open_list)
        % 从open list中取出f值最小的点
        [~, idx] = min([open_list.f]);
        current = open_list(idx);
        open_list(idx) = [];  % 从open list中删除当前点
        
        % 如果当前点是终点，生成路径
        if current.idx == end_idx
            shortest_path = [];
            while ~isempty(current.parent)
                shortest_path = [point_set(current.idx, :); shortest_path];
                current = current.parent;
            end
            shortest_path = [start_point; shortest_path];
            return;
        end
        
        % 将当前点加入closed list
        closed_list(current.idx) = true;
        
        % 生成邻接点
        for i = 1:size(directions, 1)
            % 计算邻居的坐标
            neighbor_coord = point_set(current.idx, :) + directions(i, :);
            
            % 检查邻接点是否合法且在点集中
            if is_valid_point(neighbor_coord, point_set, closed_list)
                % 查找邻接点在point_set中的索引
                neighbor_idx = find(ismember(point_set, neighbor_coord, 'rows'));
                
                % 如果找到了邻接点的索引
                if ~isempty(neighbor_idx)
                    % 计算g值、h值、f值
                    g_new = current.g + 1;  % 假设每步代价为1
                    h_new = heuristic(neighbor_coord, end_point);
                    f_new = g_new + h_new;
                    
                    % 检查该点是否在open list中
                    if is_in_open_list(neighbor_idx, open_list)
                        % 如果已在open list中，检查是否需要更新
                        idx_in_open = find([open_list.idx] == neighbor_idx);
                        if f_new < open_list(idx_in_open).f
                            open_list(idx_in_open).f = f_new;
                            open_list(idx_in_open).g = g_new;
                            open_list(idx_in_open).parent = current;
                        end
                    else
                        % 如果不在open list中，加入open list
                        open_list = [open_list, struct('idx', neighbor_idx, 'g', g_new, 'h', h_new, 'f', f_new, 'parent', current)];
                    end
                end
            end
        end
    end
    
    % 如果无法找到路径，返回空
    shortest_path = [];
end

% 判断点是否合法且不在closed list中
function valid = is_valid_point(point, point_set, closed_list)
    % 确保point是有效的，并且没有超出范围
    valid = all(point >= 1 & point <= size(point_set, 1));  
    
    % 确保该点没有在closed list中
    if valid
        valid = ~any(ismember(point_set, point, 'rows') & closed_list);  % 判断该点是否在closed list中
    end
end

% 判断点是否在open list中
function in_list = is_in_open_list(idx, open_list)
    % 使用find来查找idx是否在open_list中
    in_list = any(arrayfun(@(x) x.idx == idx, open_list));
end
