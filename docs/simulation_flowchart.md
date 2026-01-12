# Lưu Đồ Thuật Toán Mô Phỏng Hệ Thống 2x2 MIMO-OFDM

Tài liệu này mô tả chi tiết lưu đồ thuật toán của hệ thống mô phỏng 2x2 MIMO-OFDM với Alamouti STBC.

---

## 1. Lưu Đồ Tổng Quan Hệ Thống

```mermaid
flowchart TB
    subgraph INIT["🔧 KHỞI TẠO HỆ THỐNG"]
        A1["Bắt đầu"] --> A2["Khởi tạo<br/>config_params()"]
        A2 --> A3["Thiết lập biến:<br/>BER_results, SER_results"]
    end

    subgraph MAINLOOP["🔄 VÒNG LẶP MÔ PHỎNG CHÍNH"]
        B1{"Duyệt SNR<br/>0:2:20 dB"} --> B2{"Duyệt<br/>Monte Carlo<br/>n = 1:10"}
        B2 --> B3["📡 TRANSMITTER<br/>tx_chain()"]
        B3 --> B4["📶 CHANNEL<br/>channel_model()"]
        B4 --> B5["📥 RECEIVER<br/>rx_chain()"]
        B5 --> B6["Tích lũy BER, SER"]
        B6 --> B2
        B2 -- "Hoàn thành" --> B7["Tính trung bình<br/>BER, SER"]
        B7 --> B1
    end

    subgraph RESULT["📊 KẾT QUẢ"]
        C1["Vẽ đồ thị BER vs SNR"]
        C2["Vẽ đồ thị SER vs SNR"]
        C3["So sánh với lý thuyết"]
        C4["Lưu file PNG"]
        C5["Kết thúc"]
    end

    INIT --> MAINLOOP
    B1 -- "Hoàn thành" --> C1
    C1 --> C2 --> C3 --> C4 --> C5

    style A1 fill:#2ecc71,color:#fff
    style C5 fill:#e74c3c,color:#fff
    style B3 fill:#3498db,color:#fff
    style B4 fill:#9b59b6,color:#fff
    style B5 fill:#e67e22,color:#fff
```

---

## 2. Lưu Đồ Chi Tiết Khối Transmitter (tx_chain.m)

```mermaid
flowchart TB
    subgraph TX["📡 TRANSMITTER CHAIN"]
        direction TB
        
        subgraph DATA["① Tạo Dữ Liệu"]
            T1["Nhận cấu hình cfg"] --> T2["Tính số bit cần thiết:<br/>bitsPerSymOFDM = nData × k<br/>totalCodedBits = bitsPerSymOFDM × nSym<br/>totalDataBits = totalCodedBits × 0.5"]
            T2 --> T3["Tạo bit ngẫu nhiên:<br/>dataBits = randi([0,1], totalDataBits, 1)"]
        end
        
        subgraph ENCODE["② Mã Hóa Kênh"]
            T4["Tạo trellis:<br/>poly2trellis(7, [171 133])"] --> T5["Mã hóa Convolutional:<br/>codedBits = convenc(dataBits, trellis)<br/>Rate = 1/2"]
        end
        
        subgraph MOD["③ Điều Chế 16-QAM"]
            T6["Reshape bit → k-bit words:<br/>reshapedBits = reshape(codedBits, k, []).'"] --> T7["Chuyển Binary → Decimal:<br/>decData = bi2de(reshapedBits, 'left-msb')"]
            T7 --> T8["QAM Modulation:<br/>qamSyms = qammod(decData, 16, 'UnitAveragePower', true)"]
        end
        
        subgraph STBC["④ Alamouti STBC Encoding"]
            T9["Reshape → OFDM grid:<br/>qamGrid[nData × numOFDMSyms]"] --> T10{"Duyệt cặp<br/>symbol OFDM<br/>i = 1:2:numOFDMSyms"}
            T10 --> T11["Lấy s1 = qamGrid(:,i)<br/>Lấy s2 = qamGrid(:,i+1)"]
            T11 --> T12["Anten 1:<br/>Slot t: s1<br/>Slot t+1: -s2*"]
            T11 --> T13["Anten 2:<br/>Slot t: s2<br/>Slot t+1: s1*"]
            T12 --> T14["Map vào txGrid[:,:,1]"]
            T13 --> T15["Map vào txGrid[:,:,2]"]
            T14 --> T10
            T15 --> T10
        end
        
        subgraph OFDM_TX["⑤ OFDM Modulation"]
            T16{"Duyệt anten<br/>ant = 1:2"} --> T17["IFFT:<br/>ifft_out = ifft(grid_ant, nFFT)"]
            T17 --> T18["Thêm Cyclic Prefix:<br/>cp_out = [ifft_out(end-nCP+1:end,:); ifft_out]"]
            T18 --> T19["Parallel → Serial:<br/>txSig(:,ant) = cp_out(:)"]
            T19 --> T16
        end
        
        T3 --> T4
        T5 --> T6
        T8 --> T9
        T10 -- "Hoàn thành" --> T16
        T16 -- "Hoàn thành" --> T20["Output: txSig, txGrid, dataBits"]
    end

    style T1 fill:#3498db,color:#fff
    style T20 fill:#2ecc71,color:#fff
    style T12 fill:#e74c3c,color:#fff
    style T13 fill:#e74c3c,color:#fff
```

