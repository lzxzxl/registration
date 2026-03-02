function [] = draw1(S,plane4,VesData3D_Trans,VesData3D_Seg,VesData2D_drawcenterline)



v2_plane = projectPointsToPlaneFromSource(VesData3D_Trans, S, plane4);  % Nx3
%% ==== Plot ====
figure('Color','w'); hold on; axis equal; grid on; box on;
xlabel('X'); ylabel('Y'); zlabel('Z');
view(3);

% 1) 画平面（半透明）
patch('Vertices', plane4, 'Faces', [1 2 3 4], ...
      'FaceAlpha', 0.15, 'EdgeAlpha', 0.6, 'LineWidth', 1.5);

% 2) 画光源点
% plot3(S(1),S(2),S(3),'o','MarkerSize',10,'LineWidth',2);

% 3) 画四棱锥侧面：S 与平面四边形的四条边组成4个三角面
V = [S; plane4];  % 顶点表：1是S，2~5是平面四点
F_side = [1 2 3;
          1 3 4;
          1 4 5;
          1 5 2];

a_face = 0.08;         % 面透明度
a_edge = 0.06;         % 边透明度（想更明显就调大一点，比如0.3）

patch('Vertices', V, 'Faces', F_side, ...
       'FaceAlpha', a_face, ...
       'EdgeAlpha', a_edge, ...
      'LineWidth', 1.5);

% （可选）底面也用同色透明，表示“投影平面区域”
F_base = [2 3 4 5];
patch('Vertices', V, 'Faces', F_base, ...
       'FaceAlpha', 0.02, ...
       'EdgeAlpha', a_edge, ...
      'LineWidth', 1.2);


for i=1:numel(VesData3D_Seg)
    temp=VesData3D_Seg(i).idx;
    plot3(VesData3D_Trans(temp,1),VesData3D_Trans(temp,2),VesData3D_Trans(temp,3),'Color',[220/255,11/255,15/255],'LineWidth',1.5);
end

plot3(VesData2D_drawcenterline(:,1),VesData2D_drawcenterline(:,2),VesData2D_drawcenterline(:,3),'.','Color',[83/255,214/255,0/255],'MarkerSize',4);

% 5) 画平面上的投影点/投影线
plot3(v2_plane(:,1), v2_plane(:,2), v2_plane(:,3)+10, '.','Color',[220/255,10/255,18/255], 'MarkerSize', 4);



% legend({'Plane','Light source','Projection pyramid','3D centerline','Projected pts','Rays'}, ...
%        'Location','bestoutside');


axis tight
% 再保留等比例（不拉伸）
daspect([1 1 6])     % 或者 axis equal

ax = gca;
axis(ax,'off');   % 最彻底：轴线、刻度、标签、网格全部隐藏

end
%% ===== Helper: 从点光源把3D点投到给定平面 =====
function Q = projectPointsToPlaneFromSource(P, S, plane4)
% P: Nx3 3D points
% S: 1x3 light source
% plane4: 4x3 coplanar points defining plane
% Q: Nx3 intersection points on plane along ray S->P

% plane normal
p0 = plane4(1,:);
n  = cross(plane4(2,:)-p0, plane4(3,:)-p0);
n  = n / norm(n);

dir = P - S;           % Nx3 ray directions
den = dir * n(:);      % Nx1
num = (p0 - S) * n(:); % scalar

t = num ./ den;        % Nx1
Q = S + dir .* t;      % Nx3
end
