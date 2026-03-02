function err = MeasureError_2d_exp(img_DT,VesData3D_Proj_child,w)  %无512-
m=size(img_DT,1);
dist2D=sqrt(sum((VesData3D_Proj_child-VesData3D_Proj_child(1,:)).^2,2));
dist2D=dist2D./max(dist2D);
weight=exp(-dist2D*2);

x=round(VesData3D_Proj_child(:,1));
y=round(VesData3D_Proj_child(:,2));
x = min(max(x, 1), 511);y = min(max(y, 1), 511);
err=img_DT(y+m*(x-1)).*weight.*w;
err=mean(err);
end

