# Tài liệu Lý thuyết: Hệ thống 2x2 MIMO-OFDM

## 1. Tổng quan
Hệ thống được mô phỏng là một liên kết truyền thông không dây băng rộng sử dụng kỹ thuật đa anten (MIMO) kết hợp với ghép kênh phân chia theo tần số trực giao (OFDM). Đây là kiến trúc nền tảng cho các chuẩn WiFi (802.11n/ac/ax) và 4G/5G LTE.

## 2. Các thành phần chính

### 2.1. Mã hóa kênh (Convolutional Coding)
- **Lý do sử dụng**: Kênh truyền vô tuyến chịu ảnh hưởng của nhiễu và fading. Mã hóa giúp sửa lỗi bit tại nơi thu.
- **Cấu hình**: Sử dụng mã chập với tỷ lệ (rate) 1/2, độ dài ràng buộc (constraint length) K=7. Đa thức sinh phổ biến [171 133] (octal) được dùng trong chuẩn WiFi/LTE.
- **Giải mã**: Sử dụng thuật toán Viterbi (Maximum Likelihood Decoding).

### 2.2. Điều chế 16-QAM (Quadrature Amplitude Modulation)
- **Lý do sử dụng**: 16-QAM cho phép truyền 4 bit trên mỗi symbol, tăng hiệu suất phổ so với BPSK/QPSK. Phù hợp với các kênh có SNR trung bình đến cao.
- **Cơ chế**: Dữ liệu được ánh xạ vào mặt phẳng phức với 16 điểm chòm sao.

### 2.3. MIMO 2x2 và Mã hóa Alamouti (STBC)
- **MIMO (Multiple-Input Multiple-Output)**: Sử dụng 2 anten phát và 2 anten thu.
- **Alamouti STBC (Space-Time Block Code)**: Kỹ thuật phân tập phát giúp chống lại fading mà không cần tăng băng thông.
    - Tại khe thời gian $t$: Anten 1 phát $s_1$, Anten 2 phát $s_2$.
    - Tại khe thời gian $t+1$: Anten 1 phát $-s_2^*$, Anten 2 phát $s_1^*$.
- **Ưu điểm**: Cung cấp độ lợi phân tập (diversity gain) bậc 2Tx $\times$ 1Rx (hoặc 2x2 = 4 nếu dùng MRC tại thu), giúp đường cong BER dốc hơn (giảm lỗi nhanh hơn khi tăng SNR).

### 2.4. OFDM (Orthogonal Frequency Division Multiplexing)
- **Lý do sử dụng**: Chống lại fading chọn lọc tần số (Frequency Selective Fading) gây ra do đa đường (multipath).
- **Cơ chế**: Chia băng thông rộng thành nhiều sóng mang con (subcarrier) hẹp phẳng (flat fading).
- **Cyclic Prefix (CP)**: Thêm khoảng bảo vệ để loại bỏ nhiễu ISI (Inter-Symbol Interference).

### 2.5. Mô hình kênh truyền
- **Rayleigh Fading**: Mô phỏng môi trường đô thị không có tầm nhìn thẳng (NLOS), tín hiệu đến từ nhiều hướng phản xạ.
- **AWGN**: Nhiễu nhiệt cộng thêm tại máy thu.

## 3. Quy trình xử lý tín hiệu
1.  **Phát**: Bit sinh ngẫu nhiên $\rightarrow$ Mã hóa Chập $\rightarrow$ Điều chế 16-QAM $\rightarrow$ Mã hóa Alamouti $\rightarrow$ IFFT (OFDM) $\rightarrow$ Thêm CP $\rightarrow$ Kênh.
2.  **Kênh**: Tích chập với đáp ứng xung kim (Multipath) $\rightarrow$ Cộng nhiễu Gaussian.
3.  **Thu**: Loại bỏ CP $\rightarrow$ FFT $\rightarrow$ Cân bằng kênh & Giải mã Alamouti $\rightarrow$ Giải điều chế $\rightarrow$ Giải mã Viterbi $\rightarrow$ So sánh lỗi.

## 4. Phương pháp đánh giá
Để đánh giá hiệu năng của hệ thống, phương pháp chuẩn là **Mô phỏng Monte Carlo**.

### 4.1. Các chỉ số quan trọng
- **BER (Bit Error Rate)**: Tỷ lệ lỗi bit. Đây là chỉ số quan trọng nhất, phản ánh độ tin cậy cuối cùng của hệ thống sau khi giải mã kênh.
- **SER (Symbol Error Rate)**: Tỷ lệ lỗi symbol (trớc khi giải mã bit). Chỉ số này phản ánh hiệu năng thuần túy của bộ điều chế/giải điều chế và cân bằng kênh dưới tác động của nhiễu.
- **SNR (Signal-to-Noise Ratio)**: Tỷ số tín hiệu trên nhiễu, thường tính bằng dB. Trục hoành của đồ thị hiệu năng.

### 4.2. Phân tích kết quả (Đồ thị Waterfall)
- **Hình dạng**: Đồ thị BER theo SNR thường có dạng "thác nước" (waterfall). Khi SNR tăng, BER giảm nhanh.
- **Độ dốc (Diversity Order)**:
    - Trong kênh Rayleigh fading phẳng (SISO), BER giảm tuyến tính theo 1/SNR (độ dốc 1).
    - Với hệ thống MIMO 2x2 sử dụng Alamouti và máy thu MRC, ta đạt được độ lợi phân tập (diversity gain) bậc 4 (2 phát x 2 thu). Điều này làm cho đường BER dốc hơn nhiều (tương đương giảm theo $1/SNR^4$), giúp hệ thống đạt hiệu năng cao hơn đáng kể ở cùng mức SNR.
- **Coding Gain**: Việc sử dụng mã chập (Convolutional Code) cung cấp thêm độ lợi mã hóa, dịch chuyển đường cong lỗi sang trái (cần ít năng lượng hơn để đạt cùng BER).
