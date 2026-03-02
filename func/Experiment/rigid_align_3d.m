function [R,t,rmse] = rigid_align_3d(A,B)
% A,B: Nx3, known correspondences, solve B ≈ R*A + t
assert(size(A,2)==3 && size(B,2)==3);
assert(size(A,1)==size(B,1) && size(A,1)>=3);

muA = mean(A,1);
muB = mean(B,1);

Ac = A - muA;
Bc = B - muB;

H = Ac' * Bc;
[U,~,V] = svd(H);

R = V*U';
if det(R) < 0
    V(:,3) = -V(:,3);
    R = V*U';
end

t = muB' - R*muA';

% optional error
A2 = (R*A' + t).';          % Nx3
rmse = sqrt(mean(sum((A2 - B).^2,2)));
end
