function [Adj, Adj_dir] = buildadj_full(A, B)
    A = A(:); B = B(:);
    n = numel(A);
    assert(numel(B) == n);

    Adj     = zeros(n, n, 'uint8');
    Adj_dir = zeros(n, n, 'uint8');

    valid = (B ~= 0);
    child = find(valid);              % 子节点在A中的位置 = 行号
    parentID = B(valid);              % 父节点真实ID

    [tf, parentPos] = ismember(parentID, A);  % parentPos 是父节点在A中的位置
    if any(~tf)
        bad = parentID(~tf);
        error('以下父节点不在A中：%s', mat2str(unique(bad(:).')));
    end

    % 有向：父->子（父行 子列）
    Adj_dir(sub2ind([n n], parentPos, child)) = 1;

    % 无向：补对称
    Adj(sub2ind([n n], parentPos, child)) = 1;
    Adj(sub2ind([n n], child, parentPos)) = 1;
end
