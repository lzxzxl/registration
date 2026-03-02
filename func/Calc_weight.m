function w = Calc_weight(N,VesData2D,VesData3D_Seg)
Num_seg=size(VesData3D_Seg,2);
img_DT=VesData2D.img_DT; 
w=ones(N,1);

for i=1:Num_seg
vestemp=VesData3D_Seg(i).positions;
num_pot=size(vestemp,1);

vesidx=VesData3D_Seg(i).idx;
vestemp_proj=Proj(vestemp',VesData2D.K);


%%%%算误差
vestemp_proj1=double(round(vestemp_proj));%专门算距离
x=vestemp_proj1(:,1);
y=512-vestemp_proj1(:,2);
x = min(max(x, 1), 511);%！！新增
y = min(max(y, 1), 511);%！！新增
m=size(img_DT,1);
disterr=img_DT(y+m*(x-1));
vestemp_err=sum(disterr)/num_pot;

if vestemp_err<4
    continue;
else
    id=2;
    while id<num_pot
        xx=x(id:num_pot);
        yy=y(id:num_pot);
        disterr_temp=img_DT(yy+m*(xx-1));
        temp_err=sum(disterr_temp)/(num_pot-id+1);
        if temp_err<10
            id=id+2;
        else
            break;
        end

    end
    if id>=num_pot
        continue;
    else
        clear_id=vesidx(id:end);
        w(clear_id)=0;
    end

end


end





end

