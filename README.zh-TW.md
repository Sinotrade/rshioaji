# rshioaji

[Shioaji](https://sinotrade.github.io/) 的 Rust 實作 — 永豐金證券**跨語言、跨平台**金融市場交易 API。

[![PyPI](https://img.shields.io/pypi/v/rshioaji)](https://pypi.org/project/rshioaji/)

[English](README.md)

> **⚠️ Alpha 階段** — 本專案仍在積極開發中，尚未達到正式版品質。API 可能隨時變更，請自行承擔風險。

## 什麼是 rshioaji？

Shioaji 過去僅支援 Python。rshioaji 將其轉變為**通用交易平台** — 任何程式語言都能透過 HTTP API 伺服器搭配 SSE 即時串流進行交易。

| 存取層 | 對象 | 方式 |
|--------|------|------|
| **Python** | 原生綁定 (PyO3) | `import shioaji` — 最佳效能，支援同步/非同步 |
| **HTTP API + SSE** | 任何語言 | REST 端點 + 即時串流 `localhost:8080` |
| **CLI** | 終端 / 腳本 | `shioaji` 指令管理伺服器、交易、資料查詢 |

### 支援語言

Python, JavaScript/TypeScript, Go, C/C++, C#, Rust, Java/Kotlin

## 功能

- **Python 交易 API** — 以 Rust 重新實作的 Shioaji Python 函式庫，透過 PyO3 綁定
- **HTTP API 伺服器** — RESTful API + SSE 串流，任何語言皆可使用
- **內建儀表板** — 即時監控伺服器狀態、API 使用量、SSE 連線、帳戶與憑證
- **自訂應用** — 上傳自己的 Web 應用至伺服器，與儀表板並行服務
- **OpenAPI 文件** — 自動產生互動式 API 文件 (`/docs`)，request/response schema 的唯一真實來源
- **CLI 工具** — 管理伺服器、Token 池、API 連線
- **Claude Code 技能** — AI 輔助開發，完整交易 API 文件

## Claude Code 技能

安裝 shioaji 技能進行 AI 輔助交易開發：

```bash
claude plugin marketplace add Sinotrade/rshioaji
claude plugin install rshioaji
```

技能涵蓋所有存取層 — Python、CLI、HTTP API、SSE 串流，以及 JS/TS、Go、C/C++、C#、Rust、Java/Kotlin 的完整專案指南。

## 儀表板

![Shioaji Dashboard](https://raw.githubusercontent.com/sinotrade/rshioaji/main/assets/dashboard.png)

儀表板提供即時監控：
- **伺服器健康** — 版本、運行時間、模擬模式
- **API 使用量** — 連線數、頻寬使用
- **SSE 串流** — 活躍串流連線狀態
- **CA 憑證** — 憑證狀態與到期日
- **帳戶** — 關聯交易帳戶

伺服器運行時於 `http://localhost:8080/` 存取儀表板。

## 自訂應用

![Custom Apps](https://raw.githubusercontent.com/sinotrade/rshioaji/main/assets/custom-apps.png)

從儀表板的 **Custom Apps** 卡片上傳自訂 Web 應用 — 支援單檔或 Vite 建置輸出。應用服務於 `/apps/<name>/`。

入門範本：[Sinotrade/shioaji-app-demo](https://github.com/Sinotrade/shioaji-app-demo)

## 安裝

### Python 套件

```bash
# uv（推薦）
uv add rshioaji

# pip
pip install rshioaji
```

### CLI 工具

```bash
uv tool install rshioaji
shioaji --help
```

### 獨立二進制檔

**Linux / macOS：**
```bash
# 穩定版
curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | sh

# 預覽版
curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | CHANNEL=prerelease sh

# 指定版本
curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | VERSION=v1.5.0b2 sh
```

**Windows (PowerShell)：**
```powershell
# 穩定版
irm https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.ps1 | iex

# 預覽版
$env:CHANNEL="prerelease"; irm https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.ps1 | iex
```

## 使用方式

### Python API

```python
import shioaji as sj

api = sj.Shioaji(simulation=True)
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# 快照
api.snapshots([api.Contracts.Stocks["2330"]])

# K 線
api.kbars(api.Contracts.Stocks["2330"])
```

### HTTP API（任何語言）

啟動伺服器以 REST API 存取 Shioaji：

```bash
shioaji server start
```

伺服器提供：
- **REST API** `http://localhost:8080/api/v1/`
- **OpenAPI 文件** `http://localhost:8080/docs` — 瀏覽 schema、測試端點
- **OpenAPI 規格** `http://localhost:8080/openapi.json` — 自動產生型別化客戶端
- **儀表板** `http://localhost:8080/`
- **SSE 串流** — 即時 tick、bidask、quote 資料

```bash
# 取得快照
curl -X POST http://localhost:8080/api/v1/data/snapshots \
  -H "Content-Type: application/json" \
  -d '{"contracts":[{"security_type":"STK","exchange":"TSE","code":"2330"}]}'

# 訂閱即時 tick 串流 (SSE)
curl -X POST http://localhost:8080/api/v1/stream/subscribe \
  -H "Content-Type: application/json" \
  -d '{"security_type":"STK","exchange":"TSE","code":"2330","quote_type":"Tick"}'
curl -N http://localhost:8080/api/v1/stream/data/tick_stk
```

### CLI

```bash
shioaji server start              # 啟動 HTTP 伺服器（模擬模式）
shioaji server start --production # 正式環境模式
shioaji server check              # 檢查模式與認證狀態
shioaji server status             # 顯示 daemon 狀態
shioaji server stop               # 停止 daemon
shioaji auth accounts             # 列出交易帳戶
shioaji data snapshots --codes 2330,2317
shioaji order place --code 2330 --action Buy --price 580 --quantity 1
shioaji portfolio balance
shioaji utils token list          # 列出快取 token
shioaji utils api check           # 測試 API 連線
shioaji tree --all                # 顯示完整指令樹
```

## 平台支援

| 平台 | Wheel | Binary |
|------|-------|--------|
| Linux x86_64 | manylinux2014 | tar.gz |
| macOS aarch64 (Apple Silicon) | abi3 | tar.gz |
| Windows x86_64 | abi3 | zip |

## 連結

- [Shioaji 文件](https://sinotrade.github.io/)
- [PyPI 套件](https://pypi.org/project/rshioaji/)
- [自訂應用範本](https://github.com/Sinotrade/shioaji-app-demo)
