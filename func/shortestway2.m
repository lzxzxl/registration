function [xs, ys] = shortestway2(im, x, y, s, t) 
%输入x为起点终点实际x坐标，y为起点终点实际y坐标，im为map，s=1,t=2

% 检查起点和终点是否连通
L = bwlabel(im, 8);
if L(y(s), x(s)) ~= L(y(t), x(t))
    error('No path exists between start and end points!');
end

% 调用C++实现的二维最短路径算法（0-based索引）
[xs, ys] = shortest_path_2d(double(im), x-1, y-1, s, t);

% 转换回1-based索引
xs = xs + 1;
ys = ys + 1;
end