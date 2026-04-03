# HTTP/3 規範研究報告

## 目錄

1. [概述](#1-概述)
2. [相關 RFC 文件](#2-相關-rfc-文件)
3. [QUIC 傳輸協定 (RFC 9000)](#3-quic-傳輸協定-rfc-9000)
4. [HTTP/3 協定 (RFC 9114)](#4-http3-協定-rfc-9114)
5. [QPACK 標頭壓縮 (RFC 9204)](#5-qpack-標頭壓縮-rfc-9204)
6. [HTTP/3 vs HTTP/2 比較](#6-http3-vs-http2-比較)
7. [實作函式庫](#7-實作函式庫)
8. [結論與建議](#8-結論與建議)

---

## 1. 概述

HTTP/3 是超文本傳輸協定 (HTTP) 的第三個主要版本，由 IETF 於 2022 年 6 月發布為 RFC 9114。其最大的架構變革是**將底層傳輸協定從 TCP 改為 QUIC**（基於 UDP 的多工安全傳輸協定）。

### 核心動機

- **消除隊頭阻塞 (Head-of-Line Blocking)**：HTTP/2 雖在應用層實現了多工，但底層 TCP 的封包遺失會阻塞所有串流。QUIC 在傳輸層原生支援多工，封包遺失只影響對應的串流。
- **降低連線建立延遲**：QUIC 將 TLS 1.3 握手整合進傳輸層握手，只需 1-RTT（甚至 0-RTT）即可建立安全連線。
- **支援連線遷移**：透過 Connection ID 機制，連線可在網路路徑變更（如 Wi-Fi 切換到行動網路）時無縫遷移。

---

## 2. 相關 RFC 文件

| RFC | 名稱 | 說明 |
|-----|------|------|
| [RFC 9000](https://datatracker.ietf.org/doc/html/rfc9000) | QUIC: A UDP-Based Multiplexed and Secure Transport | QUIC 傳輸協定核心規範 |
| [RFC 9001](https://datatracker.ietf.org/doc/html/rfc9001) | Using TLS to Secure QUIC | QUIC 的 TLS 1.3 整合 |
| [RFC 9002](https://datatracker.ietf.org/doc/html/rfc9002) | QUIC Loss Detection and Congestion Control | QUIC 封包遺失偵測與壅塞控制 |
| [RFC 9114](https://datatracker.ietf.org/doc/html/rfc9114) | HTTP/3 | HTTP/3 核心規範 |
| [RFC 9204](https://datatracker.ietf.org/doc/html/rfc9204) | QPACK: Field Compression for HTTP/3 | HTTP/3 標頭欄位壓縮 |
| [RFC 9369](https://datatracker.ietf.org/doc/html/rfc9369) | QUIC Version 2 | QUIC 版本 2 |

---

## 3. QUIC 傳輸協定 (RFC 9000)

### 3.1 協定架構

```
+---------------------+
|     Application     |
|      (HTTP/3)       |
+---------------------+
|        QUIC         |
|  (Streams, Crypto,  |
|   Flow Control)     |
+---------------------+
|      UDP            |
+---------------------+
|      IP             |
+---------------------+
```

QUIC 建立在 UDP 之上，在使用者空間實現壅塞控制，並原生整合 TLS 1.3 作為加密層。

### 3.2 連線建立

#### 1-RTT 握手（首次連線）

```
Client                                    Server

Initial[0]: CRYPTO[CH] --------->
                                 Initial[0]: CRYPTO[SH] CRYPTO[EE, CERT, CV, FIN]
                          <--------- Handshake[0]: CRYPTO[FIN]
Handshake[0]: CRYPTO[FIN] --------->

[此時連線已建立，可開始傳送應用資料]
```

- 客戶端發送 Initial 封包，包含 TLS ClientHello
- 伺服器回傳 Initial + Handshake 封包，包含 ServerHello、加密擴展、憑證等
- **只需 1 次往返即可建立安全連線**（TCP + TLS 1.3 需要 2-3 次往返）

#### 0-RTT 握手（後續連線）

- 客戶端使用先前連線的 Pre-Shared Key (PSK) 在首次封包中即附帶應用資料
- 伺服器可立即處理 0-RTT 資料
- **注意：0-RTT 無法防禦重放攻擊 (Replay Attack)**，僅適用於冪等操作

### 3.3 串流 (Streams)

QUIC 串流是有序的位元組串流抽象，提供以下特性：

#### 串流類型

| 類型 | Stream ID 最低 2 位元 | 說明 |
|------|----------------------|------|
| 客戶端發起的雙向串流 | 0x00 | 用於 HTTP 請求/回應 |
| 伺服器發起的雙向串流 | 0x01 | 保留 |
| 客戶端發起的單向串流 | 0x02 | 用於控制串流、QPACK 等 |
| 伺服器發起的單向串流 | 0x03 | 用於控制串流、推送等 |

#### 串流狀態

- **Send States**: Ready → Send → Data Sent → Data Recvd / Reset Sent → Reset Recvd
- **Receive States**: Recv → Size Known → Data Recvd → Data Read / Reset Recvd → Reset Read

#### 關鍵特性

- 每個串流獨立進行流量控制和重傳
- 串流之間互不阻塞（解決 TCP 隊頭阻塞問題）
- 串流可被任一端點取消，不影響其他串流

### 3.4 流量控制

QUIC 提供兩層流量控制：

1. **串流層級 (Stream-level)**：限制單一串流可緩衝的資料量
2. **連線層級 (Connection-level)**：限制所有串流合計可緩衝的資料量

透過 `MAX_STREAM_DATA` 和 `MAX_DATA` 幀通知對端可用的緩衝空間。

### 3.5 封包遺失偵測與壅塞控制 (RFC 9002)

- 使用基於確認 (ACK) 的遺失偵測
- 預設壅塞控制演算法類似 TCP NewReno
- 支援 Probe Timeout (PTO) 取代 TCP 的 RTO
- 實作可自由選擇壅塞控制演算法（如 CUBIC、BBR）

### 3.6 連線遷移

- 每個連線有一個或多個 **Connection ID**
- Connection ID 由對端分配，不與特定網路路徑綁定
- 當端點從新的本地位址發送非探測幀 (non-probing frame) 時觸發遷移
- 遷移後需進行路徑驗證 (PATH_CHALLENGE / PATH_RESPONSE)
- 探測幀包括：PATH_CHALLENGE、PATH_RESPONSE、NEW_CONNECTION_ID、PADDING

---

## 4. HTTP/3 協定 (RFC 9114)

### 4.1 串流對應 (Stream Mapping)

HTTP/3 將 HTTP 語意對應到 QUIC 串流：

#### 雙向串流 (Bidirectional Streams)

- **請求串流 (Request Streams)**：客戶端發起的雙向串流，承載 HTTP 請求/回應對

#### 單向串流 (Unidirectional Streams)

| 串流類型 | Type Value | 說明 |
|----------|------------|------|
| 控制串流 (Control Stream) | 0x00 | 每個端點各一條，承載連線層級設定與控制幀 |
| 推送串流 (Push Stream) | 0x01 | 伺服器發起，承載推送的回應 |
| QPACK 編碼器串流 | 0x02 | 傳送動態表更新指令 |
| QPACK 解碼器串流 | 0x03 | 傳送動態表確認指令 |

### 4.2 幀類型 (Frame Types)

HTTP/3 幀的通用格式：

```
HTTP/3 Frame Format {
  Type (i),        // 可變長度整數
  Length (i),      // 可變長度整數
  Frame Payload (..)
}
```

#### 幀類型列表

| 幀類型 | Type Value | 可用串流 | 說明 |
|--------|------------|----------|------|
| DATA | 0x00 | Request, Push | 承載 HTTP 訊息主體 |
| HEADERS | 0x01 | Request, Push | 承載 QPACK 編碼的標頭欄位 |
| CANCEL_PUSH | 0x03 | Control | 取消伺服器推送 |
| SETTINGS | 0x04 | Control | 連線參數設定 |
| PUSH_PROMISE | 0x05 | Request | 伺服器推送承諾 |
| GOAWAY | 0x07 | Control | 優雅關閉連線 |
| MAX_PUSH_ID | 0x0d | Control | 控制伺服器推送 ID 上限 |

#### 與 HTTP/2 的差異

以下 HTTP/2 幀在 HTTP/3 中**不存在**，因為 QUIC 已在傳輸層處理：

- **PRIORITY**：QUIC 處理優先序
- **RST_STREAM**：QUIC 串流取消
- **PING**：QUIC 保活機制
- **WINDOW_UPDATE**：QUIC 流量控制
- **CONTINUATION**：HTTP/3 HEADERS 幀不受大小限制

### 4.3 請求/回應生命週期

```
Client                                    Server

[開啟新的雙向串流 (Stream ID = N)]

HEADERS (請求標頭) --------->
DATA (請求主體, 可選) --------->
                          <--------- HEADERS (回應標頭)
                          <--------- DATA (回應主體)
                          <--------- HEADERS (trailers, 可選)

[串流關閉]
```

1. 客戶端在新的雙向串流上發送 HEADERS 幀（包含請求方法、路徑等）
2. 可選地發送 DATA 幀（請求主體）
3. 伺服器在同一串流上回傳 HEADERS 幀（包含狀態碼等）
4. 回傳 DATA 幀（回應主體）
5. 可選地回傳 trailing HEADERS

### 4.4 設定參數 (Settings)

連線建立時，雙方透過控制串流交換 SETTINGS 幀：

| 設定參數 | Value | 預設值 | 說明 |
|----------|-------|--------|------|
| SETTINGS_MAX_FIELD_SECTION_SIZE | 0x06 | 無限制 | 標頭區段大小上限 |
| SETTINGS_QPACK_MAX_TABLE_CAPACITY | 0x01 | 0 | QPACK 動態表容量上限 |
| SETTINGS_QPACK_BLOCKED_STREAMS | 0x07 | 0 | QPACK 允許的阻塞串流數 |

### 4.5 錯誤碼 (Error Codes)

| 錯誤碼 | Value | 說明 |
|--------|-------|------|
| H3_NO_ERROR | 0x0100 | 無錯誤（用於優雅關閉） |
| H3_GENERAL_PROTOCOL_ERROR | 0x0101 | 一般協定錯誤 |
| H3_INTERNAL_ERROR | 0x0102 | 內部錯誤 |
| H3_STREAM_CREATION_ERROR | 0x0103 | 串流建立錯誤 |
| H3_CLOSED_CRITICAL_STREAM | 0x0104 | 關鍵串流被關閉 |
| H3_FRAME_UNEXPECTED | 0x0105 | 收到非預期的幀 |
| H3_FRAME_ERROR | 0x0106 | 幀格式錯誤 |
| H3_EXCESSIVE_LOAD | 0x0107 | 對端產生過多負載 |
| H3_ID_ERROR | 0x0108 | 識別碼錯誤 |
| H3_SETTINGS_ERROR | 0x0109 | SETTINGS 幀錯誤 |
| H3_MISSING_SETTINGS | 0x010a | 缺少 SETTINGS 幀 |
| H3_REQUEST_REJECTED | 0x010b | 請求被拒絕 |
| H3_REQUEST_CANCELLED | 0x010c | 請求被取消 |
| H3_REQUEST_INCOMPLETE | 0x010d | 請求不完整 |
| H3_MESSAGE_ERROR | 0x010e | HTTP 訊息格式錯誤 |
| H3_CONNECT_ERROR | 0x010f | CONNECT 方法錯誤 |
| H3_VERSION_FALLBACK | 0x0110 | 版本回退 |

### 4.6 伺服器推送 (Server Push)

1. 伺服器在請求串流上發送 PUSH_PROMISE 幀
2. PUSH_PROMISE 包含 Push ID 和 QPACK 編碼的請求標頭
3. 伺服器開啟推送串流，以 Push ID 開頭
4. 在推送串流上發送回應 (HEADERS + DATA)
5. 客戶端可透過 CANCEL_PUSH 取消推送
6. 客戶端透過 MAX_PUSH_ID 控制可用的 Push ID 範圍

### 4.7 連線關閉

- **優雅關閉**：發送 GOAWAY 幀，指示最後處理的串流 ID，對端不應發起新的超過此 ID 的串流
- **立即關閉**：發送 QUIC CONNECTION_CLOSE 幀，附帶錯誤碼
- **閒置超時**：QUIC 傳輸參數中可設定閒置超時時間

---

## 5. QPACK 標頭壓縮 (RFC 9204)

### 5.1 概述

QPACK 是 HTTP/3 的標頭欄位壓縮格式，由 HPACK（HTTP/2 使用）改良而來。主要解決在 QUIC 亂序傳遞環境下的壓縮效率與隊頭阻塞問題。

### 5.2 與 HPACK 的差異

| 特性 | HPACK (HTTP/2) | QPACK (HTTP/3) |
|------|----------------|-----------------|
| 動態表更新 | 在 HEADERS 幀中直接更新 | 透過獨立的編碼器/解碼器串流 |
| 串流同步 | TCP 保證順序 | 需要額外機制處理亂序 |
| 阻塞行為 | 參考不存在的索引會出錯 | 可阻塞等待動態表更新 |
| 靈活性 | 固定行為 | 實作可選擇壓縮率 vs 阻塞的平衡 |

### 5.3 組件架構

```
+--------+          Encoder Stream          +--------+
|        | --------------------------------> |        |
| Encoder|                                  | Decoder|
|        | <-------------------------------- |        |
+--------+          Decoder Stream          +--------+
     |                                           |
     |  Encoded Field Sections on                |
     |  Request/Push Streams                     |
     +------------------------------------------>+
```

#### 靜態表 (Static Table)

- 預定義的 99 個常用標頭欄位
- 包含常見的 HTTP 方法、狀態碼、標頭名稱等
- 索引從 0 開始

#### 動態表 (Dynamic Table)

- FIFO 列表，有最大容量限制
- 由 SETTINGS_QPACK_MAX_TABLE_CAPACITY 控制上限
- 編碼器透過編碼器串流新增條目
- 被參考的條目不可被驅逐

### 5.4 編碼器串流指令

- **Set Dynamic Table Capacity**：設定動態表容量
- **Insert With Name Reference**：參考靜態/動態表中的名稱，插入新條目
- **Insert With Literal Name**：使用字面名稱插入新條目
- **Duplicate**：複製動態表中的既有條目

### 5.5 解碼器串流指令

- **Section Acknowledgment**：確認已處理某串流的標頭區段
- **Stream Cancellation**：通知串流已被取消
- **Insert Count Increment**：通知已知的插入計數增量

### 5.6 阻塞串流處理

- 編碼的標頭區段包含 Required Insert Count
- 如果解碼器的動態表尚未包含所需的條目，串流會被阻塞
- SETTINGS_QPACK_BLOCKED_STREAMS 控制允許的最大阻塞串流數
- 實作可選擇只使用靜態表來避免阻塞（犧牲壓縮率）

---

## 6. HTTP/3 vs HTTP/2 比較

### 6.1 架構差異

| 特性 | HTTP/2 | HTTP/3 |
|------|--------|--------|
| 傳輸協定 | TCP | QUIC (基於 UDP) |
| 加密 | TLS 1.2+ (可選) | TLS 1.3 (強制) |
| 多工 | 應用層 | 傳輸層原生支援 |
| 標頭壓縮 | HPACK | QPACK |
| 連線建立 | TCP 3-way + TLS (2-3 RTT) | QUIC 握手 (1 RTT / 0-RTT) |
| 隊頭阻塞 | TCP 層存在 | 已解決 |
| 連線遷移 | 不支援 | 支援 |
| 流量控制 | HTTP/2 層 | QUIC 層 |

### 6.2 效能比較

根據各項基準測試結果：

| 場景 | HTTP/3 改善幅度 | 來源 |
|------|-----------------|------|
| 小型頁面 (15KB) | ~3% 延遲降低 | [Cloudflare](https://blog.cloudflare.com/http-3-vs-http-2/) |
| 高封包遺失網路 | **55% 延遲降低** | [DebugBear](https://www.debugbear.com/blog/http3-vs-http2-performance) |
| 不穩定行動網路 | **52% 下載加速** | [DebugBear](https://www.debugbear.com/blog/http3-vs-http2-performance) |
| 跨洲連線 (美東-德國) | 25% 下載加速 | [DebugBear](https://www.debugbear.com/blog/http3-vs-http2-performance) |
| 行動裝置延遲 | 30% 延遲降低 | Akamai 2025 報告 |
| 連線建立時間 | ~50% 降低 | 0-RTT vs TCP+TLS |

**關鍵結論**：HTTP/3 在**網路品質越差的環境下優勢越明顯**，在高延遲、高封包遺失率的場景效能提升最為顯著。

### 6.3 安全性差異

- HTTP/3 **強制加密**（TLS 1.3），不存在明文傳輸
- QUIC 封包標頭大部分也被加密，降低中間人觀察和干擾的能力
- 連線遷移需要路徑驗證，防止路徑注入攻擊
- 0-RTT 資料無法防禦重放攻擊，需應用層注意

---

## 7. 實作函式庫

### 7.1 Python

| 函式庫 | 說明 |
|--------|------|
| [aioquic](https://github.com/aiortc/aioquic) | 純 Python QUIC/HTTP/3 實作，支援 asyncio。被 dnspython、hypercorn、mitmproxy 使用 |

### 7.2 Rust

| 函式庫 | 說明 |
|--------|------|
| [quiche](https://github.com/cloudflare/quiche) | Cloudflare 開發，低階 API，提供 C API 綁定 |
| [tokio-quiche](https://blog.cloudflare.com/async-quic-and-http-3-made-easy-tokio-quiche-is-now-open-source/) | quiche + Tokio 非同步執行環境整合 |
| [quinn](https://github.com/quinn-rs/quinn) | 基於 Tokio 的非同步友好 QUIC 實作 |
| [neqo](https://github.com/nicovank/neqo) | Mozilla 的 QUIC/HTTP/3 實作（Firefox 使用） |
| [s2n-quic](https://github.com/aws/s2n-quic) | AWS 的 Rust QUIC 實作 |

### 7.3 Go

| 函式庫 | 說明 |
|--------|------|
| [quic-go](https://github.com/quic-go/quic-go) | Go 語言的 QUIC 實作 |

### 7.4 C/C++

| 函式庫 | 說明 |
|--------|------|
| [ngtcp2](https://github.com/ngtcp2/ngtcp2) | C 語言 QUIC 實作 |
| [msquic](https://github.com/microsoft/msquic) | Microsoft 跨平台 QUIC 實作 |
| [lsquic](https://github.com/litespeedtech/lsquic) | LiteSpeed QUIC 實作 |

### 7.5 測試工具

| 工具 | 說明 |
|------|------|
| [h3i](https://blog.cloudflare.com/h3i/) | Cloudflare 的 HTTP/3 低階測試與除錯工具 |
| [quic-interop-runner](https://github.com/quicwg/base-drafts/wiki/Implementations) | QUIC 互通性測試框架 |

---

## 8. 結論與建議

### HTTP/3 的主要優勢

1. **消除隊頭阻塞**：QUIC 原生多工，封包遺失只影響單一串流
2. **更快的連線建立**：1-RTT（首次）/ 0-RTT（後續）大幅降低延遲
3. **連線遷移**：網路切換不中斷連線，對行動裝置特別重要
4. **強制加密**：TLS 1.3 整合，安全性更高
5. **使用者空間實作**：不受作業系統核心限制，可快速迭代更新

### 需注意的挑戰

1. **UDP 可能被防火牆封鎖**：部分企業環境可能封鎖 UDP 443
2. **CPU 使用率較高**：QUIC 在使用者空間處理，缺乏核心層級的最佳化
3. **0-RTT 重放攻擊風險**：需在應用層處理冪等性
4. **生態系統成熟度**：相較 TCP/HTTP/2，除錯與監控工具較少
5. **中間設備相容性**：部分網路中間設備可能不支援 QUIC

### 對本專案的建議

- 考慮使用 **aioquic**（Python）或 **quiche/quinn**（Rust）作為 HTTP/3 客戶端實作
- 實作時應同時支援 HTTP/2 回退，以處理 QUIC 被封鎖的場景
- 利用 Alt-Svc 標頭進行 HTTP/3 探索與升級
- 注意 0-RTT 的安全限制，對非冪等操作使用 1-RTT

---

*研究日期：2026-04-03*
*資料來源：RFC 9000, RFC 9114, RFC 9204, Cloudflare, DebugBear, IANA HTTP/3 Parameters Registry*
