function [ber, ser, rxBits] = rx_chain(rxSig, cfg, h_time, txDataBits)
    % RX_CHAIN Xử lý chuỗi thu cho hệ thống 2x2 MIMO-OFDM
    %
    % Inputs:
    %   rxSig: Tín hiệu thu [Samples x nRx]
    %   cfg: Cấu hình hệ thống
    %   h_time: Đáp ứng xung kênh [nRx x nTx x L] (Perfect CSI)
    %   txDataBits: (Optional) Chuỗi bit phát để tính BER ngay (nếu cần)
    %
    % Outputs:
    %   ber: Tỷ lệ lỗi bit
    %   ser: Tỷ lệ lỗi symbol
    %   rxBits: Chuỗi bit sau giải mã
    
    %% 1. OFDM Demodulation
    % rxSig đang ở dạng Serial. Cần đưa về Parallel.
    % Kích thước mong đợi sau khi reshape: [(nFFT+nCP) x numOFDMSyms]
    
    [totalSamples, nRx] = size(rxSig);
    symLen = cfg.nFFT + cfg.nCP;
    numOFDMSyms = totalSamples / symLen;
    
    rxGrid = zeros(cfg.nFFT, numOFDMSyms, nRx);
    
    for r = 1:nRx
        % Serial to Parallel
        r_serial = reshape(rxSig(:, r), symLen, numOFDMSyms);
        
        % Remove CP
        r_no_cp = r_serial(cfg.nCP+1:end, :);
        
        % FFT
        rxGrid(:, :, r) = fft(r_no_cp, cfg.nFFT);
    end
    
    %% 2. Tính toán H Frequency Response (Perfect CSI)
    % h_time: [nRx x nTx x L]
    % Cần h_freq chuẩn với kích thước [nData x nTx x nRx] hoặc tương đương để cân bằng.
    % Ta sẽ tính FFT của h_time.
    
    % FFT của đáp ứng xung kênh theo chiều dài nFFT
    % Kết quả h_freq_full: [nRx x nTx x nFFT]
    h_freq_full = fft(h_time, cfg.nFFT, 3);
    
    % Trích xuất tại các subcarrier dữ liệu
    % h_est: [nData x numOFDMSyms x nRx x nTx]
    % Kênh được giả sử không đổi trong suốt gói (block fading) hoặc đổi theo từng symbol?
    % Trong channel_model, ta dùng filter nghĩa là kênh tĩnh trong suốt quá trình truyền 1 packet (quasi-static)
    % hoặc nếu kênh thay đổi thì phải generate h cho từng block. 
    % Với mô hình channel_model hiện tại (filter 1 lần), kênh là Quasi-Static (không đổi trong 1 lần gọi hàm).
    
    % Lấy H tại các data subcarriers: [nRx x nTx x nData]
    h_est_data = h_freq_full(:, :, cfg.dataSubcarriers);
    
    % Reshape để dễ xử lý trong STBC Combining: [nData x nRx x nTx]
    h_est_data = permute(h_est_data, [3, 1, 2]);
    
    %% 3. STBC Decoding (Alamouti Combining) & Equalization
    % Cần giải mã từng cặp symbol OFDM (t, t+1)
    
    % Output của bộ combine: ước lượng symbol phát tại các subcarrier
    % Kích thước: [nData x numOFDMSyms] (nhưng gộp lại 1 stream)
    estParams_s1 = zeros(cfg.nData, numOFDMSyms/2);
    estParams_s2 = zeros(cfg.nData, numOFDMSyms/2);
    
    % Duyệt qua từng cặp symbol thời gian
    for i = 1:2:numOFDMSyms
        idx = (i+1)/2;
        
        % Tín hiệu thu tại subcarrier k, thời điểm t và t+1
        % r1: [nData x nRx] tại t
        % r2: [nData x nRx] tại t+1
        r1 = squeeze(rxGrid(cfg.dataSubcarriers, i, :)); 
        r2 = squeeze(rxGrid(cfg.dataSubcarriers, i+1, :));
        
        % Kênh H tại subcarrier k (giả sử không đổi trong 2 symbol này)
        % H: [nData x nRx x nTx]. H(:, j, i) là h_ji (từ Tx i đến Rx j)
        % Note: h_est_data indices are (k, rx, tx)
        
        % Alamouti Combining Formula cho 2x2:
        % s1_hat = h11*r1 + h12*r1 + h21*r1... wait, formula is simpler per Rx antenna then combined.
        % Standard Alamouti 2x1 
        % r1 = h1 s1 + h2 s2 + n1
        % r2 = -h1 s2* + h2 s1* + n2
        % => s1_hat = h1* r1 + h2 r2*
        % => s2_hat = h2* r1 - h1 r2*
        
        % For 2x2 (2 Rx antennas), we do Maximal Ratio Combining (MRC) of the estimates from each Rx antenna.
        % s1_hat_total = s1_hat_rx1 + s1_hat_rx2
        % s2_hat_total = s2_hat_rx1 + s2_hat_rx2
        
        % Loop over subcarriers is slow in MATLAB, try vectorization.
        % H11 = h_est_data(:, 1, 1); % Rx1, Tx1
        % H12 = h_est_data(:, 1, 2); % Rx1, Tx2
        % H21 = h_est_data(:, 2, 1); % Rx2, Tx1
        % H22 = h_est_data(:, 2, 2); % Rx2, Tx2
        
        H11 = h_est_data(:, 1, 1); 
        H12 = h_est_data(:, 1, 2);
        H21 = h_est_data(:, 2, 1);
        H22 = h_est_data(:, 2, 2);
        
        R1_1 = r1(:, 1); % Rx1, time t
        R2_1 = r2(:, 1); % Rx1, time t+1
        R1_2 = r1(:, 2); % Rx2, time t
        R2_2 = r2(:, 2); % Rx2, time t+1
        
        % Combining cho Rx1
        % s1_tik_1 = conj(H11).*R1_1 + H12.*conj(R2_1);
        % s2_tik_1 = conj(H12).*R1_1 - H11.*conj(R2_1);
        
        % Combining cho Rx2
        % s1_tik_2 = conj(H21).*R1_2 + H22.*conj(R2_2);
        % s2_tik_2 = conj(H22).*R1_2 - H21.*conj(R2_2);
        
        % Tổng hợp (MRC)
        % Mẫu số chuẩn hóa: sum(|h_ij|^2)
        norm_factor = abs(H11).^2 + abs(H12).^2 + abs(H21).^2 + abs(H22).^2;
        
        s1_hat = (conj(H11).*R1_1 + H12.*conj(R2_1) + conj(H21).*R1_2 + H22.*conj(R2_2)) ./ norm_factor;
        s2_hat = (conj(H12).*R1_1 - H11.*conj(R2_1) + conj(H22).*R1_2 - H21.*conj(R2_2)) ./ norm_factor;
        
        estParams_s1(:, idx) = s1_hat;
        estParams_s2(:, idx) = s2_hat;
    end
    
    % Gom lại thành 1 chuỗi symbol
    % estParams: [nData x numOFDMSyms]
    rxSymsGrid = zeros(cfg.nData, numOFDMSyms);
    rxSymsGrid(:, 1:2:end) = estParams_s1;
    rxSymsGrid(:, 2:2:end) = estParams_s2;
    
    rxSyms = rxSymsGrid(:);
    
    %% 4. Demodulation và SER Calculation
    % Hard decision cho SER
    rxDataInt = qamdemod(rxSyms, cfg.M, 'UnitAveragePower', true);
    
    % Tính số lượng symbol phát đi từ txDataBits để so sánh SER chính xác?
    % Nhưng ở đây ta chưa có symbol phát gốc dạng số nguyên (bi2de đã làm ở tx).
    % Để tính SER chính xác, ta cần txSyms gốc. Nhưng input chỉ có txDataBits.
    % Ta tính tạm BER trước.
    
    %% 5. Giải mã kênh (LDPC Decoding với Soft-Decision)
    % Tính LLR (Log-Likelihood Ratio) từ symbol thu để có soft-decision tốt hơn
    % Sử dụng qamdemod với 'OutputType', 'approxllr' cho soft-decision
    
    % Cần ước lượng noise variance cho LLR calculation
    % Giả sử noise variance được ước lượng từ SNR (nếu biết) hoặc dùng giá trị mặc định
    noiseVar = var(rxSyms - qammod(qamdemod(rxSyms, cfg.M, 'UnitAveragePower', true), cfg.M, 'UnitAveragePower', true));
    if noiseVar < 1e-10
        noiseVar = 0.01; % Tránh chia cho 0
    end
    
    % Tính LLR cho các bit
    rxLLR = qamdemod(rxSyms, cfg.M, 'UnitAveragePower', true, 'OutputType', 'approxllr', 'NoiseVariance', noiseVar);
    rxLLR = rxLLR(:);
    
    % LDPC Decoding
    % Tính số khối LDPC
    infoLen = cfg.ldpcInfoLength;
    numLDPCBlocks = floor(length(rxLLR) / cfg.ldpcBlockLength);
    
    % Kiểm tra số khối LDPC có hợp lệ không
    if numLDPCBlocks == 0
        warning('Khong du du lieu de giai ma LDPC! rxLLR=%d, blockLen=%d', length(rxLLR), cfg.ldpcBlockLength);
        % Fallback: giải mã hard-decision không qua LDPC
        rxBits = double(rxLLR < 0);  % LLR < 0 => bit 1
        rxBits = rxBits(1:min(length(rxBits), length(txDataBits)));
    else
        % Giải mã từng khối LDPC
        rxBits = zeros(numLDPCBlocks * infoLen, 1);
        for blk = 1:numLDPCBlocks
            startIdx = (blk - 1) * cfg.ldpcBlockLength + 1;
            endIdx = blk * cfg.ldpcBlockLength;
            llrBlock = rxLLR(startIdx:endIdx);
            
            % Giải mã LDPC sử dụng belief propagation
            % Lưu ý: LDPC decoder trong MATLAB cần LLR với convention: +LLR -> bit 0, -LLR -> bit 1
            decodedBlock = ldpcDecode(llrBlock, cfg.ldpcDecoderCfg, cfg.ldpcMaxIterations);
            
            rxBits((blk-1)*infoLen + 1 : blk*infoLen) = decodedBlock(1:infoLen);
        end
    end
    
    %% 6. Tính toán Lỗi
    if nargin > 3
        % Cần đảm bảo độ dài khớp nhau (cắt bớt phần dư nếu có)
        n = min(length(txDataBits), length(rxBits));
        
        if n == 0
            warning('Khong co du lieu de tinh BER!');
            ber = 1;  % Worst case
            ser = 1;
        else
            [~, ber] = biterr(txDataBits(1:n), rxBits(1:n));
            
            % Tính SER (tương đối từ rxDataInt vs tái tạo từ txDataBits)
            % Tái tạo txSymsINT từ txDataBits qua LDPC encoding
            infoLen = cfg.ldpcInfoLength;
            numLDPCBlocksTx = floor(length(txDataBits) / infoLen);
            
            if numLDPCBlocksTx > 0
                % Mã hóa lại để lấy coded bits
                txCodedBits = zeros(numLDPCBlocksTx * cfg.ldpcBlockLength, 1);
                for blk = 1:numLDPCBlocksTx
                    startIdx = (blk - 1) * infoLen + 1;
                    endIdx = blk * infoLen;
                    infoBlock = txDataBits(startIdx:endIdx);
                    codedBlock = ldpcEncode(infoBlock, cfg.ldpcEncoderCfg);
                    txCodedBits((blk-1)*cfg.ldpcBlockLength + 1 : blk*cfg.ldpcBlockLength) = codedBlock;
                end
                
                % Cắt bớt để khớp với số symbol
                numSyms = floor(length(txCodedBits) / cfg.k);
                if numSyms > 0
                    txCodedBits = txCodedBits(1:numSyms*cfg.k);
                    
                    txBitsReshaped = reshape(txCodedBits, cfg.k, []).';
                    txDataInt = bi2de(txBitsReshaped, 'left-msb');
                    
                    % Cần cắt bớt rxDataInt cho khớp length
                    k_sym = min(length(txDataInt), length(rxDataInt));
                    if k_sym > 0
                        [~, ser] = symerr(txDataInt(1:k_sym), rxDataInt(1:k_sym));
                    else
                        ser = 1;
                    end
                else
                    ser = 1;
                end
            else
                ser = 1;
            end
        end
    else
        ber = -1;
        ser = -1;
    end

end
