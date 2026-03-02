function [Generate_tree,adj_matrix]=Generate_randomtree(seed)
addpath(genpath(pwd));

if seed==0
    rng('shuffle');
else
    rng(seed);%40,50
end


%grammar  geometry
grammar.start = 'X';
grammar.rules = containers.Map( ...
    {'X','F'}, ...
    {'F-[[X]+X]+F[+FX]-X', 'FF'} ...
);



geometry.rotate = 25; % 每次转动角度（度）
geometry.actions = containers.Map( ...
    {'-','+','F','[',']'}, ...
    {'left','right','forward','push','pop'} ...
);

Init_dir=[60,0,0];


% figure('Color','w');
% t = tiledlayout(2,2,'Padding','compact','TileSpacing','compact');



for i = 1:4
    str  = replacement(grammar.start, grammar.rules, i+1);       % 重写 i 次
    coords = interpretation3d(str, geometry.actions, ...
                            geometry.rotate, Init_dir, 0, 0, 0);        % 初始角 60°, 起点(0,0)





    % figure;
    % hold on;
    % axis equal;
    % xlabel('X');
    % ylabel('Y');
    % zlabel('Z');
    % for k = 1:numel(coords)
    %     xyz = coords{k};     
    %     plot3(xyz{1}, xyz{2}, xyz{3},'MarkerSize', 1);
    % end
    % title(sprintf('order = %d', i));
end
root = 1;

Generate_tree = cell2mat(cellfun(@(c) [c{1}(:), c{2}(:), c{3}(:)], coords, 'UniformOutput', false));

Generate_tree = unique(Generate_tree, 'rows', 'stable');   % 如果你不想保留分段连接处的重复坐标

N = size(Generate_tree,1);
adj_matrix = zeros(N,N);
for i=1:numel(coords)
    temp = cell2mat(coords{i}(:))';
    a1=find(ismember(Generate_tree,temp(1,:),'rows'));
    for j=2:size(temp,1)
        a2=find(ismember(Generate_tree,temp(j,:),'rows'));
        adj_matrix(a1,a2)=1;
        adj_matrix(a2,a1)=1;
        a1=a2;
    end

end

[Generate_tree,adj_matrix]=shrink_branches(Generate_tree,adj_matrix,15);
[Generate_tree,adj_matrix]=shrink_branches(Generate_tree,adj_matrix,8);
[Generate_tree,adj_matrix]=shrink_branches(Generate_tree,adj_matrix,5);
    
    
    
    
    



% figure;
% plot3(Generate_tree(:,1),Generate_tree(:,2),Generate_tree(:,3),'r.');

end


function out = replacement(strIn, rules, order)
    out = strIn;
    for it = 1:order
        dst = '';  % 逐字符构建
        for j = 1:length(out)
            c = out(j);
            if isKey(rules, c)     % 若有产生式
                dst = [dst, rules(c)]; %#ok<AGROW>
            else
                dst = [dst, c];    %#ok<AGROW>
            end
        end
        out = dst;
    end
end


