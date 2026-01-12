function cfg = config_params()
    % CONFIG_PARAMS Cấu hình tham số hệ thống 2x2 MIMO-OFDM
    %
    % Output:
    %   cfg: Structure chứa các tham số cấu hình
    
    %% Các tham số cơ bản
    cfg.nTx = 2;            % Số lượng anten phát
    cfg.nRx = 2;            % Số lượng anten thu
    cfg.M = 64;             % Bậc điều chế (64-QAM)
    cfg.k = log2(cfg.M);    % Số bit trên mỗi symbol
    
    %% Tham số OFDM
    cfg.nFFT = 64;          % Kích thước FFT/IFFT
    cfg.nCP = 16;           % Độ dài Cyclic Prefix (1/4 nFFT)
    cfg.nData = 52;         % Số lượng sóng mang con dữ liệu (đã sửa từ 48 thành 52 để khớp với dataSubcarriers)
    % Các vị trí sóng mang dữ liệu (tránh DC và các sóng mang biên)
    % Giả sử sử dụng các chỉ số sóng mang chuẩn:
    % [-26:-1, 1:26] ánh xạ vào FFT bin [39:64, 2:27]
    cfg.dataSubcarriers = [39:64, 2:27]; 
    cfg.nSym = 100;         % Số lượng symbol OFDM mô phỏng trên mỗi vòng lặp SNR
    
    %% Tham số Mã hóa kênh (LDPC Codes)
    % Sử dụng LDPC với rate 1/2
    cfg.ldpcRate = 1/2;                 % Tỷ lệ mã LDPC
    cfg.ldpcMaxIterations = 50;         % Số vòng lặp giải mã LDPC tối đa
    
    % Tạo parity-check matrix H
    % Thử các phương pháp khác nhau theo thứ tự ưu tiên
    cfg.ldpcH = [];
    
    % Phương án 1: DVB-S2 LDPC (Communications Toolbox) - ưu tiên vì ổn định
    % Block size: 64800 bits (normal frame) hoặc 16200 bits (short frame)
    if isempty(cfg.ldpcH)
        try
            cfg.ldpcH = dvbs2ldpc(cfg.ldpcRate);
            fprintf('Su dung DVB-S2 LDPC (rate=1/2, 64800 bits)\n');
        catch ME
            fprintf('dvbs2ldpc FAILED: %s\n', ME.message);
        end
    end
    
    % Phương án 2: IEEE 802.11n LDPC - thử nhiều cách
    if isempty(cfg.ldpcH)
        % Thử các cách gọi khác nhau
        syntaxes = {
            @() ldpcQuasiCyclicMatrix(0.5, 27),
            @() ldpcQuasiCyclicMatrix(1/2, 27),
            @() ldpcQuasiCyclicMatrix('1/2', 27),
            @() ldpcQuasiCyclicMatrix(0.5, '27'),
        };
        for i = 1:length(syntaxes)
            try
                cfg.ldpcH = syntaxes{i}();
                fprintf('Su dung IEEE 802.11n LDPC (syntax %d)\n', i);
                break;
            catch
                % Thử cách tiếp theo
            end
        end
    end
    
    % Phương án 3: Nếu tất cả đều fail
    if isempty(cfg.ldpcH)
        error('Khong the tao LDPC matrix! Vui long chay: help ldpcQuasiCyclicMatrix');
    end
    
    % ĐẢM BẢO ma trận H là sparse logical (yêu cầu của ldpcEncoderConfig)
    cfg.ldpcH = sparse(logical(cfg.ldpcH));
    
    % Tạo encoder và decoder config
    cfg.ldpcEncoderCfg = ldpcEncoderConfig(cfg.ldpcH);
    cfg.ldpcDecoderCfg = ldpcDecoderConfig(cfg.ldpcH);
    
    % Tính info length dựa trên H matrix thực tế
    [M_ldpc, N_ldpc] = size(cfg.ldpcH);
    cfg.ldpcInfoLength = N_ldpc - M_ldpc;  % K = N - M
    cfg.ldpcBlockLength = N_ldpc;           % N = codeword length
    
    fprintf('LDPC: Block=%d, Info=%d, Rate=%.2f\n', cfg.ldpcBlockLength, cfg.ldpcInfoLength, cfg.ldpcInfoLength/cfg.ldpcBlockLength);
    
    %% Tham số mô phỏng
    cfg.snrRange = 0:2:30;  % Dải SNR (dB) để mô phỏng
    cfg.nMonteCarlo = 50;   % Số lần lặp Monte Carlo cho mỗi mức SNR (để làm mượt đồ thị)
    
    % Đảm bảo nSym đủ lớn cho ít nhất 3-5 khối LDPC
    bitsPerSymOFDM = cfg.nData * cfg.k;
    minLDPCBlocks = 5;  % Số khối LDPC tối thiểu
    minCodedBits = minLDPCBlocks * cfg.ldpcBlockLength;
    minOFDMSyms = ceil(minCodedBits / bitsPerSymOFDM);
    
    % nSym phải là số chẵn (do Alamouti cần cặp symbol)
    if cfg.nSym < minOFDMSyms
        cfg.nSym = ceil(minOFDMSyms / 2) * 2;
        fprintf('Da dieu chinh nSym = %d de phu hop voi LDPC block size\n', cfg.nSym);
    end
    
end
