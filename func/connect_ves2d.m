function Centerline = connect_ves2d(Centerline,adj_matrix)
N=size(Centerline,1);
deg=sum(adj_matrix,2);
endpoint=[];
for i=1:N
    if deg(i)==1
        endpoint=[endpoint,i];
    end
end

for i=endpoint
    newpoint=[];
    j1=i-1;j2=i-2;
    d1=Centerline(i,:)-Centerline(j1,:);
    d2=Centerline(j1,:)-Centerline(j2,:);
    d1=d1/norm(d1);
    d2=d2/norm(d2);
    d=(d1+d2)/2;
    d=d/norm(d);
    for j=1:15
        newpoint=[newpoint;[Centerline(i,1)+j*d(1),Centerline(i,2)+j*d(2)]];
    end
    newpoint=round(newpoint);
    Centerline=[Centerline;newpoint];
end
figure;
plot(Centerline(:,1),Centerline(:,2),'g.');


end

