# Antigravity × Claude Code Orchestrator（日本語ガイド）

[English README](./README.md)

**Google Antigravity（Gemini 4 Neon）** を指揮官（リードアーキテクト／オーケストレーター）とし、ローカルの **公式 Claude Code CLI（Claude Opus 5.5 / Sonnet 5.5）** および Antigravity ネイティブのサブエージェントを協調させるためのグローバルスキルです。

OAuth トークンの抜き出しや非公式プロキシハーネスを一切使わず、**Google AI Pro / Ultra と Claude Max / Pro のサブスクリプション枠内で安全に運用**できるように設計されています。

---

## 主な特徴

* **1M コンテキストを活かした指揮（Gemini 4 Neon）**
  リポジトリ全体や仕様書の把握は Neon が担い、Claude Code には「対象ファイル＋要件＋完了条件」だけを簡潔に渡すことで、Claude 側の利用枠消費を最小限に抑えます。
* **サブスクリプション保護ブリッジ（`claude-bridge.ps1` / `claude-bridge.sh`）**
  * 未改変の公式 `claude` バイナリをローカルで直接呼び出します。
  * 実行時に `ANTHROPIC_API_KEY` を一時クリアし、意図しない従量課金 API へのフォールバックを防止します。
  * `-ReadOnly` / `--read-only` オプションにより、書き込み不可の安全なクロスモデル・コードレビューが可能です。
* **双方向・複数ターンのセッション継続**
  Claude Code が返す `session_id` を自動回収し、`--resume` で同一会話を継続できるため、Neon ↔ Claude Code 間での設計議論やテスト失敗の差し戻しがスムーズに行えます。
* **GUI でのやり取り可視化**
  * Antigravity アプリ内の Artifacts パネルに `orchestration-board.md` を出力・更新します。
  * プロジェクト内の `.orchestration/dashboard.html` をブラウザで開くだけで、Neon（左）↔ Claude Code（右）のやり取り・モデル・応答時間・セッションIDをチャット画面風に確認できます（オフラインの `file://` でもそのまま動作）。
* **クロスプラットフォーム対応**
  Windows（PowerShell）と macOS / Linux（Bash）の両方に対応しています。

---

## 前提条件

1. **Google Antigravity**（アプリ / IDE / `agy` CLI）で Gemini 4 Neon が利用できること
2. **公式 Claude Code CLI** がインストールされ、サブスクリプションでログイン済みであること：
   ```bash
   claude auth status
   # 未ログインの場合
   claude auth login
   ```
   > **補足**: `claude-opus-5-5` を明示指定するには Claude Code CLI `2.1.280` 以上（`claude update`）が必要です。旧バージョンでは `-Model default` / `--model default` を指定してください。
3. *(macOS / Linux のみ)* `python3` が利用可能であること

---

## インストール方法

### Windows (PowerShell)
```powershell
git clone https://github.com/rtonf/antigravity-claude-orchestrator.git
cd antigravity-claude-orchestrator
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### macOS / Linux
```bash
git clone https://github.com/rtonf/antigravity-claude-orchestrator.git
cd antigravity-claude-orchestrator
bash ./install.sh
```

グローバルスキルディレクトリ `~/.gemini/config/skills/neon-claude-orchestrator/` に配置され、どのワークスペースを開いても自動的に認識されます。

---

## 使い方

1. Antigravity で対象プロジェクトのフォルダを開く。
2. モデルを **Gemini 4 Neon** に設定する。
3. 最初のメッセージで以下のように依頼します：

```text
neon-claude-orchestrator スキルを使ってこのプロジェクトを進めたい。
【プロジェクト概要】
（作りたいもの・技術スタック・制約条件を書く）

まずは全体設計とタスク分解を行い、orchestration-board.md と .orchestration/dashboard.html をセットアップしてから進めて。
```

> **初回実行時のヒント**: `claude` CLI はネットワークと `~/.claude` へのアクセスが必要なため、初回呼び出し時にサンドボックス外実行の確認ダイアログが表示されます。**「Always Allow（常に許可）」** を選ぶと、次回以降はスムーズに自動オーケストレーションが回ります。

---

## ライセンス

[MIT](./LICENSE)
