% MAIN_SIM Script chính mô phỏng hệ thống 2x2 MIMO-OFDM
% Sử dụng Space-Time Block Coding (Alamouti) và kỹ thuật OFDM.
% Mã hóa kênh: LDPC (Low-Density Parity-Check) rate 1/2
% Kênh truyền: Rayleigh Fading + AWGN
% Modulation: 64-QAM

clc;
clear;
close all;

% Thêm đường dẫn tới thư mục src
addpath('src');

%% 1. Khởi tạo
fprintf('Khoi tao he thong MIMO-OFDM...\n');
cfg = config_params();

% In thông tin cấu hình
fprintf('\n=== CAU HINH HE THONG ===\n');
fprintf('MIMO: %dx%d\n', cfg.nTx, cfg.nRx);
fprintf('Modulation: %d-QAM\n', cfg.M);
fprintf('OFDM: nFFT=%d, nCP=%d, nData=%d, nSym=%d\n', cfg.nFFT, cfg.nCP, cfg.nData, cfg.nSym);
fprintf('LDPC: BlockLen=%d, InfoLen=%d, Rate=%.2f, MaxIter=%d\n', ...
    cfg.ldpcBlockLength, cfg.ldpcInfoLength, cfg.ldpcInfoLength/cfg.ldpcBlockLength, cfg.ldpcMaxIterations);
fprintf('========================\n\n');

% Các biến lưu kết quả
BER_results = zeros(length(cfg.snrRange), 1);
SER_results = zeros(length(cfg.snrRange), 1);

%% 2. Vòng lặp Mô phỏng
for iSnr = 1:length(cfg.snrRange)
    snr = cfg.snrRange(iSnr);
    fprintf('Dang mo phong SNR = %d dB... ', snr);
    
    ber_mc = 0;
    ser_mc = 0;
    
    for iMC = 1:cfg.nMonteCarlo
        % --- A. TRANSMITTER ---
        [txSig, ~, dataBits] = tx_chain(cfg);
        
        % --- B. CHANNEL ---
        % Trả về tín hiệu thu và đáp ứng kênh (cho Perfect CSI)
        [rxSig, h_time] = channel_model(txSig, cfg, snr);
        
        % --- C. RECEIVER ---
        [ber, ser, ~] = rx_chain(rxSig, cfg, h_time, dataBits);
        
        ber_mc = ber_mc + ber;
        ser_mc = ser_mc + ser;
    end
    
    % Lấy trung bình
    BER_results(iSnr) = ber_mc / cfg.nMonteCarlo;
    SER_results(iSnr) = ser_mc / cfg.nMonteCarlo;
    
    fprintf('BER = %.4e, SER = %.4e\n', BER_results(iSnr), SER_results(iSnr));
end

%% 3. Vẽ đồ thị
fprintf('Ve do thi ket qua...\n');

% Tính toán đường lý thuyết (Theoretical Curves)
% Chuyển đổi SNR (Es/N0) sang Eb/N0
% SNR = Es/N0 = k * Eb/N0 => Eb/N0_dB = SNR_dB - 10*log10(cfg.k);
EbNo_dB = cfg.snrRange - 10*log10(cfg.k);

% Lý thuyết Bit Error Rate (BER) 16-QAM trên kênh Rayleigh 2x2
theory_BER_Rayleigh_2x2 = berfading(EbNo_dB, 'qam', cfg.M, 2*cfg.nRx); 

% Lý thuyết Symbol Error Rate (SER) 16-QAM trên kênh Rayleigh 2x2
% Lưu ý: berfading trả về BER. Ta cần dùng hàm tính SER nếu có hoặc xấp xỉ.
% Tuy nhiên, trong MATLAB Communications Toolbox không có hàm 'serfading'.
% Nhưng ta có thể dùng công thức xấp xỉ từ BER: SER ~ k * BER (với Gray coding và high SNR)
% Hoặc chính xác hơn: hàm berfading có tùy chọn không? Không.
% Cách tốt nhất: Dùng công thức giải tích cho M-QAM MRC Diversity.
% Để đơn giản và nhanh trong MATLAB: SER xấp xỉ k * BER (với M=16, k=4)
% Hoặc dùng một cách tiếp cận khác: tính Ps (Symbol error prob) từ Pb (Bit error prob)
% Với Gray code: Pb ~ Ps / k => Ps ~ k * Pb.
theory_SER_Rayleigh_2x2 = theory_BER_Rayleigh_2x2 * cfg.k;

