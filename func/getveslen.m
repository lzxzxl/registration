function len = getveslen(vessel)
diff_coords = diff(vessel, 1, 1);  % 沿第一维计算差分
len = sum(sqrt(sum(diff_coords.^2, 2)));  % 计算欧氏距离并求和
end

