function [txSig, txGrid, dataBits] = tx_chain(cfg)
    % TX_CHAIN Xử lý chuỗi phát cho hệ thống 2x2 MIMO-OFDM
    %
    % Inputs:
    %   cfg: Structure cấu hình hệ thống
    %
    % Outputs:
    %   txSig: Tín hiệu phát miền thời gian [Samples x nTx]
    %   txGrid: Lưới tài nguyên tần số trước khi IFFT [nFFT x nSym x nTx]
    %   dataBits: Chuỗi bit gốc đã được tạo [nBits x 1]

    %% 1. Tính toán số lượng bit cần thiết
    % Số bit trên mỗi symbol OFDM cho mỗi anten (trước khi STBC)
    % Alamouti mã hóa 2 symbol s1, s2 qua 2 khe thời gian cho 2 anten.
    % Tỷ lệ mã STBC = 1.
    % Số subcarrier dữ liệu * số bit/subcarrier
    bitsPerSymOFDM = cfg.nData * cfg.k; 
    
    % Tổng số bit cần tạo cho toàn bộ quá trình mô phỏng
    % LDPC: số bit thông tin trên mỗi khối = ldpcInfoLength
    infoLen = cfg.ldpcInfoLength;
    
    % Tính số khối LDPC cần thiết để đủ số bit coded cho toàn bộ symbol OFDM
    totalCodedBitsNeeded = bitsPerSymOFDM * cfg.nSym;
    numLDPCBlocks = ceil(totalCodedBitsNeeded / cfg.ldpcBlockLength);
    
    % Tổng số bit thông tin
    totalDataBits = numLDPCBlocks * infoLen;
    
    %% 2. Tạo dữ liệu ngẫu nhiên
    dataBits = randi([0 1], totalDataBits, 1);
    
    %% 3. Mã hóa kênh (LDPC Encoding)
    % Mã hóa từng khối LDPC
    codedBits = zeros(numLDPCBlocks * cfg.ldpcBlockLength, 1);
    for blk = 1:numLDPCBlocks
        startIdx = (blk - 1) * infoLen + 1;
        endIdx = blk * infoLen;
        infoBlock = dataBits(startIdx:endIdx);
        
        % Mã hóa LDPC
        codedBlock = ldpcEncode(infoBlock, cfg.ldpcEncoderCfg);
        
        codedBits((blk-1)*cfg.ldpcBlockLength + 1 : blk*cfg.ldpcBlockLength) = codedBlock;
    end
    
    % Cắt bớt coded bits nếu thừa (để khớp với số symbol OFDM)
    codedBits = codedBits(1:totalCodedBitsNeeded);
    
    %% 4. Điều chế (Modulation) - 16-QAM
    % Chuyển đổi bit thành symbol. Reshape thành các từ mã k-bit
    reshapedBits = reshape(codedBits, cfg.k, []).';
    decData = bi2de(reshapedBits, 'left-msb');
    qamSyms = qammod(decData, cfg.M, 'UnitAveragePower', true);
    
    %% 5. Ánh xạ vào lưới OFDM và STBC (Alamouti)
    % Cần đảm bảo số lượng symbol QAM chia hết cho 2 (cho Alamouti) và chia hết cho nData
    % qamSyms đang là chuỗi 1D stream.
    % Chia thành các khối để vào OFDM
    
    % Số lượng OFDM symbol thực tế (do làm tròn hoặc thiết kế)
    numOFDMSyms = length(qamSyms) / cfg.nData;
    
    % Reshape thành [nData x numOFDMSyms]
    qamGrid = reshape(qamSyms, cfg.nData, numOFDMSyms);
    
    % Chuẩn bị lưới phát cho 2 anten
    % txGrid_ant1 và txGrid_ant2 kích thước [nFFT x numOFDMSyms]
    txGrid = zeros(cfg.nFFT, numOFDMSyms, cfg.nTx);
    
    % Áp dụng Alamouti Coding trên miền tần số (Frequency Domain STBC)
    % Alamouti thường được áp dụng cho cặp symbol liên tiếp trong không gian hoặc thời gian.
    % Ở đây ta áp dụng trên 2 symbol OFDM liên tiếp (Space-Time) hoặc trên các subcarrier.
    % Để đơn giản và phổ biến cho OFDM, ta áp dụng trên 2 khe thời gian (2 symbol OFDM liên tiếp).
    % Giả sử numOFDMSyms là số chẵn.
    
    for i = 1:2:numOFDMSyms
        % Lấy vector dữ liệu cho 2 khe thời gian t và t+1
        % Do cấu trúc Alamouti:
        % Time t:   Ant1 phát s1,      Ant2 phát s2
        % Time t+1: Ant1 phát -s2*,    Ant2 phát s1*
        
        % Tuy nhiên, đây là MIMO-OFDM, "s1" và "s2" ở đây là VECTOR các subcarrier.
        % Ta sẽ thực hiện Alamouti trên từng subcarrier tương ứng của 2 symbol OFDM.
        
        s1 = qamGrid(:, i);     % Symbol OFDM tại t
        s2 = qamGrid(:, i+1);   % Symbol OFDM tại t+1
        
        % Map vào subcarrier data của Anten 1
        txGrid(cfg.dataSubcarriers, i, 1)   = s1;
        txGrid(cfg.dataSubcarriers, i+1, 1) = -conj(s2);
        
        % Map vào subcarrier data của Anten 2
        txGrid(cfg.dataSubcarriers, i, 2)   = s2;
        txGrid(cfg.dataSubcarriers, i+1, 2) = conj(s1);
    end
    
    %% 6. OFDM Modulation (IFFT + CP)
    txSig = zeros((cfg.nFFT + cfg.nCP) * numOFDMSyms, cfg.nTx);
    
    for ant = 1:cfg.nTx
        % Lấy lưới tần số của anten hiện tại
        grid_ant = txGrid(:, :, ant);
        
        % IFFT
        ifft_out = ifft(grid_ant, cfg.nFFT);
        
        % Thêm Cyclic Prefix
        cp_out = [ifft_out(end-cfg.nCP+1:end, :); ifft_out];
        
        % Parallel to Serial
        txSig(:, ant) = cp_out(:);
    end
    
end