### Bảng Ma Trận Alamouti STBC (Space-Time)

| Thời gian | Anten 1 | Anten 2 |
|-----------|---------|---------|
| Slot t    | s₁      | s₂      |
| Slot t+1  | -s₂*    | s₁*     |

---

## 3. Lưu Đồ Chi Tiết Khối Channel (channel_model.m)

```mermaid
flowchart TB
    subgraph CHANNEL["📶 CHANNEL MODEL"]
        direction TB
        
        subgraph FADING["① Rayleigh Multipath Fading"]
            C1["Nhận txSig, cfg, snr"] --> C2["Định nghĩa số tap:<br/>L = 4 đường đa đường"]
            C2 --> C3["Tạo ma trận kênh h[nRx × nTx × L]:<br/>h = (randn + j×randn) / √(2L)"]
        end
        
        subgraph CONV["② Tích Chập Kênh MIMO"]
            C4{"Duyệt Rx<br/>r = 1:2"} --> C5{"Duyệt Tx<br/>t = 1:2"}
            C5 --> C6["Lấy đáp ứng xung:<br/>h_rt = h[r, t, :]"]
            C6 --> C7["Tích chập:<br/>sig_rt = filter(h_rt, 1, txSig[:, t])"]
            C7 --> C8["Cộng dồn:<br/>sig_r = sig_r + sig_rt"]
            C8 --> C5
            C5 -- "Hoàn thành" --> C9["rxSigNoNoise[:,r] = sig_r"]
            C9 --> C4
        end
        
        subgraph AWGN["③ Thêm Nhiễu AWGN"]
            C10["Tính công suất tín hiệu:<br/>sigPower = mean|rxSigNoNoise|²"] --> C11["Tính công suất nhiễu:<br/>noisePower = sigPower / 10^(SNR/10)"]
            C11 --> C12["Tạo nhiễu phức Gaussian:<br/>noise = √(Pn/2) × (randn + j×randn)"]
            C12 --> C13["Cộng nhiễu:<br/>rxSig = rxSigNoNoise + noise"]
        end
        
        C3 --> C4
        C4 -- "Hoàn thành" --> C10
        C13 --> C14["Output: rxSig, h"]
    end

    style C1 fill:#9b59b6,color:#fff
    style C14 fill:#2ecc71,color:#fff
```

### Mô Hình Kênh MIMO 2×2

```mermaid
flowchart LR
    subgraph TX["Transmitter"]
        TX1["Anten Tx₁"]
        TX2["Anten Tx₂"]
    end
    
    subgraph CHAN["Rayleigh Fading Channel"]
        H11["h₁₁"]
        H12["h₁₂"]
        H21["h₂₁"]
        H22["h₂₂"]
    end
    
    subgraph RX["Receiver"]
        RX1["Anten Rx₁"]
        RX2["Anten Rx₂"]
    end
    
    TX1 -.->|"h₁₁"| RX1
    TX1 -.->|"h₂₁"| RX2
    TX2 -.->|"h₁₂"| RX1
    TX2 -.->|"h₂₂"| RX2
    
    style TX1 fill:#e74c3c,color:#fff
    style TX2 fill:#e74c3c,color:#fff
    style RX1 fill:#2ecc71,color:#fff
    style RX2 fill:#2ecc71,color:#fff
```

---

## 4. Lưu Đồ Chi Tiết Khối Receiver (rx_chain.m)

