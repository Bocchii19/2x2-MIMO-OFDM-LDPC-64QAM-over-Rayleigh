# Dự án Mô phỏng 2x2 MIMO-OFDM

Dự án này mô phỏng hệ thống truyền thông không dây sử dụng kỹ thuật MIMO 2x2 kết hợp OFDM, mã hóa Alamouti và điều chế 16-QAM trên kênh truyền Rayleigh fading.

## Cơ cấu thư mục
- `main_sim.m`: Script chính để chạy mô phỏng.
- `config_params.m`: File cấu hình các tham số hệ thống.
- `src/`: Thư mục chứa mã nguồn các khối chức năng (Tx, Rx, Channel).
- `docs/`: Tài liệu lý thuyết.

## Hướng dẫn sử dụng
1.  Mở MATLAB.
2.  Chuyển thư mục làm việc (Current Folder) về thư mục chứa dự án này (`d:\Code\2x2MIMO-OFDM`).
3.  Mở file `main_sim.m`.
4.  Nhấn nút **Run** (hoặc gõ `main_sim` trong Command Window).
5.  Chương trình sẽ chạy mô phỏng qua các mức SNR từ 0 đến 20dB (mặc định).
6.  Kết quả BER và SER sẽ được hiển thị trên Command Window và vẽ đồ thị sau khi hoàn tất.

## Yêu cầu hệ thống
- MATLAB (khuyến nghị phiên bản R2020a trở lên).
- Communications Toolbox (cần thiết cho các hàm `qammod`, `convenc`, `vitdec`).
- Signal Processing Toolbox (cần thiết cho hàm `biterr` nếu phiên bản cũ, nhưng thường có sẵn).

## Tùy chỉnh
Bạn có thể thay đổi các tham số trong file `config_params.m`:
- `cfg.nMonteCarlo`: Tăng lên (ví dụ 100 hoặc 1000) để đồ thị mượt hơn (nhưng chạy lâu hơn).
- `cfg.snrRange`: Thay đổi dải SNR muốn khảo sát.
