function [A] = shapedis(vessel)
N=size(vessel,1);
A=zeros(N,1);

for i=2:N
    if vessel(i,1)-vessel(i-1,1)==0
        if vessel(i,2)-vessel(i-1,2)>0
            A(i)=60;
        else
            A(i)=20;
        end
        continue;
    end
    k=(vessel(i,2)-vessel(i-1,2))/(vessel(i,1)-vessel(i-1,1));
    if k<-0.26 && k>-3.73
        if vessel(i,2)-vessel(i-1,2)>0
            A(i)=50;
        else
            A(i)=10;
        end
    elseif k<=-3.73 || k>=3.73
        if vessel(i,2)-vessel(i-1,2)>0
            A(i)=60;
        else
            A(i)=20;
        end
    elseif k<3.73 && k>0.26
        if vessel(i,2)-vessel(i-1,2)>0
            A(i)=70;
        else
            A(i)=30;
        end
    elseif k<=0.26 && k>=-0.26
        if vessel(i,1)-vessel(i-1,1)>0
            A(i)=80;
        else
            A(i)=40;
        end
    end
end
end