```mermaid
flowchart TB
    subgraph RX["📥 RECEIVER CHAIN"]
        direction TB
        
        subgraph OFDM_RX["① OFDM Demodulation"]
            R1["Nhận rxSig, cfg, h_time, txDataBits"] --> R2{"Duyệt Rx<br/>r = 1:2"}
            R2 --> R3["Serial → Parallel:<br/>reshape(rxSig[:,r], symLen, numOFDMSyms)"]
            R3 --> R4["Loại bỏ CP:<br/>r_no_cp = r_serial[nCP+1:end, :]"]
            R4 --> R5["FFT:<br/>rxGrid[:,:,r] = fft(r_no_cp, nFFT)"]
            R5 --> R2
        end
        
        subgraph CSI["② Ước Lượng Kênh (Perfect CSI)"]
            R6["FFT đáp ứng xung kênh:<br/>h_freq_full = fft(h_time, nFFT, 3)"] --> R7["Trích xuất tại data subcarriers:<br/>h_est_data = h_freq_full[:,:,dataSubcarriers]"]
            R7 --> R8["Permute → [nData × nRx × nTx]:<br/>H₁₁, H₁₂, H₂₁, H₂₂"]
        end
        
        subgraph STBC_DEC["③ Alamouti STBC Decoding"]
            R9{"Duyệt cặp symbol<br/>i = 1:2:numOFDMSyms"} --> R10["Lấy tín hiệu thu:<br/>R₁⁽¹⁾, R₂⁽¹⁾ (Rx1)<br/>R₁⁽²⁾, R₂⁽²⁾ (Rx2)"]
            R10 --> R11["Tính hệ số chuẩn hóa:<br/>norm = |H₁₁|² + |H₁₂|² + |H₂₁|² + |H₂₂|²"]
            R11 --> R12["Alamouti Combining + MRC:<br/>ŝ₁ = (H₁₁*R₁⁽¹⁾ + H₁₂R₂⁽¹⁾* + H₂₁*R₁⁽²⁾ + H₂₂R₂⁽²⁾*) / norm<br/>ŝ₂ = (H₁₂*R₁⁽¹⁾ - H₁₁R₂⁽¹⁾* + H₂₂*R₁⁽²⁾ - H₂₁R₂⁽²⁾*) / norm"]
            R12 --> R13["Lưu estParams_s1, estParams_s2"]
            R13 --> R9
        end
        
        subgraph DEMOD["④ Demodulation"]
            R14["Gộp thành chuỗi symbol:<br/>rxSyms = rxSymsGrid[:]"] --> R15["16-QAM Demodulation:<br/>rxDataInt = qamdemod(rxSyms, 16)"]
            R15 --> R16["Demod → bits:<br/>rxBitsRaw = qamdemod(..., 'OutputType', 'bit')"]
        end
        
        subgraph DECODE["⑤ Giải Mã Kênh"]
            R17["Viterbi Decoding:<br/>trellis = poly2trellis(7, [171 133])<br/>rxBits = vitdec(rxBitsRaw, trellis, 32, 'trunc', 'hard')"]
        end
        
        subgraph ERROR["⑥ Tính Toán Lỗi"]
            R18["So sánh bit:<br/>BER = biterr(txDataBits, rxBits)"] --> R19["So sánh symbol:<br/>SER = symerr(txDataInt, rxDataInt)"]
        end
        
        R2 -- "Hoàn thành" --> R6
        R8 --> R9
        R9 -- "Hoàn thành" --> R14
        R16 --> R17
        R17 --> R18
        R19 --> R20["Output: ber, ser, rxBits"]
    end

    style R1 fill:#e67e22,color:#fff
    style R20 fill:#2ecc71,color:#fff
    style R12 fill:#f39c12,color:#fff
```

### Công Thức Alamouti Combining cho 2×2 MIMO

Với hệ thống 2×2 (2 Tx, 2 Rx), công thức kết hợp Maximal Ratio Combining (MRC):

**Tại Rx₁:**
```
r₁⁽¹⁾ = h₁₁·s₁ + h₁₂·s₂ + n₁⁽¹⁾
r₂⁽¹⁾ = -h₁₁·s₂* + h₁₂·s₁* + n₂⁽¹⁾
```

**Tại Rx₂:**
```
r₁⁽²⁾ = h₂₁·s₁ + h₂₂·s₂ + n₁⁽²⁾
r₂⁽²⁾ = -h₂₁·s₂* + h₂₂·s₁* + n₂⁽²⁾
```

**Kết hợp MRC:**
```
ŝ₁ = (h₁₁*·r₁⁽¹⁾ + h₁₂·r₂⁽¹⁾* + h₂₁*·r₁⁽²⁾ + h₂₂·r₂⁽²⁾*) / Σ|hᵢⱼ|²
ŝ₂ = (h₁₂*·r₁⁽¹⁾ - h₁₁·r₂⁽¹⁾* + h₂₂*·r₁⁽²⁾ - h₂₁·r₂⁽²⁾*) / Σ|hᵢⱼ|²
```

---

