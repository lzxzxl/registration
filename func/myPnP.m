function [R,t,inliers] = myPnP(pts3d,pts2d,K,varargin)

pts2d_homo = [pts2d';ones(1,size(pts2d',2))];  %2维平面点转为齐次坐标
pts2d_homo = K\pts2d_homo;  %左乘K可逆
pts2d_nor = pts2d_homo(1:2,:)';  %取前两行再转置

inliers = ones(1,length(pts3d));

[R,t] = ASPnP(pts3d',pts2d_nor', K);       

if isempty(R) || isempty(t)
    R = eye(3,3); t = zeros(3,1);
end
if numel(size(R)) == 3
    R = R(:,:,1);
    t = t(:,1);
end

end
