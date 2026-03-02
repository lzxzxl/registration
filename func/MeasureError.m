function Err = MeasureError(T,VesData3D,VesData2D)
w=VesData3D.w;
img_DT=VesData2D.img_DT;
N=size(VesData3D.node_positions,1);%三维点数量
VesData3D_Trans=Trans(T,VesData3D);%转化为DSA坐标

VesData3D_Proj=Proj(VesData3D_Trans,VesData2D.K); %横着进入

ptsIdxs=round(VesData3D_Proj);
% ptsIdxs(ptsIdxs<1) = 1;
% ptsIdxs(ptsIdxs>=size(img_DT,1)) = size(img_DT,1)-1;
% ptsIdxs(ptsIdxs(:,1)<1|ptsIdxs(:,2)<1,:) = [];
% ptsIdxs(ptsIdxs(:,2)>=size(img_DT,1)|ptsIdxs(:,1)>=size(img_DT,2),:) = [];
% 
% %平均距离误差
% m=size(img_DT,1);
% x=ptsIdxs(:,1);y=512-ptsIdxs(:,2);
% disterr=img_DT(y+m*(x-1));
x=ptsIdxs(:,1);
y=512-ptsIdxs(:,2);
lg=length(x);
inx=x<1|x>size(img_DT,2)|y<1|y>size(img_DT,1);
x(inx)=[];
y(inx)=[];
w(inx)=[];

PP=VesData3D.node_positions(VesData3D.rootpoint,:);

dist3D=sqrt(sum((VesData3D.node_positions-PP).^2,2));
dist3D=dist3D./max(dist3D);
dist3D(inx)=[];
sigma=20;
weight=exp(-dist3D*2);
%平均距离误差
m=size(img_DT,1);
disterr=img_DT(y+m*(x-1)).*weight.*w;

% Err=(sum(disterr)+100*(lg-length(x)))/lg;
Err=sum(disterr)/length(x)+floor((lg-length(x))/100); %!!!!!sum/length
Err = double(Err);













% w  = VesData3D.w(:);
% DT = VesData2D.img_DT;
% 
% H = size(DT,1);
% W = size(DT,2);
% 
% VesData3D_Trans = Trans(T, VesData3D);
% VesData3D_Proj  = Proj(VesData3D_Trans, VesData2D.K);
% 
% pts = round(VesData3D_Proj);
% x = pts(:,1);
% y = H - pts(:,2);                 % 你原来写死 512，这里用 H 更安全
% 
% % ---- 根节点距离权重（越靠近根，weight 越大）----
% rootIdx = VesData3D.rootpoint;
% PP = VesData3D.node_positions(rootIdx,:);
% dist3D = sqrt(sum((VesData3D.node_positions - PP).^2, 2));
% dist3D = dist3D ./ max(dist3D + eps);
% 
% sigma  = 20; %#ok<NASGU>  % 你这里没用到 sigma，可删
% weight = exp(-2 * dist3D);        % 或 exp(-(dist3D.^2)/(2*sigma^2)) 之类
% 
% % ---- 越界 mask（不删点）----
% inx = (x<1 | x>W | y<1 | y>H);
% 
% % ---- 将索引 clamp 到边界，用于从 DT 取值（不会报错）----
% xc = min(max(x,1), W);
% yc = min(max(y,1), H);
% 
% lin = yc + H*(xc-1);
% d_in = DT(lin);                   % 越界点也会取到边界 DT 值（偏乐观）
% 
% % ---- 对越界点加“额外罚项”：越界越多罚越大；且乘 weight*w 使根附近更敏感 ----
% dx = max(0, 1-x) + max(0, x-W);
% dy = max(0, 1-y) + max(0, y-H);
% outDist = sqrt(dx.^2 + dy.^2);
% 
% lambda_out = 5;                   % 罚项强度（可调大：更不允许越界）
% penalty = lambda_out * outDist;
% 
% d = d_in + penalty.*inx;          % 越界点: d = DT边界值 + 罚项
% 
% disterr = d .* weight .* w;
% 
% % ---- 误差（不需要 lg-length(x) 这种补丁了）----
% Err = sum(disterr) / numel(disterr);
% Err = double(Err);


end

