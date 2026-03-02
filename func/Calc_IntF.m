function F_int = Calc_IntF(VesData3D_Init,VesData3D,k_int,adj_matrix)
N=size(VesData3D,1);
F_int=zeros(N,3);
for i=1:N
    number_adj=find(adj_matrix(i,:));
    for j=number_adj
        d1=norm(VesData3D_Init(j,:)-VesData3D_Init(i,:));
        d2=norm(VesData3D(j,:)-VesData3D(i,:));
        F_int(i,:)=F_int(i,:)+k_int*(d2-d1)*(VesData3D(j,:)-VesData3D(i,:))./d2;
    end
end

end

