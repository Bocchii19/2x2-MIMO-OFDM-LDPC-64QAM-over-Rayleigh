function [rxSig, h] = channel_model(txSig, cfg, snr, H_ideal)
    % CHANNEL_MODEL Mô hình kênh Rayleigh Fading chọn lọc tần số và AWGN
    %
    % Inputs:
    %   txSig: Tín hiệu phát [Samples x nTx]
    %   cfg: Cấu hình hệ thống
    %   snr: Tỷ số tín hiệu trên nhiễu (dB)
    %   H_ideal: (Tùy chọn) Đáp ứng kênh lý tưởng nếu muốn cố định kênh
    %
    % Outputs:
    %   rxSig: Tín hiệu thu [Samples x nRx]
    %   h: Đáp ứng xung kênh [nRx x nTx x L] (Perfect CSI)
    
    %% 1. Tạo đáp ứng xung kênh Rayleigh (Multipath)
    % Giả sử mô hình kênh đơn giản với L tap (đường) phai
    L = 4; % Số đường đa đường
    
    % Kênh MIMO 2x2 sẽ có 4 đường truyền con: h11, h12, h21, h22
    % Mỗi đường con là một đáp ứng xung chiều dài L.
    
    % Kích thước tín hiệu
    [nSamps, nTx] = size(txSig);
    rxSigNoNoise = zeros(nSamps, cfg.nRx);
    
    % Tạo ma trận kênh h: [nRx x nTx x L]
    % h(r, t, :) là đáp ứng xung từ Tx t đến Rx r
    h = (randn(cfg.nRx, nTx, L) + 1j*randn(cfg.nRx, nTx, L)) / sqrt(2*L);
    % Chuẩn hóa công suất trung bình mỗi đường dẫn về 1/L để tổng công suất = 1
    
    %% 2. Tích chập tín hiệu với kênh (Fading)
    for r = 1:cfg.nRx
        sig_r = zeros(nSamps, 1);
        for t = 1:nTx
            % Lấy đáp ứng xung h_{rt}
            h_rt = squeeze(h(r, t, :));
            
            % Tích chập tín hiệu phát từ anten t với h_{rt}
            % Sử dụng filter để giữ nguyên độ dài
            sig_rt = filter(h_rt, 1, txSig(:, t));
            
            % Cộng dồn tại anten thu
            sig_r = sig_r + sig_rt;
        end
        rxSigNoNoise(:, r) = sig_r;
    end
    
    %% 3. Thêm nhiễu AWGN
    % Tính công suất tín hiệu
    sigPower = mean(abs(rxSigNoNoise(:)).^2);
    
    % Tính công suất nhiễu dựa trên SNR
    % SNR_dB = 10*log10(Ps/Pn) => Pn = Ps / 10^(SNR/10)
    noisePower = sigPower / (10^(snr/10));
    
    % Tạo nhiễu
    noise = sqrt(noisePower/2) * (randn(size(rxSigNoNoise)) + 1j*randn(size(rxSigNoNoise)));
    
    rxSig = rxSigNoNoise + noise;
    
end
