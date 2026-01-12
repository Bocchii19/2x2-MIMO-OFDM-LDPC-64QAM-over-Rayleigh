function H = createSimpleLDPCMatrix(M, N)
    % CREATESIMPLELDPCMATRIX Tạo ma trận parity-check LDPC đơn giản
    %
    % Inputs:
    %   M: Số hàng (số parity bits)
    %   N: Số cột (codeword length)
    %
    % Output:
    %   H: Ma trận parity-check sparse [M x N]
    %
    % Tạo regular LDPC matrix với cấu trúc quasi-cyclic đơn giản
    
    % Sử dụng seed cố định để có kết quả reproducible
    rng(42);
    
    % Column weight (số 1 trong mỗi cột) - thường là 3-4 cho LDPC tốt
    colWeight = 3;
    
    % Khởi tạo ma trận sparse
    H = sparse(M, N);
    
    % Phương pháp Gallager Construction
    % Chia ma trận thành colWeight sub-matrices, mỗi cái có đúng 1 phần tử 1 trên mỗi cột
    rowsPerSubMatrix = floor(M / colWeight);
    
    for subIdx = 1:colWeight
        startRow = (subIdx - 1) * rowsPerSubMatrix + 1;
        
        if subIdx == 1
            % Sub-matrix đầu tiên: phân phối đều
            for col = 1:N
                rowIdx = mod(col - 1, rowsPerSubMatrix) + startRow;
                H(rowIdx, col) = 1;
            end
        else
            % Các sub-matrix tiếp theo: hoán vị cột của sub-matrix đầu
            perm = randperm(N);
            for col = 1:N
                rowIdx = mod(perm(col) - 1, rowsPerSubMatrix) + startRow;
                H(rowIdx, col) = 1;
            end
        end
    end
    
    % Xử lý các hàng còn lại (nếu M không chia hết cho colWeight)
    remainingRows = M - colWeight * rowsPerSubMatrix;
    if remainingRows > 0
        for row = (M - remainingRows + 1):M
            % Thêm 1s ngẫu nhiên để đảm bảo mỗi hàng có weight đủ
            numOnes = ceil(N * colWeight / M);
            cols = randperm(N, min(numOnes, N));
            H(row, cols) = 1;
        end
    end
    
    % Đảm bảo mỗi cột có ít nhất 2 phần tử 1
    for col = 1:N
        colSum = full(sum(H(:, col)));
        if colSum < 2
            availRows = find(H(:, col) == 0);
            numToAdd = max(2 - colSum, 0);
            if length(availRows) >= numToAdd
                addRows = availRows(randperm(length(availRows), numToAdd));
                H(addRows, col) = 1;
            end
        end
    end
    
    % Đảm bảo mỗi hàng có ít nhất 2 phần tử 1
    for row = 1:M
        rowSum = full(sum(H(row, :)));
        if rowSum < 2
            availCols = find(H(row, :) == 0);
            numToAdd = max(2 - rowSum, 0);
            if length(availCols) >= numToAdd
                addCols = availCols(randperm(length(availCols), numToAdd));
                H(row, addCols) = 1;
            end
        end
    end
    
    % Đảm bảo ma trận có dạng chuẩn cho LDPC encoder
    % H = [A | I_M] hoặc tương đương để encoder hoạt động
    % Thực hiện Gaussian elimination để đưa về dạng systematic
    H = makeSystematicLDPC(H);
    
    % Reset random seed
    rng('shuffle');
    
    % Đảm bảo output là sparse LOGICAL (yêu cầu của ldpcEncoderConfig)
    H = sparse(logical(H > 0));
end

function H_sys = makeSystematicLDPC(H)
    % Đưa ma trận H về dạng [A | I] hoặc gần như vậy
    % sử dụng Gaussian elimination trên GF(2)
    
    [M, N] = size(H);
    H_work = full(H);
    
    % Gaussian elimination trên GF(2)
    pivotCol = N - M + 1;  % Bắt đầu từ cột parity
    
    for row = 1:M
        % Tìm pivot
        found = false;
        for col = pivotCol:N
            if H_work(row, col) == 1
                % Hoán đổi cột nếu cần
                if col ~= pivotCol
                    H_work(:, [pivotCol, col]) = H_work(:, [col, pivotCol]);
                end
                found = true;
                break;
            end
        end
        
        if ~found
            % Tìm hàng có 1 ở cột pivotCol và hoán đổi
            for r = row+1:M
                if H_work(r, pivotCol) == 1
                    H_work([row, r], :) = H_work([r, row], :);
                    found = true;
                    break;
                end
            end
        end
        
        if found
            % Khử các hàng khác
            for r = 1:M
                if r ~= row && H_work(r, pivotCol) == 1
                    H_work(r, :) = mod(H_work(r, :) + H_work(row, :), 2);
                end
            end
        end
        
        pivotCol = pivotCol + 1;
        if pivotCol > N
            break;
        end
    end
    
    H_sys = sparse(logical(H_work));
end