function coords = interpretation3d(str, actions, rotate, angle, x0, y0, z0)
    linesX = {x0};
    linesY = {y0};
    linesZ = {z0};
    curIdx = 1;
    
    H = [0;0;1]; L = [1;0;0]; U = [0;1;0];
    R = [H, L, U];  % 列向量拼成 3x3 正交基

    R = rot_axis(R, R(:,3), deg2rad(angle(1))); % yaw(U)
    R = rot_axis(R, R(:,2), deg2rad(angle(2))); % pitch(L)
    R = rot_axis(R, R(:,1), deg2rad(angle(3))); % roll(H)


    stackPos = zeros(0,3);
    stackR = zeros(3,3,0);

    stepLen = 1;


    for idx = 1:length(str)
        s = str(idx);

        if ~isKey(actions, s)
            continue;
        end

        act = actions(s);
        rn=rand;
        switch act
            case 'left'
                theta = deg2rad( rotate * (0.7 + 0.6*rand) );   % 0.7~1.3倍随机角
                % if rn>0 && rn<0.28
                %     R = rot_axis(R, R(:,3), -deg2rad(rotate));
                % elseif rn>=0.28 && rn<=0.66
                %     R = rot_axis(R, R(:,2), -deg2rad(rotate));
                % else
                %     R = rot_axis(R, R(:,1), -deg2rad(rotate));
                % end
                if rn < 0.25
                    R = rot_axis(R, R(:,3), -theta);
                elseif rn <= 0.66
                    R = rot_axis(R, R(:,2), -theta);
                else
                    R = rot_axis(R, R(:,1), -theta);
                end
            case 'right'
                theta = deg2rad( rotate * (0.85 + 0.3*rand) );   % 0.7~1.3倍随机角
                % if rn>0 && rn<0.28
                %     R = rot_axis(R, R(:,3), deg2rad(rotate));
                % elseif rn>=0.28 && rn<=0.66
                %     R = rot_axis(R, R(:,2), deg2rad(rotate));
                % else
                %     R = rot_axis(R, R(:,1), deg2rad(rotate));
                % end
                if rn < 0.25
                    R = rot_axis(R, R(:,3), theta);
                elseif rn <= 0.66
                    R = rot_axis(R, R(:,2), theta);
                else
                    R = rot_axis(R, R(:,1), theta);
                end
            case 'forward'
                p = [linesX{curIdx}(end); linesY{curIdx}(end); linesZ{curIdx}(end)];
                p_new = p + R(:,1) * stepLen;             % 沿 H 方向前进
                tx = linesX{curIdx}; ty = linesY{curIdx}; tz = linesZ{curIdx};
                tx(end+1) = p_new(1); ty(end+1) = p_new(2); tz(end+1) = p_new(3);
                linesX{curIdx} = tx; linesY{curIdx} = ty; linesZ{curIdx} = tz;
                
                % angle = angle + 5*randn;
                R(:,1)=R(:,1)+[deg2rad(5*randn),deg2rad(5*randn),deg2rad(5*randn)]';
                % % 小随机扭转：绕随机轴旋转一个小角度（真正的3D扰动）
                % twist = deg2rad(5*randn);          % 扭转幅度
                % axis  = randn(3,1); axis = axis/norm(axis);
                % R = rot_axis(R, axis, twist);
                
                % 每步正交化，防止数值漂移（非常关键）
                [Q,~] = qr(R,0);
                if det(Q) < 0, Q(:,3) = -Q(:,3); end
                R = Q;
                                


            case 'push'
                p = [linesX{curIdx}(end), linesY{curIdx}(end), linesZ{curIdx}(end)];
                stackPos(end+1,:) = p; %#ok<AGROW>
                stackR(:,:,end+1) = R;

            case 'pop'
                if ~isempty(stackPos)
                    % 恢复位姿，并开启一条新折线（从恢复的位置开始）
                    p      = stackPos(end,:);  stackPos(end,:) = [];
                    R      = stackR(:,:,end);  stackR(:,:,end) = [];
                    linesX{end+1} = p(1); %#ok<AGROW>
                    linesY{end+1} = p(2); %#ok<AGROW>
                    linesZ{end+1} = p(3); %#ok<AGROW>
                    curIdx = numel(linesX);
                end
        end
    end

    % 组织输出：每条线是一对 {x_vec, y_vec}
    n = numel(linesX);
    coords = cell(n,1);
    for k = 1:n
        coords{k} = {linesX{k}, linesY{k}, linesZ{k}};
    end
end


function Rnew = rot_axis(Rcur, axis_world, theta)

    a = axis_world(:);
    a = a / max(norm(a), eps);
    K = [  0   -a(3)  a(2);
          a(3)   0   -a(1);
         -a(2)  a(1)   0  ];
    Raxis = eye(3) + sin(theta)*K + (1-cos(theta))*(K*K);
    Rnew  = Rcur * Raxis;
end

function [Generate_tree,adj_matrix]=shrink_branches(Generate_tree,adj_matrix,lenx)
    leaf_idx = find(sum(adj_matrix~=0, 2) == 1);
    del_pot = [];
    for i = leaf_idx'  %列向量不能完成遍历
        if i==1 ,continue;end
        adj = find(adj_matrix(i,:));

        dist=0; %距离
        num_adj = length(adj);

        d1=i;d2=adj;
        while num_adj < 3
           dist = dist + norm(Generate_tree(d1,:)-Generate_tree(d2,:));
           if dist < lenx
                del_pot = [del_pot,d1];
           end
           adj = find(adj_matrix(d2,:));
           num_adj = length(adj);
           if num_adj > 2 ,break;end
           j = adj(adj~=d1);
           d1 = d2;
           d2 = j;

           
        end

    end
    keep=true(size(Generate_tree,1),1);
    Generate_tree(del_pot,:)=[];
    keep(del_pot)=false;
    adj_matrix=adj_matrix(keep,keep);
end