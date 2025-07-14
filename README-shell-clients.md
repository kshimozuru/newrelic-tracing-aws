# New Relic分散トレーシング - シェルクライアント実装ガイド

このドキュメントでは、AWS API Gatewayを呼び出すための3種類のシェルクライアント実装について説明します。それぞれ異なるアプローチでNew Relicとの統合レベルが異なります。

## 📋 クライアント実装一覧

| スクリプト | 実装方式 | New Relic統合 | Entity表示 | 使用用途 |
|-----------|----------|---------------|------------|----------|
| `call-api.sh` | 純粋シェル | ❌ なし | ❌ なし | 軽量テスト |
| `call-api-newrelic.js` | Node.js統合 | ✅ エージェント | ✅ あり | 本格運用 |
| `call-api-otel.sh` | OpenTelemetry | ✅ OTLP | ✅ あり | 標準準拠 |

---

## 🔧 1. 純粋シェルスクリプト版 (`call-api.sh`)

### 概要
軽量でシンプルなHTTPクライアント実装。New Relicとの直接統合はありませんが、最も導入が簡単です。

### 特徴
- **依存関係**: curl, openssl のみ
- **起動速度**: 非常に高速
- **New Relic統合**: なし
- **TraceID**: W3C準拠形式生成（32文字16進数）

### 使用方法

```bash
# 基本的な使用
./call-api.sh

# カスタムメッセージ
./call-api.sh "Hello World"

# 追加データ付き
./call-api.sh "Test Message" '{"userId": "123", "priority": "high"}'

# ヘルプ表示
./call-api.sh --help
```

### 内部実装
```bash
# TraceID生成（タイムスタンプ + ランダム）
local timestamp_hex=$(printf "%08x" $(date +%s))
local random_hex=$(openssl rand -hex 12)
local trace_id="${timestamp_hex}${random_hex}"

# HTTP リクエスト送信
curl -X POST \
    -H "Content-Type: application/json" \
    -H "X-Trace-Id: $trace_id" \
    -d "$json_payload" \
    "$API_URL"
```

### 適用場面
- ✅ 簡単な動作確認
- ✅ CI/CDパイプライン
- ✅ 軽量なテストスクリプト
- ❌ 本格的な監視・トレーシング

---

## 🔧 2. Node.js統合版 (`call-api-newrelic.js`)

### 概要
New Relicエージェントを使用した本格的なAPM統合実装。完全な分散トレーシングとエンティティ管理が可能です。

### 特徴
- **依存関係**: Node.js, New Relicエージェント
- **New Relic統合**: フル機能
- **Entity Name**: `newrelic-tracing-shell-client`
- **トランザクション**: バックグラウンドトランザクション作成

### セットアップ
```bash
# 依存関係インストール
npm install newrelic dotenv axios commander

# 環境変数設定（.env）
NEW_RELIC_LICENSE_KEY=your-license-key
NEW_RELIC_APP_NAME=newrelic-tracing-shell-client
```

### 使用方法

```bash
# New Relic統合テスト
node call-api-newrelic.js test

# API呼び出し（カスタムメッセージ）
node call-api-newrelic.js send -m "Hello New Relic" -d '{"userId": "123"}'

# ヘルプ表示
node call-api-newrelic.js --help
```

### 内部実装
```javascript
// New Relic トランザクション作成
await newrelic.startBackgroundTransaction('shell-api-call', 'Custom', async () => {
    // カスタムアトリビュート追加
    newrelic.addCustomAttributes({
        'shell.message': message,
        'shell.trace_id': traceId,
        'response.status': response.status
    });
    
    // HTTP リクエスト実行
    const response = await axios.post(apiUrl, requestData);
});
```

### New Relicでの表示内容
- **APMエンティティ**: `newrelic-tracing-shell-client`
- **トランザクション名**: `shell-api-call`
- **カスタムアトリビュート**: リクエスト詳細情報
- **分散トレーシング**: 完全対応

### 適用場面
- ✅ 本格的なアプリケーション監視
- ✅ 詳細なパフォーマンス分析
- ✅ エラー追跡・アラート
- ✅ SLI/SLO監視

---

## 🔧 3. OpenTelemetry統合版 (`call-api-otel.sh`)

### 概要
OpenTelemetry Protocol (OTLP) を使用した標準準拠の実装。ベンダー非依存でNew Relicと統合します。

### 特徴
- **依存関係**: otel-cli, curl, openssl
- **プロトコル**: OpenTelemetry OTLP
- **Entity Name**: `newrelic-tracing-otel-shell`
- **標準準拠**: W3C Trace Context完全対応

### セットアップ
```bash
# otel-cli インストール
go install github.com/equinix-labs/otel-cli@latest

# 環境変数設定
export OTEL_EXPORTER_OTLP_ENDPOINT="https://otlp.nr-data.net/v1/traces"
export OTEL_SERVICE_NAME="newrelic-tracing-otel-shell"
```

