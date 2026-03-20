# rshioaji

Rust implementation of [Shioaji](https://sinotrade.github.io/) — SinoPac's trading API for Taiwan financial markets (TWSE/TPEX/TAIFEX).

[![PyPI](https://img.shields.io/pypi/v/rshioaji)](https://pypi.org/project/rshioaji/)

> **⚠️ Alpha Stage** — This project is under active development and not yet production-ready. APIs may change without notice. Use at your own risk.

## Features

- **Python Trading API** — Drop-in Rust replacement for the Python Shioaji library, with PyO3 bindings
- **HTTP Adaptor Server** — RESTful API relay that translates HTTP requests to the Solace messaging backend
- **Built-in Dashboard** — Real-time web UI for monitoring server health, API usage, SSE streams, accounts, and CA certificates
- **OpenAPI Documentation** — Auto-generated interactive API docs at `/docs`
- **CLI Tool** — Manage server, token pool, and API connectivity from the command line

## Dashboard

![Shioaji Dashboard](https://raw.githubusercontent.com/sinotrade/rshioaji/main/assets/dashboard.png)

The dashboard provides real-time monitoring of:
- **Server Health** — version, uptime, simulation mode
- **API Usage** — connection count, bandwidth usage
- **SSE Streams** — active stream connections and health status
- **CA Certificates** — certificate status and expiration
- **Accounts** — linked trading accounts

Access the dashboard at `http://localhost:8080/` when the server is running.

## Install

### Python Package

```bash
pip install rshioaji
# or
uv add rshioaji
```

### CLI Tool

```bash
uv tool install rshioaji
shioaji --help
```

### Standalone Binary

**Linux / macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | sh
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.ps1 | iex
```

## Usage

### Python API

```python
import shioaji as sj

api = sj.Shioaji(simulation=True)
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Snapshots
api.snapshots([api.Contracts.Stocks["2330"]])

# Kbars
api.kbars(api.Contracts.Stocks["2330"])
```

### HTTP Adaptor Server

Start the server to expose Shioaji as a REST API:

```bash
shioaji server start
```

The server provides:
- **REST API** at `http://localhost:8080/api/v1/`
- **OpenAPI docs** at `http://localhost:8080/docs`
- **Dashboard** at `http://localhost:8080/`
- **SSE streams** for real-time tick, bidask, and quote data

Full API documentation available at `/docs` when the server is running.

### CLI

```bash
shioaji server start              # Start HTTP relay server
shioaji server check              # Health check
shioaji utils token list          # List cached tokens
shioaji utils token clean --all   # Clean all tokens (with server logout)
shioaji utils api check           # Test API connectivity
```

## Platform Support

| Platform | Wheel | Binary |
|----------|-------|--------|
| Linux x86_64 | manylinux2014 | tar.gz |
| macOS aarch64 (Apple Silicon) | abi3 | tar.gz |
| Windows x86_64 | abi3 | zip |

## Links

- [Shioaji Documentation](https://sinotrade.github.io/)
- [PyPI Package](https://pypi.org/project/rshioaji/)
- [CI/CD Pipeline](https://github.com/sinotrade/rshioaji/blob/main/CICD.md)