## 5. Lưu Đồ Luồng Dữ Liệu End-to-End

```mermaid
flowchart LR
    subgraph SOURCE["Nguồn"]
        A["Data Bits<br/>randi([0,1])"]
    end
    
    subgraph TX_PROC["Xử Lý Phát"]
        B["Convolutional<br/>Encoder<br/>(Rate 1/2)"]
        C["16-QAM<br/>Modulator"]
        D["Alamouti<br/>STBC<br/>Encoder"]
        E["OFDM<br/>Modulator<br/>(IFFT + CP)"]
    end
    
    subgraph CHANNEL["Kênh"]
        F["Rayleigh<br/>Multipath<br/>Fading"]
        G["AWGN<br/>Noise"]
    end
    
    subgraph RX_PROC["Xử Lý Thu"]
        H["OFDM<br/>Demodulator<br/>(Remove CP + FFT)"]
        I["Channel<br/>Estimation<br/>(Perfect CSI)"]
        J["Alamouti<br/>Combiner<br/>+ MRC"]
        K["16-QAM<br/>Demodulator"]
        L["Viterbi<br/>Decoder"]
    end
    
    subgraph SINK["Đích"]
        M["Recovered<br/>Data Bits"]
    end
    
    A --> B --> C --> D --> E
    E -->|"Tx₁"| F
    E -->|"Tx₂"| F
    F --> G
    G -->|"Rx₁"| H
    G -->|"Rx₂"| H
    H --> I --> J --> K --> L --> M
    
    style A fill:#27ae60,color:#fff
    style M fill:#27ae60,color:#fff
    style F fill:#9b59b6,color:#fff
    style G fill:#e74c3c,color:#fff
```

---

## 6. Tham Số Hệ Thống (config_params.m)

| Tham số | Giá trị | Mô tả |
|---------|---------|-------|
| **nTx** | 2 | Số anten phát |
| **nRx** | 2 | Số anten thu |
| **M** | 16 | Bậc điều chế (16-QAM) |
| **k** | 4 | Số bit/symbol |
| **nFFT** | 64 | Kích thước FFT |
| **nCP** | 16 | Độ dài Cyclic Prefix |
| **nData** | 52 | Số subcarrier dữ liệu |
| **nSym** | 100 | Số symbol OFDM/vòng lặp |
| **constraintLength** | 7 | Độ dài ràng buộc mã chập |
| **codeGenerator** | [171 133] | Đa thức sinh (Octal) |
| **snrRange** | 0:2:20 | Dải SNR mô phỏng (dB) |
| **nMonteCarlo** | 10 | Số lần lặp Monte Carlo |

---

## 7. Lưu Đồ Tính Toán Số Lượng Dữ Liệu

```mermaid
flowchart TD
    A["nData = 52 subcarriers"] --> B["bitsPerSymOFDM = nData × k<br/>= 52 × 4 = 208 bits"]
    B --> C["totalCodedBits = bitsPerSymOFDM × nSym<br/>= 208 × 100 = 20,800 bits"]
    C --> D["totalDataBits = totalCodedBits × 0.5<br/>= 10,400 bits<br/>(do Rate 1/2)"]
    
    D --> E["Số symbol QAM = totalCodedBits / k<br/>= 20,800 / 4 = 5,200 symbols"]
    E --> F["Số symbol OFDM = 5,200 / 52 = 100"]
    
    style A fill:#3498db,color:#fff
    style F fill:#2ecc71,color:#fff
```

---

## 8. Tóm Tắt Quy Trình Monte Carlo

```mermaid
flowchart TB
    subgraph MC["Phương Pháp Monte Carlo"]
        M1["Khởi tạo BER = 0, SER = 0"] --> M2{"Vòng lặp<br/>iMC = 1:10"}
        M2 --> M3["Chạy mô phỏng 1 lần"]
        M3 --> M4["Tích lũy:<br/>ber_mc += ber<br/>ser_mc += ser"]
        M4 --> M2
        M2 -- "Hoàn thành" --> M5["Lấy trung bình:<br/>BER_avg = ber_mc / 10<br/>SER_avg = ser_mc / 10"]
        M5 --> M6["Kết quả mượt hơn<br/>& đáng tin cậy hơn"]
    end
    
    style M1 fill:#f39c12,color:#fff
    style M6 fill:#27ae60,color:#fff
```

---

> **Lưu ý:** Các lưu đồ trên mô tả chi tiết thuật toán mô phỏng hệ thống 2×2 MIMO-OFDM với Alamouti STBC. Để hiểu sâu hơn về lý thuyết, vui lòng tham khảo [Theory.md](./Theory.md).
