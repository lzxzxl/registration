% function [dist, path] = DTW(X, Y)
%     N = size(X, 1);
%     M = size(Y, 1);
% 
%     % 计算距离矩阵
%     D = zeros(N, M);
%     for i = 1:N
%         for j = 1:M
%             D(i, j) = sqrt((X(i,1)-Y(j,1))^2 + (X(i,2)-Y(j,2))^2);
%         end
%     end
% 
%     % 初始化累积代价矩阵
%     C = inf(N, M,'single'); % 用inf初始化避免未定义区域影响min
%     C(1,1) = D(1,1);
% 
%     % 填充第一列
%     for i = 2:N
%         C(i,1) = D(i,1) + C(i-1,1);
%     end
% 
%     % 填充第一行
%     for j = 2:M
%         C(1,j) = D(1,j) + C(1,j-1);
%     end
% 
%     % 填充剩余部分
%     for i = 2:N
%         for j = 2:M
%             min_cost = min([C(i-1,j), C(i,j-1), C(i-1,j-1)]);
%             C(i,j) = D(i,j) + min_cost;
%         end
%     end
% 
%     dist = C(N, M);
% 
%     % 改进的回溯路径
%     path = [];
%     i = N;
%     j = M;
% 
%     while (i >= 1) && (j >= 1)
%         path = [i, j; path]; % 插入头部保持顺序
% 
%         if i == 1 && j == 1
%             break;
%         elseif i == 1
%             j = j - 1;
%         elseif j == 1
%             i = i - 1;
%         else
%             [~, idx] = min([C(i-1,j), C(i,j-1), C(i-1,j-1)]);
%             if idx == 1
%                 i = i - 1;
%             elseif idx == 2
%                 j = j - 1;
%             else
%                 i = i - 1;
%                 j = j - 1;
%             end
%         end
%     end
% 
%     dd=0;
%     NN=size(path,1);
%     for k=1:NN
%         % fac=-9/10*(N-1)^2*(path(k,1)-1)^2+1;
%         fac=-10/(NN-1)*(path(k,1)-1)+10;
%         dd=dd+fac*D(path(k,1),path(k,2));
%     end
%     % dist=dd;
% 
% 
% end

function [dist, path] = DTW(X, Y)
    X = single(X); Y = single(Y);
    N = size(X,1); M = size(Y,1);

    % 距离矩阵（向量化），比双for快很多
    % D(i,j)=||X(i,:)-Y(j,:)||
    DX = X(:,1); DY = X(:,2);
    EX = Y(:,1)'; EY = Y(:,2)';
    D = hypot(DX-EX, DY-EY);   % N×M single

    C = inf(N,M,'single');
    C(1,1) = D(1,1);
    C(2:N,1) = cumsum(D(2:N,1)) + C(1,1);
    C(1,2:M) = cumsum(D(1,2:M)) + C(1,1);

    for i = 2:N
        for j = 2:M
            C(i,j) = D(i,j) + min([C(i-1,j), C(i,j-1), C(i-1,j-1)]);
        end
    end
    dist = C(N,M);

    % 回溯：先尾插，再翻转（避免头插反复拷贝）
    i=N; j=M;
    path = zeros(N+M,2,'int32'); % 上界长度
    k = 0;
    while true
        k = k+1;
        path(k,:) = [i,j];
        if i==1 && j==1, break; end
        if i==1
            j=j-1;
        elseif j==1
            i=i-1;
        else
            [~,idx] = min([C(i-1,j), C(i,j-1), C(i-1,j-1)]);
            if idx==1, i=i-1;
            elseif idx==2, j=j-1;
            else, i=i-1; j=j-1;
            end
        end
    end
    path = flipud(path(1:k,:));
end
