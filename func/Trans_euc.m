function S = Trans_euc(A,parent)
    N=size(A,1);
    S=zeros(N,3);
    S(1,:)=A(1,:);
    for i=2:N
        r=A(i,1);
        az=A(i,2);
        elev=A(i,3);
        [dx,dy,dz] = sph2cart(az,elev,r);
        p=parent(i);
        S(i,:)=S(p,:)+[dx,dy,dz];
    end
end

