function images_to_gif(input_folder, output_gif, delay_time)
% input_folder : 图片所在的文件夹路径
% output_gif   : 输出的 gif 文件名，例如 'out.gif'
% delay_time   : 每帧的停留时间（秒）

if nargin < 3
    delay_time = 0.1; % 默认每帧 0.1 秒
end

% 列出常见图片格式
img_types = {'*.png', '*.jpg', '*.jpeg', '*.bmp', '*.tif'};
file_list = [];

% 搜索所有格式
for k = 1:length(img_types)
    file_list = [file_list; dir(fullfile(input_folder, img_types{k}))];
end

% 按照文件名排序
[~, idx] = sort({file_list.name});
file_list = file_list(idx);

% 检查是否为空
if isempty(file_list)
    error('文件夹中没有找到任何图片！');
end

fprintf('总共找到 %d 张图片\n', length(file_list));

for i = 1:length(file_list)
    % 读取图片
    img_path = fullfile(input_folder, file_list(i).name);
    img = imread(img_path);

    % 将图像转为 indexed（gif 必须是 indexed 或 RGB）
    [A, map] = rgb2ind(img, 256);

    % 写入 GIF
    if i == 1
        imwrite(A, map, output_gif, ...
            'gif', 'LoopCount', Inf, 'DelayTime', delay_time);
    else
        imwrite(A, map, output_gif, ...
            'gif', 'WriteMode', 'append', 'DelayTime', delay_time);
    end

    fprintf('已写入：%s\n', file_list(i).name);
end

fprintf('GIF 生成完成：%s\n', output_gif);
end
