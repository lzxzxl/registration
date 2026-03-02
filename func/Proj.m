function VesData3D_Proj = Proj(VesData3D,K)  %进去是3*N,出来是N*3
projMatrix=K*eye(3,4);

%%
VesData3D_Proj=projMatrix*cart2homo(VesData3D);
omegas=(VesData3D_Proj(3,:)).^-1;
VesData3D_Proj=VesData3D_Proj(1:2,:).*repmat(omegas,2,1);
VesData3D_Proj=VesData3D_Proj';
end

