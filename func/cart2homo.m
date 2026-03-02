function homo = cart2homo(cart)  %变成齐次式
homo = [cart;ones(1,size(cart,2))];
end

