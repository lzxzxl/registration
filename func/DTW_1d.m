function [dist, path] = DTW_1d(seq1, seq2)
% 输入：seq1, seq2 - 两个一维序列（行向量或列向量）
% 输出：dist - DTW距离（标量）
%       path - N×2矩阵，每行表示匹配的点对索引 [index_seq1, index_seq2]

% 确保输入为行向量
seq1 = seq1(:)';
seq2 = seq2(:)';

n = length(seq1);
m = length(seq2);

% 初始化距离矩阵和累积代价矩阵
D = zeros(n, m);      % 局部距离矩阵
cost = inf(n, m);     % 累积代价矩阵（初始化为无穷大）

% 计算局部距离矩阵（平方欧氏距离）
for i = 1:n
    for j = 1:m
        D(i, j) = (seq1(i) - seq2(j))^2 + (i*m/n - j)^2;
    end
end

% 初始化起点
cost(1, 1) = D(1, 1);

% 计算第一列累积代价
for i = 2:n
    cost(i, 1) = D(i, 1) + cost(i-1, 1);
end

% 计算第一行累积代价
for j = 2:m
    cost(1, j) = D(1, j) + cost(1, j-1);
end

% 计算其余部分的累积代价
for i = 2:n
    for j = 2:m
        % 寻找最小累积代价的邻居
        min_cost = min([cost(i-1, j), cost(i, j-1), cost(i-1, j-1)]);
        cost(i, j) = D(i, j) + min_cost;
    end
end

% 计算最终DTW距离（取平方根）
dist = sqrt(cost(n, m));

% 回溯路径
path = [];
i = n;
j = m;

while (i >= 1) && (j >= 1)
    path = [i, j; path];  % 添加当前点到路径
    
    if i == 1 && j == 1
        break;
    end
    
    % 确定回溯方向（优先检查边界）
    if i == 1
        j = j - 1;
    elseif j == 1
        i = i - 1;
    else
        % 找到最小代价的邻居
        [~, idx] = min([cost(i-1, j), cost(i, j-1), cost(i-1, j-1)]);
        switch idx
            case 1  % 来自上方
                i = i - 1;
            case 2  % 来自左方
                j = j - 1;
            case 3  % 来自对角线
                i = i - 1;
                j = j - 1;
        end
    end
end
end