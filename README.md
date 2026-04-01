# rshioaji

[Shioaji](https://sinotrade.github.io/) 的 Rust 實作 — 永豐金證券**跨語言、跨平台**台灣金融市場交易 API（TWSE/TPEX/TAIFEX）。

Rust implementation of [Shioaji](https://sinotrade.github.io/) — SinoPac's **cross-language, cross-platform** trading API for Taiwan financial markets (TWSE/TPEX/TAIFEX).

[![PyPI](https://img.shields.io/pypi/v/rshioaji)](https://pypi.org/project/rshioaji/)

> **⚠️ Alpha 階段** — 本專案仍在積極開發中，尚未達到正式版品質。API 可能隨時變更，請自行承擔風險。
>
> **⚠️ Alpha Stage** — This project is under active development and not yet production-ready. APIs may change without notice. Use at your own risk.

## 什麼是 rshioaji？ / What is rshioaji?

Shioaji 過去僅支援 Python。rshioaji 將其轉變為**通用交易平台** — 任何程式語言都能透過 HTTP API 伺服器搭配 SSE 即時串流交易台灣市場。

Shioaji was Python-only. rshioaji transforms it into a **universal trading platform** — any programming language can now trade Taiwan markets through the HTTP API server with SSE real-time streaming.

| 存取層 Access Layer | 對象 Who | 方式 How |
|-------------|-----|-----|
| **Python** | 原生綁定 (PyO3) Native binding | `import shioaji` — 最佳效能，同步/非同步 best performance, sync and async |
| **HTTP API + SSE** | 任何語言 Any language | REST + 即時串流 real-time streaming at `localhost:8080` |
| **CLI** | 終端 / 腳本 Terminal / scripts | `shioaji` 指令 command for server, trading, data queries |

### 支援語言 / Supported Languages

| 語言 Language | 存取方式 Access | SSE 串流 Streaming |
|----------|--------|---------------|
| Python | 原生 PyO3 綁定 Native binding | Callbacks |
| JavaScript/TypeScript | HTTP API | `EventSource` |
| Go | HTTP API | `bufio.Scanner` |
| C/C++ | HTTP API | `libcurl` chunked |
| C# | HTTP API | `HttpClient` SSE |
| Rust | HTTP API | `reqwest-eventsource` |
| Java/Kotlin | HTTP API | `okhttp-sse` |

## 功能 / Features

- **Python 交易 API** — 以 Rust 重新實作的 Shioaji Python 函式庫，透過 PyO3 綁定 / Drop-in Rust replacement with PyO3 bindings
- **HTTP API 伺服器** — RESTful API + SSE 串流，任何語言皆可使用 / RESTful API with SSE streaming, accessible from any language
- **內建儀表板** — 即時監控伺服器狀態、API 使用量、SSE 連線、帳戶與憑證 / Real-time web UI for monitoring
- **自訂應用** — 上傳自己的 Web 應用至伺服器 / Upload and serve your own web apps alongside the dashboard
- **OpenAPI 文件** — 自動產生互動式 API 文件 (`/docs`)，request/response schema 的唯一來源 / Auto-generated interactive API docs
- **CLI 工具** — 管理伺服器、Token、API 連線 / Manage server, token pool, and API connectivity
- **Claude Code 技能** — AI 輔助開發，完整交易 API 文件 / AI-assisted development with comprehensive documentation

## Claude Code 技能 / Claude Code Skill

安裝 shioaji 技能進行 AI 輔助交易開發：

Install the shioaji skill for AI-assisted trading development:

```bash
claude plugin marketplace add Sinotrade/rshioaji
claude plugin install rshioaji
```

技能涵蓋所有存取層 — Python、CLI、HTTP API、SSE 串流，以及 JS/TS、Go、C/C++、C#、Rust、Java/Kotlin 的完整專案指南。

The skill covers all access layers — Python, CLI, HTTP API, SSE streaming, and complete project guides for JS/TS, Go, C/C++, C#, Rust, and Java/Kotlin.

## 儀表板 / Dashboard

![Shioaji Dashboard](https://raw.githubusercontent.com/sinotrade/rshioaji/main/assets/dashboard.png)

儀表板提供即時監控 / The dashboard provides real-time monitoring of:
- **伺服器健康 Server Health** — 版本、運行時間、模擬模式 / version, uptime, simulation mode
- **API 使用量 API Usage** — 連線數、頻寬使用 / connection count, bandwidth usage
- **SSE 串流 SSE Streams** — 活躍連線狀態 / active stream connections and health status
- **CA 憑證 CA Certificates** — 憑證狀態與到期日 / certificate status and expiration
- **帳戶 Accounts** — 關聯交易帳戶 / linked trading accounts

伺服器運行時於 `http://localhost:8080/` 存取儀表板。

Access the dashboard at `http://localhost:8080/` when the server is running.

## 自訂應用 / Custom Apps

![Custom Apps](https://raw.githubusercontent.com/sinotrade/rshioaji/main/assets/custom-apps.png)

從儀表板的 **Custom Apps** 卡片上傳自訂 Web 應用 — 支援單檔或 Vite 建置輸出。應用服務於 `/apps/<name>/`。

Upload custom web apps from the dashboard's **Custom Apps** card — supports single files or Vite build output folders. Apps are served at `/apps/<name>/`.

入門範本 Demo template: [Sinotrade/shioaji-app-demo](https://github.com/Sinotrade/shioaji-app-demo)

## 安裝 / Install

### Python 套件 / Python Package

```bash
# uv（推薦 recommended）
uv add rshioaji

# pip
pip install rshioaji
```

### CLI 工具 / CLI Tool

```bash
uv tool install rshioaji
shioaji --help
```

### 獨立二進制檔 / Standalone Binary

**Linux / macOS:**
```bash
# 穩定版 Stable
curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | sh

# 預覽版 Pre-release
curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | CHANNEL=prerelease sh

# 指定版本 Specific version
curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | VERSION=v1.5.0b2 sh
```

**Windows (PowerShell):**
```powershell
# 穩定版 Stable
irm https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.ps1 | iex

# 預覽版 Pre-release
$env:CHANNEL="prerelease"; irm https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.ps1 | iex
```

## 使用方式 / Usage

### Python API

```python
import shioaji as sj

api = sj.Shioaji(simulation=True)
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# 快照 Snapshots
api.snapshots([api.Contracts.Stocks["2330"]])

# K 線 Kbars
api.kbars(api.Contracts.Stocks["2330"])
```

### HTTP API（任何語言 any language）

啟動伺服器以 REST API 存取 Shioaji / Start the server to expose Shioaji as a REST API:

```bash
shioaji server start
```

伺服器提供 / The server provides:
- **REST API** `http://localhost:8080/api/v1/`
- **OpenAPI 文件 docs** `http://localhost:8080/docs` — 瀏覽 schema、測試端點 / browse schemas, try endpoints
- **OpenAPI 規格 spec** `http://localhost:8080/openapi.json` — 自動產生型別化客戶端 / auto-generate typed clients
- **儀表板 Dashboard** `http://localhost:8080/`
- **SSE 串流 streams** — 即時 tick、bidask、quote 資料 / real-time data

```bash
# 取得快照 Get market snapshots
curl -X POST http://localhost:8080/api/v1/data/snapshots \
  -H "Content-Type: application/json" \
  -d '{"contracts":[{"security_type":"STK","exchange":"TSE","code":"2330"}]}'

# 訂閱即時 tick 串流 Subscribe and stream real-time ticks (SSE)
curl -X POST http://localhost:8080/api/v1/stream/subscribe \
  -H "Content-Type: application/json" \
  -d '{"security_type":"STK","exchange":"TSE","code":"2330","quote_type":"Tick"}'
curl -N http://localhost:8080/api/v1/stream/data/tick_stk
```

### CLI

```bash
shioaji server start              # 啟動 HTTP 伺服器（模擬）Start HTTP server (simulation)
shioaji server start --production # 正式環境 Production mode
shioaji server check              # 檢查模式與認證狀態 Check mode and auth status
shioaji server status             # 顯示 daemon 狀態 Show daemon status
shioaji server stop               # 停止 daemon Stop the daemon
shioaji auth accounts             # 列出交易帳戶 List trading accounts
shioaji data snapshots --codes 2330,2317
shioaji order place --code 2330 --action Buy --price 580 --quantity 1
shioaji portfolio balance
shioaji utils token list          # 列出快取 token List cached tokens
shioaji utils api check           # 測試 API 連線 Test API connectivity
shioaji tree --all                # 顯示完整指令樹 Show full command tree
```

## 平台支援 / Platform Support

| 平台 Platform | Wheel | Binary |
|----------|-------|--------|
| Linux x86_64 | manylinux2014 | tar.gz |
| macOS aarch64 (Apple Silicon) | abi3 | tar.gz |
| Windows x86_64 | abi3 | zip |

## 連結 / Links

- [Shioaji 文件 Documentation](https://sinotrade.github.io/)
- [PyPI 套件 Package](https://pypi.org/project/rshioaji/)
- [自訂應用範本 Custom App Demo Template](https://github.com/Sinotrade/shioaji-app-demo)