% Lưu ý: Công thức SER ~ k*BER chỉ đúng ở SNR cao. Ở SNR thấp sai số lớn.
% Tuy nhiên để vẽ tham khảo thì chấp nhận được.

% --- FIGURE 1: BER ---
figure(1);
semilogy(cfg.snrRange, BER_results, '-bo', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'Simulated BER (2x2 MIMO-OFDM + LDPC)');
hold on;
semilogy(cfg.snrRange, theory_BER_Rayleigh_2x2, '--m', 'LineWidth', 1.5, 'DisplayName', 'Theory BER Rayleigh 2x2 (Uncoded)');
grid on;
xlabel('SNR (dB)');
ylabel('Bit Error Rate (BER)');
title(sprintf('BER Performance: 2x2 MIMO-OFDM with LDPC Coding'));
legend('show', 'Location', 'southwest');
ylim([1e-5 1]);
saveas(gcf, 'BER_results.png');

% --- FIGURE 2: SER ---
figure(2);
semilogy(cfg.snrRange, SER_results, '-rs', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'Simulated SER (2x2 MIMO-OFDM + LDPC)');
hold on;
semilogy(cfg.snrRange, theory_SER_Rayleigh_2x2, '--k', 'LineWidth', 1.5, 'DisplayName', 'Theory SER Rayleigh 2x2 (Uncoded)');
grid on;
xlabel('SNR (dB)');
ylabel('Symbol Error Rate (SER)');
title(sprintf('SER Performance: 2x2 MIMO-OFDM with LDPC Coding'));
legend('show', 'Location', 'southwest');
ylim([1e-5 1]);
saveas(gcf, 'SER_results.png');

% --- FIGURE 3: BER và SER trên cùng 1 đồ thị ---
figure(3);
set(gcf, 'Position', [100, 100, 900, 600]);  % Kích thước lớn hơn

% Vẽ BER
semilogy(cfg.snrRange, BER_results, '-bo', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'DisplayName', 'Simulated BER (LDPC)');
hold on;
semilogy(cfg.snrRange, theory_BER_Rayleigh_2x2, '--b', 'LineWidth', 1.5, 'DisplayName', 'Theory BER (Uncoded)');

% Vẽ SER
semilogy(cfg.snrRange, SER_results, '-rs', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'DisplayName', 'Simulated SER (LDPC)');
semilogy(cfg.snrRange, theory_SER_Rayleigh_2x2, '--r', 'LineWidth', 1.5, 'DisplayName', 'Theory SER (Uncoded)');

grid on;
xlabel('SNR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Error Rate', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('BER & SER Performance: 2x2 MIMO-OFDM with LDPC Coding\n%d-QAM, Rayleigh Fading Channel', cfg.M), 'FontSize', 14);
legend('show', 'Location', 'southwest', 'FontSize', 10);
ylim([1e-5 1]);
xlim([min(cfg.snrRange) max(cfg.snrRange)]);

% Thêm annotation
text(max(cfg.snrRange)-5, 1e-1, sprintf('LDPC Rate: %.1f', cfg.ldpcInfoLength/cfg.ldpcBlockLength), 'FontSize', 10, 'BackgroundColor', 'white');
text(max(cfg.snrRange)-5, 3e-2, sprintf('Block: %d bits', cfg.ldpcBlockLength), 'FontSize', 10, 'BackgroundColor', 'white');

saveas(gcf, 'BER_SER_comparison.png');

fprintf('Da hoan thanh! Ket qua luu tai:\n');
fprintf('  - BER_results.png\n');
fprintf('  - SER_results.png\n');
fprintf('  - BER_SER_comparison.png\n');
