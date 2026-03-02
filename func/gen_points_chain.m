function [pts, Map] = gen_points_chain(N,seed)
    % 参数（可改）
    imgSize         = 512;      % 图大小
    segLenRange     = [30, 140]; % 每段长度 x 的范围
    stepLen         = 1;        % 步长
    perturbEvery    = 5;        % 每生成多少点扰动一次方向
    sigmaDeg        = 6;        % 扰动的标准差(度)
    continueFromLast = false;   % 是否从上一段终点继续

    % rng('shuffle'); % 随机种子（需要可复现就改为固定数）
    if seed==0
        rng('shuffle');
    else
        rng(seed);
    end

    pts = zeros(N, 2); % [x, y]，x=列, y=行
    k = 0;             % 已生成点计数
    Map = zeros(imgSize, imgSize); % 0/1 图（如不需要可删）

    while k < N
        % 1) 选择起点 a
        if ~continueFromLast || k == 0
            a = [randi([150, 350]), randi([150, 350])];  % 限定在中间区域生成起点
        else
            a = pts(k, :); % 从上一段终点继续
        end

        % 2) 随机方向 d
        theta = 2*pi*rand(); % 0~2π
        d = [cos(theta), sin(theta)]; % 单位方向

        % 3) 随机段长 x
        segLen = randi(segLenRange);
        segLen = min(segLen, N - k); % 别超过总需求

        % 4) 沿方向生成该段的点
        p = a; % 当前点
        for i = 1:segLen
            % 第一个点：就把起点算进去（也可以选择从下一个步长点开始）
            if i == 1 && (~continueFromLast || k == 0)
                q = p;
            else
                q = p + stepLen * d; % 新点
            end

            % 越界处理：若越界，则直接终止本段，换新段
            if q(1) < 1 || q(1) > imgSize || q(2) < 1 || q(2) > imgSize
                break; % 结束本段
            end

            % 记点（取整到像素网格）
            k = k + 1;
            q_pix = round(q);
            q_pix(1) = max(1, min(imgSize, q_pix(1)));
            q_pix(2) = max(1, min(imgSize, q_pix(2)));

            pts(k, :) = q_pix;
            Map(q_pix(2), q_pix(1)) = 1; % 行= y, 列= x

            % 更新当前点
            p = q;

            % 每 perturbEvery 个点扰动一次方向
            if mod(i, perturbEvery) == 0
                theta = theta + deg2rad(sigmaDeg) * randn();
                d = [cos(theta), sin(theta)];
            end
        end

        % 如果因为越界提前终止，或本段刚好生成完，会自动回到 while 循环
        % 下一轮会按 continueFromLast 的设置选择起点
    end

    % 如需仅返回点而不要 Map，可把函数签名改为 function pts = gen_points_chain(N)
end
