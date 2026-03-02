function vessel_3DLine = vessel_generation(folder)

% folder = 'F:\MatlabProject\MyRegistration\data\bmp_line\9132496\'; 

t = 50;% 设置红色检测的阈值
areaThreshold = 2500; % 设置面积阈值，用于过滤大面积血管
borderWidth = 25; % 边框宽度去除四周红色字体

% 获取所有 BMP 文件并按文件名排序
filePattern = fullfile(folder, '*.bmp');
bmpFiles = dir(filePattern);
names = {bmpFiles.name};
[~, sortedIndex] = sort(names);
bmpFiles = bmpFiles(sortedIndex);

N = length(bmpFiles); % 获取图片数量

% 读取第一张图片以确定尺寸
firstImage = imread(fullfile(folder, bmpFiles(1).name));
[height, width, ~] = size(firstImage);

% 预分配三维逻辑数组，用于存储血管体积数据
vesselVolume = false(height, width, N);

% 循环处理每一张图片
for k = 1:N
    % 读取当前图片
    img = imread(fullfile(folder, bmpFiles(k).name));
    % 裁剪图像去除图片四周的红色字体
    img = removeRedText(img, borderWidth, t);
    % 提取红色线条，创建二值掩膜
    redMask = img(:,:,1) > img(:,:,2) + t & img(:,:,1) > img(:,:,3) + t;
    
    % 填充红色线条包围的区域，得到血管区域
    filledMask = imfill(redMask, 'holes');
    
    %标记连通区域并计算面积
    labeledMask = bwlabel(filledMask);
    props = regionprops(labeledMask, 'Area');

    % 将填充后的掩膜存储到三维数组的对应层
    vesselVolume(:,:,k) = filledMask;
end


% 将三维血管模型保存为 .mat 文件
save('vessel_model.mat', 'vesselVolume');

%% 打印原生血管图
% 将逻辑数组转换为 double 类型，以便使用 isosurface
vesselVolumeDouble = double(vesselVolume);

% 生成 isosurface，阈值设为 0.5
fv = isosurface(vesselVolumeDouble, 0.5);

% 创建一个新的图形窗口
figure;
% 使用 patch 显示 isosurface
p = patch(fv, 'FaceColor', 'red', 'EdgeColor', 'none');

% 设置光照效果
light('Position', [1 1 1]);  % 添加光源
camlight;  % 调整光照方向
lighting gouraud;  % 设置光照模型

% 设置视图
view(3);  % 三维视图
axis equal; 
axis tight; 
xlabel('X');
ylabel('Y');
zlabel('Z');
%% 

% 进行三维骨架化 skeleton = bwskel(vesselVolume); 这个结果会造成所有连通分量连在一块

M=vesselVolume;
SE = strel("sphere",7);
N = imopen(M,SE);
SE = strel("cube",3);
N=imdilate(N,SE);
M(N==1)=0;
L = bwlabeln(M,26);

region=zeros([1 max(L(:))]);
for i=1:max(L(:))
    Q=L==i;
    region(i)=length(find(Q(:)==1));
end
[~,id]=sort(region,'descend');
W=(L==id(1))|(L==id(2));
Lw=bwlabeln(W,26);
L=Lw==2;
B = bwskel(~(L==L(1,1,1)));

[w,l,h]=size(B);

f=zeros(size(B));
shape_endpts = bwmorph3(B,'endpoints');  %发现端点
[ye,xe,ze]=ind2sub([w,l,h],find(shape_endpts(:)));
[y,x,z]=ind2sub([w,l,h],find(B(:)));
si=find(x==xe(1)&y==ye(1)&z==ze(1));

for i=2:length(ye)
    ti=find(x==xe(i)&y==ye(i)&z==ze(i));
    [xm,ym,zm]=shortestway3(B,x,y,z,si,ti);
    f((zm-1)*w*l+(xm-1)*w+ym)=1;  %消除不符合血管流动的噪声
end



s=exskeleton3d(f,10);
figure;
[y,x,z]=ind2sub([w,l,h],find(s(:)));
plot3(x,y,z,'.','Markersize',4,'MarkerFaceColor','r','Color','r');
set(gcf,'Color','white');
axis equal
xlabel('X');
ylabel('Y');
zlabel('Z');


vessel_3DLine=s;
save('CTA_Centralline_left.mat','vessel_3DLine');




function cleanedImg = removeRedText(img, borderWidth, t)
    [height, width, ~] = size(img);
    
    % 创建掩膜，标记边框区域
    mask = false(height, width);
    mask(1:borderWidth, :) = true;  % 顶部
    mask(end-borderWidth+1:end, :) = true;  % 底部
    mask(:, 1:borderWidth) = true;  % 左侧
    mask(:, end-borderWidth+1:end) = true;  % 右侧
    
    % 在边框区域内找到红色像素
    redPixels = img(:,:,1) > img(:,:,2) + t & img(:,:,1) > img(:,:,3) + t & mask;
    
    % 将红色像素设置为背景色（黑色）
    cleanedImg = img;
    cleanedImg(repmat(redPixels, [1 1 3])) = 0;
end
end

