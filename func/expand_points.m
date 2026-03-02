function B = expand_points(A)
% % A: N×2 点集
% % dedup: 是否去重（默认 true）
% % B: (最多 4N)×2 扩展后的整数点
% 
% 
% x1 = floor(A(:,1));  x2 = ceil(A(:,1));
% y1 = floor(A(:,2));  y2 = ceil(A(:,2));
% 
% % 直接堆叠四种组合（向量化）
% B = [
%     x1, y1;   % (floor x, floor y)
%     x1, y2;   % (floor x, ceil y)
%     x2, y1;   % (ceil x, floor y)
%     x2, y2    % (ceil x, ceil y)
% ];
% 
% % 可选：去重（处理相邻点重合、或原本整数点导致的重复）
% 
% B = unique(B, 'rows');

x1=round(A(:,1));y1=round(A(:,2));
B=[x1,y1;
   x1,y1-1;
   x1,y1+1;
   x1-1,y1;
   x1-1,y1-1;
   x1-1,y1+1;
   x1+1,y1-1;
   x1+1,y1;
   x1+1,y1+1
];
B = unique(B, 'rows');
end
