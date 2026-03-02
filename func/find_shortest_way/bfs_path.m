function [outx, outy, flag] = bfs_path(img, x, y, s, t, imgproj_DT, img_DT) %#ok<INUSD>
% BFS_PATH_MATLAB  MATLAB replacement for the provided MEX
% Inputs:
%   img         : rows x cols double
%   x, y        : vectors of coordinates (assumed 0-based, like in the MEX)
%   s, t        : indices into x,y (1-based in MATLAB, same as MEX expects)
%   imgproj_DT  : rows x cols double
%   img_DT      : rows x cols double (unused, kept for signature consistency)
% Outputs:
%   outx,outy   : 1 x path_len double (coordinates in the same convention as MEX)
%   flag        : 1 if found, 0 if no path

    flag = 1;

    [rows, cols] = size(img);
    total_pixels = rows * cols;

    % dist/step initialization (same semantics as C code)
    dist = ones(rows, cols) * total_pixels;   % large
    step = -ones(rows, cols);                 % unvisited

    % Pre-edit img as in MEX: if imgproj_DT <= 2 and img == 0 -> set to 5
    mask = (imgproj_DT <= 2) & (img == 0);
    img(mask) = 5;

    % Start/end (note: in MEX it uses x[s-1], so MATLAB uses x(s))
    start_x = long(x(s));
    start_y = long(y(s));
    end_x   = long(x(t));
    end_y   = long(y(t));

    % Special case: start == end (MEX outputs +1 only in this case)
    if start_x == end_x && start_y == end_y
        outx = double(start_x) + 1;  % keep MEX behavior
        outy = double(start_y) + 1;
        return;
    end

    % Convert (x,y) 0-based -> MATLAB subscripts (row,col)
    % col = x+1, row = y+1
    sr = double(start_y) + 1;
    sc = double(start_x) + 1;
    er = double(end_y) + 1;
    ec = double(end_x) + 1;

    % Bounds check (defensive)
    if sr < 1 || sr > rows || sc < 1 || sc > cols || er < 1 || er > rows || ec < 1 || ec > cols
        outx = zeros(0,0);
        outy = zeros(0,0);
        flag = 0;
        return;
    end

    % Queue (SPFA-like since it's relax+queue, not priority queue)
    qx = zeros(total_pixels, 1, 'int64');
    qy = zeros(total_pixels, 1, 'int64');
    head = 1;
    tail = 1;
    qx(tail) = start_x;
    qy(tail) = start_y;

    dist(sr, sc) = 0;
    step(sr, sc) = 0;

    found = false;

    % Main loop
    while head <= tail
        cur_x = qx(head);
        cur_y = qy(head);
        head = head + 1;

        cr = double(cur_y) + 1;
        cc = double(cur_x) + 1;

        % Reached end?
        if cur_x == end_x && cur_y == end_y
            found = true;
            % MEX does NOT break here; it keeps exploring.
        end

        % 8-neighborhood
        for dx = -1:1
            for dy = -1:1
                if dx == 0 && dy == 0
                    continue;
                end

                nx = cur_x + dx;
                ny = cur_y + dy;

                % boundary check (nx in [0, cols-1], ny in [0, rows-1])
                if nx < 0 || nx >= cols || ny < 0 || ny >= rows
                    continue;
                end

                nr = double(ny) + 1;
                nc = double(nx) + 1;

                % same as: if (imgproj_DT[nidx] > 40) break;  (break dy-loop only)
                if imgproj_DT(nr, nc) > 40
                    break;
                end

                % passability + relaxation (same as C):
                % if (img[nidx]!=0 && dist[cur] + 1.2*imgproj_DT[nidx] + img[nidx] < dist[nidx])
                newCost = dist(cr, cc) + 1.2 * imgproj_DT(nr, nc) + img(nr, nc);
                if img(nr, nc) ~= 0 && newCost < dist(nr, nc)
                    dist(nr, nc) = newCost;
                    step(nr, nc) = step(cr, cc) + 1;

                    % enqueue
                    tail = tail + 1;
                    qx(tail) = nx;
                    qy(tail) = ny;
                end
            end
        end
    end

    % If end not found / not reached
    if ~found || dist(er, ec) >= total_pixels
        outx = zeros(0,0);
        outy = zeros(0,0);
        flag = 0;
        return;
    end

    % Backtracking (greedy: go to neighbor with smaller dist)
    path_len = step(er, ec) + 1;          % includes start
    outx = zeros(1, path_len);
    outy = zeros(1, path_len);

    cur_x = end_x;
    cur_y = end_y;
    outx(path_len) = double(cur_x);
    outy(path_len) = double(cur_y);

    for i = path_len-1 : -1 : 1
        cr = double(cur_y) + 1;
        cc = double(cur_x) + 1;

        min_dist = dist(cr, cc);
        next_x = cur_x;
        next_y = cur_y;

        for dx = -1:1
            for dy = -1:1
                if dx == 0 && dy == 0
                    continue;
                end

                nx = cur_x + dx;
                ny = cur_y + dy;

                if nx < 0 || nx >= cols || ny < 0 || ny >= rows
                    continue;
                end

                nr = double(ny) + 1;
                nc = double(nx) + 1;

                if dist(nr, nc) < min_dist
                    min_dist = dist(nr, nc);
                    next_x = nx;
                    next_y = ny;
                end
            end
        end

        outx(i) = double(next_x);
        outy(i) = double(next_y);
        cur_x = next_x;
        cur_y = next_y;
    end
end
