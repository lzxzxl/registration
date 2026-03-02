function [S, parent] = Trans_spherical(A, B, root)
% CART2REL_SPHERICAL
% A: N×3, 每行欧式坐标 (x,y,z)
% B: N×N, 邻接矩阵（可为0/1或权重；当作无向边处理）
% root: 根节点索引（默认1）
% 输出:
%   S      : N×3, 相对父节点的球坐标 [r, az, elev] (弧度)，根为 [0 0 0]
%   parent : N×1, 每个节点的父节点索引（根为0）
%
% 角度说明（与 MATLAB cart2sph 一致）:
%   [az, elev, r] = cart2sph(x, y, z)
%   az   : 方位角，x–y 平面内自 x 轴起的角度，范围 (-pi, pi]
%   elev : 仰角，相对 x–y 平面的角度，范围 [-pi/2, pi/2]
%   r    : 距离

    if nargin < 3 || isempty(root), root = 1; end
    A = double(A);
    N = size(A,1);

    % --- 规范化邻接矩阵为无向、无自环的逻辑矩阵 ---
    B = B ~= 0;
    B = B | B.';                 % 对称化（无向）
    B(1:N+1:end) = false;        % 去自环

    % --- BFS 求父节点（从 root 出发）---
    parent  = zeros(N,1);
    visited = false(N,1);
    q = zeros(N,1);              % 简单队列
    head = 1; tail = 1;
    q(tail) = root; visited(root) = true; parent(root) = 0;

    while head <= tail
        u = q(head); head = head + 1;
        nbrs = find(B(u,:));
        for v = nbrs
            if ~visited(v)
                visited(v) = true;
                parent(v)  = u;
                tail = tail + 1;
                q(tail) = v;
            end
        end
    end

    % 连通性检查（可选）
    if ~all(visited)
        warning('图并非从根完全连通：%d/%d 个节点不可达。', sum(~visited), N);
    end

    % --- 计算相对父节点的球坐标 ---
    S = nan(N,3);
    S(root,:) = A(1,:);       % 根节点定义为零

    for i = 1:N
        p = parent(i);
        if p == 0, continue; end
        v = A(i,:) - A(p,:);     % 相对父节点的向量
        [az, elev, r] = cart2sph(v(1), v(2), v(3));
        S(i,:) = [r, az, elev];  % 存为 [r, az, elev]
    end
end
