% function Simvessel_sph = Add_anglenoise(Simvessel_sph,parent,para1)
%     %para1表示噪声幅度，Simvessel_sph(1)为根节点笛卡尔坐标，其余为球体坐标
%     rng(40);
%     N=size(Simvessel_sph,1);
%     pathdist=zeros(N,1);
%     for i=2:N
%         p=parent(i);
%         pathdist(i)=pathdist(p)+Simvessel_sph(i,1);
%     end
%     alpha=pathdist./max(pathdist);
%     amp=para1*alpha;
%     amp(1)=[];
%     noise1=(2*rand(N-1,1)-1).*amp;
%     noise2=(2*rand(N-1,1)-1).*amp;
%     Simvessel_sph(2:end,2)=Simvessel_sph(2:end,2)+noise1;
%     Simvessel_sph(2:end,3)=Simvessel_sph(2:end,3)+noise2;
% 
%     Simvessel_sph(2:end,3)=max(min(Simvessel_sph(2:end,3),pi/2),-pi/2);
%     Simvessel_sph(2:end,2)=max(min(Simvessel_sph(2:end,2),pi),-pi);
% 
% 
% end

function [Simvessel_sph, noise_ang2, noise_ang3] = Add_anglenoise(Simvessel_sph, parent, para1, opts)
% 平衡式角度噪声：沿每条分支生成“平滑噪声”，在分叉处与父分支连续；
% 噪声幅度随路径长度递增；并限制相邻节点角度增量，抑制锯齿。
%
% 输入
%   Simvessel_sph: N×3，1行为根(笛卡尔[x,y,z])，2..N行为相对父节点球坐标[r, ang2, ang3]
%                  约定 ang2∈[-pi,pi] (方位角)，ang3∈[-pi/2,pi/2] (仰角)
%   parent       : N×1，parent(1)=0，i>1 的父索引
%   para1        : 基础噪声幅度（标量，单位=弧度上限，大致控制远端最大扰动）
%   opts         : 可选结构体：
%       .seed            随机种子（默认40）
%       .ell_edges       平滑窗口半宽（默认8，窗口=2*ell+1）
%       .sigma_root_frac 根附近幅度比例（默认0.15）
%       .max_step_deg    相邻节点最大角度增量（默认3度）
%
% 输出
%   Simvessel_sph: 角度添加噪声后的结果（边界已处理）
%   noise_ang2   : 实际施加在 ang2 上的噪声（N×1，根为0）
%   noise_ang3   : 实际施加在 ang3 上的噪声（N×1，根为0）

    if nargin < 4, opts = struct; end
    if ~isfield(opts,'seed'), opts.seed = 40; end
    if ~isfield(opts,'ell_edges'), opts.ell_edges = 8; end
    if ~isfield(opts,'sigma_root_frac'), opts.sigma_root_frac = 0.15; end
    if ~isfield(opts,'max_step_deg'), opts.max_step_deg = 3; end

    rng(opts.seed);

    N = size(Simvessel_sph,1);
    if N ~= numel(parent), error('parent 长度需等于节点数'); end
    if parent(1) ~= 0, error('parent(1) 必须为 0 (根)'); end

    % ---- 1) 路径累计长度（用 r 累加，根为0） ----
    pathdist = zeros(N,1);
    for i = 2:N
        p = parent(i);
        if p<=0 || p>=i, % 容错：若 parent 非拓扑顺序，也可改为 BFS
            % 这里假设 parent 序给的是从根到叶的拓扑顺序；否则可换成 BFS 顺序计算
        end
        pathdist(i) = pathdist(p) + Simvessel_sph(i,1);
    end
    Lmax = max(pathdist); if Lmax<=0, Lmax = 1; end
    depth01 = pathdist / Lmax; % 0..1

    % ---- 2) 构建孩子邻接表 & 分支拆分 ----
    children = cell(N,1);
    for i = 2:N
        children{parent(i)} = [children{parent(i)}; i]; %#ok<AGROW>
    end
    branches = extract_branches(parent, children);

    % ---- 3) 构造平滑核 ----
    win_len = max(3, 2*opts.ell_edges + 1);
    win = gausswin(win_len);
    win = win / sum(win);

    % ---- 4) 容器 ----
    noise_ang2 = zeros(N,1);  % ang2 对应 [-pi, pi]
    noise_ang3 = zeros(N,1);  % ang3 对应 [-pi/2, pi/2]

    % ---- 5) 遍历每条分支：生成平滑噪声、分叉连续、步长限制 ----
    step_max = opts.max_step_deg * pi/180;

    for b = 1:numel(branches)
        idx = branches{b};        % 分支上的节点索引（从分叉/根出发的连续段）
        if isempty(idx), continue; end

        m = numel(idx);
        w2 = randn(m,1); w3 = randn(m,1);
        s2 = conv(w2, win, 'same');
        s3 = conv(w3, win, 'same');

        % 幅度随深度增长（根处降低到 para1*sigma_root_frac，远端到 para1）
        scale = opts.sigma_root_frac + (1-opts.sigma_root_frac)*depth01(idx);
        sigma2 = para1 * scale;   % ang2 幅度
        sigma3 = para1 * scale;   % ang3 幅度（也可给 ang3 更小/大一点）

        n2 = s2 .* sigma2;
        n3 = s3 .* sigma3;

        % 分叉连续：让当前分支起点噪声对齐父节点
        p0 = parent(idx(1));
        if p0 ~= 0
            n2 = n2 - n2(1) + noise_ang2(p0);
            n3 = n3 - n3(1) + noise_ang3(p0);
        end

        % 相邻步增量限制（避免锯齿）
        n2 = clip_increment(n2, step_max);
        n3 = clip_increment(n3, step_max);

        noise_ang2(idx) = n2;
        noise_ang3(idx) = n3;
    end

    % ---- 6) 应用噪声并做角度边界处理 ----
    % 索引 2..N 为球坐标
    Simvessel_sph(2:end, 2) = wrapToPi( Simvessel_sph(2:end, 2) + noise_ang2(2:end) );
    ang3_new = Simvessel_sph(2:end, 3) + noise_ang3(2:end);
    Simvessel_sph(2:end, 3) = max(min(ang3_new,  pi/2), -pi/2);  % 仰角夹限
end

% ------- 辅助：把树拆成若干“从分叉点/根到下个分叉/叶”的连续段 -------
function branches = extract_branches(parent, children)
    N = numel(parent);
    deg = cellfun(@numel, children);  % 出度
    isStart = false(N,1);
    isStart(1) = true;
    for i = 2:N
        p = parent(i);
        if deg(p) >= 2 || p == 1
            isStart(i) = true;
        end
    end
    branches = {};
    for i = 1:N
        if ~isStart(i), continue; end
        path = i; cur = i;
        while true
            ch = children{cur};
            if isempty(ch), break; end           % 到叶
            if numel(ch) >= 2, break; end        % 到下一分叉
            nxt = ch(1);
            path(end+1) = nxt; %#ok<AGROW>
            cur = nxt;
        end
        branches{end+1} = path; %#ok<AGROW>
    end
end

% ------- 辅助：限制一维序列的相邻差分幅度 -------
function y = clip_increment(x, step_max)
    if numel(x) <= 1, y = x; return; end
    y = x;
    for k = 2:numel(x)
        d = y(k) - y(k-1);
        if d > step_max,     y(k) = y(k-1) + step_max; end
        if d < -step_max,    y(k) = y(k-1) - step_max; end
    end
end
