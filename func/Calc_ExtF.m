function [F_ext,A] = Calc_ExtF(VesData3D,VesData3D_Match,k_ext)
A=10;
N=size(VesData3D,1);

v=VesData3D_Match./vecnorm(VesData3D_Match, 2, 2);

% 计算 (x·v)v - x，整批向量化
dot_xv = sum(VesData3D .* v, 2);   % N×1，逐行点积
F_ext = k_ext * (dot_xv .*v- VesData3D);   % N×3


% t_1=sum(VesData3D'.*VesData3D_Match');
% t_2=sum(VesData3D_Match'.*VesData3D_Match');
% t=t_1./t_2;
% t=t';
% Fs=VesData3D_Match.*t;
% distent=vecnorm(Fs-VesData3D,2,2);
% distent(distent==0)=inf;
% dir=(Fs-VesData3D)./distent;
% 
% % figure;
% % plot3(VesData3D(:,1),VesData3D(:,2),VesData3D(:,3),'r.','MarkerSize',3);
% % hold on;
% % X=[VesData3D(:,1)';Fs(:,1)';NaN(1,N)];
% % Y=[VesData3D(:,2)';Fs(:,2)';NaN(1,N)];
% % Z=[VesData3D(:,3)';Fs(:,3)';NaN(1,N)];
% % plot3(X(:),Y(:),Z(:),'b-');
% 
% % sp=VesData3D(1,:);
% % d=vecnorm(VesData3D-sp,2,2);
% % d_max=max(d);
% % F_ext=(-16*A/(pi*pi)*(acos(d./d_max)-pi/4).^2+A).*dir;
% 
% % F_ext=k_ext*(vecnorm(VesData3D_Match-VesData3D,2,2)).*dir;
% F_ext=k_ext*(vecnorm(Fs-VesData3D,2,2)).*dir;

end





% function [F_ext,A] = Calc_ExtF(VesData3D,sp)
% A=10;
% N=size(VesData3D,1);
% dir=(VesData3D-sp)./vecnorm(VesData3D-sp,2,2);
% ssp=repmat(sp,[N,1]);
% 
% % figure;
% % plot3(VesData3D(:,1),VesData3D(:,2),VesData3D(:,3),'r.','MarkerSize',3);
% % hold on;
% % X=[VesData3D(:,1)';ssp(:,1)';NaN(1,N)];
% % Y=[VesData3D(:,2)';ssp(:,2)';NaN(1,N)];
% % Z=[VesData3D(:,3)';ssp(:,3)';NaN(1,N)];
% % plot3(X(:),Y(:),Z(:),'b-');
% 
% L_max=max(vecnorm(VesData3D-sp,2,2));
% k_ext=0.12;
% F_ext=k_ext*(L_max-vecnorm(VesData3D-sp,2,2)).*dir;
% 
% 
% end