### 使用方法

```bash
# OpenTelemetry統合テスト
./call-api-otel.sh test

# API呼び出し
./call-api-otel.sh send "OpenTelemetry Test" '{"protocol": "otlp"}'

# カスタムスパン送信
./call-api-otel.sh span "custom-operation" "Custom message"

# ヘルプ表示
./call-api-otel.sh help
```

### 内部実装
```bash
# OpenTelemetry スパン作成・送信
otel-cli span \
    --name "api-gateway-call" \
    --service "$OTEL_SERVICE_NAME" \
    --force-trace-id "$trace_id" \
    --endpoint "$OTEL_EXPORTER_OTLP_ENDPOINT" \
    --protocol "http/protobuf" \
    --otlp-headers "api-key=$NEW_RELIC_LICENSE_KEY" \
    --attrs "http.method=POST,http.url=$API_URL" \
    -- curl -X POST "$API_URL"
```

### New Relicでの表示内容
- **APMエンティティ**: `newrelic-tracing-otel-shell`
- **スパン名**: 指定した操作名
- **アトリビュート**: HTTP詳細、カスタムデータ
- **TraceID**: 指定したTraceIDそのまま

### 適用場面
- ✅ マルチベンダー対応
- ✅ 標準プロトコル準拠
- ✅ Kubernetes環境
- ✅ マイクロサービス間連携

---

## 🚀 実行・デプロイメント

### 前提条件

**共通:**
```bash
# プロジェクトディレクトリに移動
cd /path/to/newrelic-tracing-aws

# 環境変数設定
cp .env.example .env
# .envファイルを編集してNew Relicライセンスキーを設定
```

**OpenTelemetry版追加要件:**
```bash
# Go環境でotel-cli インストール
go install github.com/equinix-labs/otel-cli@latest
export PATH=$PATH:~/go/bin
```

**Node.js版追加要件:**
```bash
# Node.js依存関係インストール
npm install newrelic dotenv axios commander
```

### テスト実行

```bash
# 1. 純粋シェル版テスト
./call-api.sh "Pure Shell Test"

# 2. Node.js統合版テスト
node call-api-newrelic.js test
node call-api-newrelic.js send -m "Node.js Test"

# 3. OpenTelemetry版テスト
./call-api-otel.sh test
./call-api-otel.sh send "OpenTelemetry Test"
```

### New Relic確認方法

1. **New Relic One** にログイン
2. **APM & Services** に移動
3. 以下のエンティティを確認:
   - `newrelic-tracing-shell-client` (Node.js版)
   - `newrelic-tracing-otel-shell` (OpenTelemetry版)
4. **Distributed tracing** でトレース詳細を確認

---

## 🔍 TraceID検証ツール

### TraceID一致確認
```bash
# 詳細なTraceID検証テスト実行
./traceid-verification.sh

# New Relic API経由での確認（オプション）
./query-newrelic-traces.sh
```

### 検証内容
- カスタムTraceID送信
- 生成TraceID検証  
- API Gateway連携確認
- New Relic UI表示確認

---

## 🎯 どの実装を選ぶべきか？

### シンプルなテスト・CI/CD
→ **`call-api.sh`** (純粋シェル版)

### 本格的なアプリケーション監視
→ **`call-api-newrelic.js`** (Node.js統合版)

### 標準準拠・マルチベンダー対応
→ **`call-api-otel.sh`** (OpenTelemetry版)

---

## 🛠️ トラブルシューティング

### よくある問題

**1. TraceIDが表示されない**
```bash
# New Relicライセンスキー確認
echo $NEW_RELIC_LICENSE_KEY

# APIエンドポイント疎通確認
curl -I https://otlp.nr-data.net/v1/traces
```

**2. otel-cli not found**
```bash
# インストール確認
which otel-cli
# PATHに追加
export PATH=$PATH:~/go/bin
```

**3. Node.js依存関係エラー**
```bash
# 依存関係再インストール
rm -rf node_modules package-lock.json
npm install
```

### ログ出力レベル調整
```bash
# 詳細ログ出力（デバッグ用）
./call-api-otel.sh send "Debug Test" --verbose
```

---

## 📚 関連ドキュメント

- [New Relic OpenTelemetry統合](https://docs.newrelic.com/docs/opentelemetry/)
- [W3C Trace Context仕様](https://www.w3.org/TR/trace-context/)
- [otel-cli GitHub](https://github.com/equinix-labs/otel-cli)
- [New Relic Node.jsエージェント](https://docs.newrelic.com/docs/apm/agents/nodejs-agent/)

---

## 📞 サポート

問題や質問がある場合は、以下を確認してください：

1. 環境変数設定 (`.env`ファイル)
2. 依存関係インストール状況
3. New Relicライセンスキーの有効性
4. ネットワーク接続性

各実装は独立して動作するため、段階的に導入・テストが可能です。