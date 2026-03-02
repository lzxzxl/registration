function R = randomRFromAngle(x,seed)
    % 输入: x —— 总旋转角（单位：度）
    % 输出: pitch, yaw, roll —— 随机欧拉角（单位：度）
    
    % 1. 随机生成旋转轴 (单位化)
    if seed==0
        rng('shuffle');
    else
        rng(seed);
    end

    n = randn(1,3);
    n = n / norm(n);
    nx = n(1); ny = n(2); nz = n(3);
    
    % 2. 将角度转为弧度
    theta = deg2rad(x);
    
    % 3. Rodrigues旋转公式生成旋转矩阵
    K = [   0   -nz   ny;
          nz     0   -nx;
         -ny    nx     0];
    R = eye(3) + sin(theta)*K + (1 - cos(theta))*(K*K);

    
end
