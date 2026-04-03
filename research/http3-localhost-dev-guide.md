# HTTP/3 Localhost 開發測試指南

## 核心挑戰

HTTP/3 在 localhost 開發有兩個主要障礙：

1. **強制 TLS 1.3** — HTTP/3/QUIC 不支援明文傳輸，必須有憑證
2. **瀏覽器限制** — 主流瀏覽器不接受自簽憑證的 HTTP/3 連線（會 fallback 到 HTTP/2）

---

## 方案一：mkcert + 本地信任 CA（推薦用於瀏覽器測試）

使用 [mkcert](https://github.com/FiloSottile/mkcert) 建立本地受信任的 CA，產生的憑證瀏覽器會信任。

### 步驟

```bash
# 1. 安裝 mkcert
# macOS
brew install mkcert nss  # nss 是 Firefox 支援所需

# Linux (Ubuntu/Debian)
sudo apt install libnss3-tools
curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
chmod +x mkcert-v*-linux-amd64
sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert

# 2. 安裝本地 CA 到系統信任庫
mkcert -install

# 3. 產生 localhost 憑證
mkcert localhost 127.0.0.1 ::1
# 輸出: localhost+2.pem 和 localhost+2-key.pem
```

### 搭配 Caddy（最簡單的 HTTP/3 伺服器）

[Caddy](https://caddyserver.com/) 預設啟用 HTTP/3。

```
# Caddyfile
{
    # HTTP/3 預設已啟用，無需額外設定
}

localhost {
    tls ./localhost+2.pem ./localhost+2-key.pem
    reverse_proxy localhost:8080  # 反向代理到你的後端服務
}
```

```bash
caddy run
```

瀏覽器訪問 `https://localhost` 即可使用 HTTP/3。

---

## 方案二：aioquic（Python，推薦用於程式化測試）

[aioquic](https://github.com/aiortc/aioquic) 是純 Python 的 QUIC/HTTP/3 實作，自簽憑證即可。

### 安裝

```bash
pip install aioquic
```

### 產生自簽憑證

```bash
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
  -days 365 -nodes \
  -keyout localhost.key -out localhost.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:::1"
```

### HTTP/3 Server 範例

```python
# h3_server.py
import asyncio
from aioquic.asyncio import serve
from aioquic.quic.configuration import QuicConfiguration
from aioquic.h3.connection import H3Connection
from aioquic.h3.events import HeadersReceived, DataReceived
from aioquic.asyncio.protocol import QuicConnectionProtocol
from aioquic.quic.events import QuicEvent, StreamDataReceived

class H3Handler(QuicConnectionProtocol):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._h3 = None

    def quic_event_received(self, event: QuicEvent):
        if isinstance(event, StreamDataReceived):
            # 延遲初始化 H3Connection
            if self._h3 is None:
                self._h3 = H3Connection(self._quic)

            for h3_event in self._h3.handle_event(event):
                if isinstance(h3_event, HeadersReceived):
                    # 收到 HTTP 請求標頭
                    headers = dict(h3_event.headers)
                    print(f"Request: {headers.get(b':method')} {headers.get(b':path')}")

                    # 回傳回應
                    self._h3.send_headers(
                        stream_id=h3_event.stream_id,
                        headers=[
                            (b":status", b"200"),
                            (b"content-type", b"application/json"),
                        ],
                    )
                    self._h3.send_data(
                        stream_id=h3_event.stream_id,
                        data=b'{"message": "Hello from HTTP/3!"}',
                        end_stream=True,
                    )
                    self.transmit()

async def main():
    config = QuicConfiguration(is_client=False)
    config.load_cert_chain("localhost.crt", "localhost.key")

    server = await serve(
        host="0.0.0.0",
        port=4433,
        configuration=config,
        create_protocol=H3Handler,
    )

    print("HTTP/3 server running on https://localhost:4433")
    await asyncio.Future()  # 永遠等待

if __name__ == "__main__":
    asyncio.run(main())
```

### HTTP/3 Client 範例

```python
# h3_client.py
import asyncio
from aioquic.asyncio import connect
from aioquic.quic.configuration import QuicConfiguration
from aioquic.h3.connection import H3Connection
from aioquic.h3.events import HeadersReceived, DataReceived
from aioquic.asyncio.protocol import QuicConnectionProtocol
from aioquic.quic.events import QuicEvent, StreamDataReceived

class H3Client(QuicConnectionProtocol):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._h3 = None
        self._response_data = bytearray()
        self._response_headers = []
        self._done = asyncio.Event()

    def quic_event_received(self, event: QuicEvent):
        if isinstance(event, StreamDataReceived):
            if self._h3 is None:
                self._h3 = H3Connection(self._quic)

            for h3_event in self._h3.handle_event(event):
                if isinstance(h3_event, HeadersReceived):
                    self._response_headers = h3_event.headers
                elif isinstance(h3_event, DataReceived):
                    self._response_data.extend(h3_event.data)
                    if h3_event.stream_ended:
                        self._done.set()

    async def send_request(self, url_path: str):
        if self._h3 is None:
            self._h3 = H3Connection(self._quic)

        stream_id = self._quic.get_next_available_stream_id()
        self._h3.send_headers(
            stream_id=stream_id,
            headers=[
                (b":method", b"GET"),
                (b":scheme", b"https"),
                (b":authority", b"localhost"),
                (b":path", url_path.encode()),
            ],
            end_stream=True,
        )
        self.transmit()

        await self._done.wait()
        return self._response_headers, bytes(self._response_data)

async def main():
    config = QuicConfiguration(is_client=True)
    # 跳過憑證驗證（本地開發用）
    config.verify_mode = False

    async with connect("localhost", 4433, configuration=config,
                       create_protocol=H3Client) as client:
        headers, data = await client.send_request("/")
        print(f"Status: {dict(headers).get(b':status')}")
        print(f"Body: {data.decode()}")

if __name__ == "__main__":
    asyncio.run(main())
```

---

## 方案三：curl --http3（命令列測試）

curl 從 8.x 版起支援 HTTP/3。

```bash
# 檢查 curl 是否支援 HTTP/3
curl --version | grep HTTP3

# 強制使用 HTTP/3，跳過憑證驗證
curl --http3-only --insecure -v https://localhost:4433/

# 嘗試 HTTP/3，失敗則 fallback
curl --http3 --insecure -v https://localhost:4433/
```

### 安裝支援 HTTP/3 的 curl

```bash
# macOS (Homebrew 版本通常已支援)
brew install curl

# Ubuntu/Debian - 可能需要從原始碼編譯
# 或使用 docker image
docker run --rm --network host curlimages/curl \
  --http3-only --insecure https://localhost:4433/
```

---

## 方案四：Chrome / Firefox 瀏覽器測試

### Chrome

```bash
# 強制對特定 host:port 使用 QUIC
google-chrome \
  --origin-to-force-quic-on=localhost:443 \
  --ignore-certificate-errors-spki-list=<SPKI_HASH> \
  https://localhost
```

取得 SPKI hash：
```bash
openssl x509 -in localhost.crt -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  openssl enc -base64
```

### Chrome DevTools 驗證

1. 開啟 DevTools → Network 標籤
2. 右鍵欄位標頭 → 勾選 "Protocol"
3. 看到 `h3` 表示成功使用 HTTP/3

### Firefox

Firefox 使用 Alt-Svc 標頭升級到 HTTP/3：
1. 先用 HTTP/2 回應，帶上 `Alt-Svc: h3=":443"` 標頭
2. Firefox 後續連線會嘗試 HTTP/3
3. 需搭配 mkcert 信任的憑證

---

## 方案五：Nginx + QUIC（接近生產環境）

Nginx 從 1.25.0 起支援 QUIC/HTTP/3。

### nginx.conf

```nginx
server {
    # HTTP/2 over TCP
    listen 443 ssl;

    # HTTP/3 over QUIC
    listen 443 quic reuseport;

    ssl_certificate     /path/to/localhost.crt;
    ssl_certificate_key /path/to/localhost.key;

    # 必要：告知瀏覽器支援 HTTP/3
    add_header Alt-Svc 'h3=":443"; ma=86400';

    # QUIC 需要 TLS 1.3
    ssl_protocols TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
```

### Docker Compose

```yaml
version: "3.8"
services:
  nginx:
    image: nginx:latest  # 1.25.0+
    ports:
      - "443:443/tcp"   # HTTP/2
      - "443:443/udp"   # HTTP/3 (QUIC)
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - ./localhost.crt:/etc/nginx/ssl/localhost.crt
      - ./localhost.key:/etc/nginx/ssl/localhost.key
```

> **注意**：HTTP/3 需要同時開放 TCP 和 UDP 的 443 port。

---

## 方案比較

| 方案 | 適用場景 | 設定複雜度 | 瀏覽器支援 |
|------|---------|-----------|-----------|
| mkcert + Caddy | 最簡單的全功能方案 | ★☆☆ | ✅ 完整支援 |
| aioquic (Python) | 程式化測試、單元測試 | ★★☆ | ❌ 僅程式化 |
| curl --http3 | 快速 CLI 驗證 | ★☆☆ | ❌ 僅 CLI |
| Chrome flags | 瀏覽器除錯 | ★★☆ | ⚠️ 需特殊啟動參數 |
| Nginx + QUIC | 接近生產環境 | ★★★ | ✅ 需 mkcert |

---

## 常見問題

### Q: 為什麼瀏覽器不走 HTTP/3？
- 確認 UDP 443 port 有開放（QUIC 走 UDP）
- 確認 `Alt-Svc` 回應標頭存在
- 確認憑證被系統信任（用 mkcert）
- Chrome 首次訪問一定走 HTTP/2，第二次才會升級到 HTTP/3

### Q: 防火牆需要注意什麼？
- QUIC 使用 **UDP port 443**（不是 TCP）
- 本地開發需確保 UDP 443 未被封鎖
- Docker 需同時映射 TCP 和 UDP port

### Q: 0-RTT 在 localhost 有效嗎？
- 有效，但首次連線仍需 1-RTT
- 後續連線可使用 0-RTT（需伺服器支援 session resumption）
- localhost 延遲極低，0-RTT 效益不明顯

### Q: 如何確認連線確實是 HTTP/3？
```bash
# curl 會顯示協定版本
curl --http3-only --insecure -v https://localhost:4433/ 2>&1 | grep "using HTTP/3"

# 或檢查回應標頭
curl --http3-only --insecure -I https://localhost:4433/
```

---

*研究日期：2026-04-03*
*參考來源：[aioquic](https://github.com/aiortc/aioquic), [Caddy](https://caddyserver.com/), [mkcert](https://github.com/FiloSottile/mkcert), [curl HTTP/3](https://curl.se/docs/http3.html), [Nginx QUIC](https://nginx.org/en/docs/quic.html)*
