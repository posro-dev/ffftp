# Posro FFFTP 5.8 — FTPES修正版・運用正本

更新：2026-11-10。**コードの機能変更はここでいったん凍結し、以後は根拠のある不具合修正のみ。**

## ソース正本

| 項目 | 内容 |
| --- | --- |
| 正本 | `posro-dev/ffftp` |
| ブランチ | `fix/ftpes-close-notify-v58` |
| 公式基準 | `ffftp/ffftp` タグ `v5.8`（`731e2259e3709d46a1a204eb949975edb8646aa3`） |
| 動作確認後のコードコミット | `83afc47204a54d0fba402e98d7f2d58e03f80736` |
| Windowsの管理先 | `%USERPROFILE%\Documents\GitHub\ffftp` |
| EXE | `Release\x64\ffftp.exe`（隣接する`ja-JP\ffftp.exe.mui`も必要） |
| 現行設定 | `%LOCALAPPDATA%\Posro\FFFTP-v58\ffftp.ini` |
| バックアップ | `%LOCALAPPDATA%\Posro\FFFTP-v58\backup\` |

`master` はフォーク元を追跡するためのブランチとして保持し、修正版を無理に統合しない。古いWork/診断ZIP、作業ツリー、EXE、INI、認証情報はGitHubの正本にはしない。

## 変更した内容

公式v5.8のソースを基準に変更対象は**8ファイル**。`common.h`、`connect.cpp`、`ffftp.vcxproj`、`getput.cpp`、`socket.cpp`、`statuswin.cpp`、`toolmenu.cpp`、`registry.cpp`。

1. **FTPES受信データ接続**：Schannelで最後の復号済みLISTデータと`SEC_I_CONTEXT_EXPIRED`（TLS close_notify）が同じ処理で到着した場合の扱いを修正。正常完了した受信ハンドシェイクだけが対象。証明書検証は維持し、送信側の動作は変えない。`QueryContextAttributesW`の結果で既存TLS状態を上書きしない。
2. **MSVC v143互換**：一時オブジェクトを受け付けない`std::make_wformat_args`などへの対応。Release x64の静的解析`EnablePREfast`は、未対応の既存`C6240`警告のため無効のまま。
3. **INIの空文字とNUL**：`registry.cpp`のスカラー設定文字列を最初のNULで切り詰める。 `Viewer2=`のような空の値も読み込めるよう、`IniConfig::Scan`の長さ条件を修正。
4. **メニュー**：試験的なリソース区切り線変更・診断ログ・暫定ガードは撤去済み。日本語／英語の右クリックメニューリソースは公式v5.8と同一。最終メニュー処理はMSVC互換用の1行のみ変更。

過程の試行錯誤はGit履歴で確認できるが、現行ソースに診断コードや一時的なメニュー改変は残していない。

## 原因と検証

### FTPES

- ロリポップでFTPESログイン、PASV、`150 Opening ASCII mode data connection` までは成功するが、LIST受信直後に失敗する現象を再現。
- 詳細ログでTLSハンドシェイク完了、1,781バイト復号、`SEC_I_CONTEXT_EXPIRED`の並びを確認。
- 旧診断CandidateでロリポップLIST **10/10成功**。30MB動画の送受信が成功し、SHA-256一致。
- GitHubで作り直した修正版も、ユーザーによるWindowsビルドとロリポップ接続が成功。Xserverでの接続・操作も問題報告なし。

### 右クリックメニュー

- 診断時、ビューアー2/3は画面上空欄でも、内部で長さ39、生成メニューラベル長46、先頭コードポイントU+0000。Win32メニュー上は表示文字数0だった。
- ビューアー2/3に`notepad`を入れると正常な表示に置換。空欄に戻すと再発。
- `registry.cpp`のNUL／空値処理の修正後、ユーザーが**右クリックの空白が出ないことを確認**（2026-11-10）。
- この結果は表示の初回確認に基づく。再起動をまたぐ設定保持・全接続先での再転送は未報告なので、必要な場合は追加確認する。

## Windows運用（既存Cloneの場合）

新規にCloneし直す必要なし。FFFTPを通常終了してから以下を実行。

```powershell
Set-Location "$HOME\Documents\GitHub\ffftp"
git pull --ff-only origin fix/ftpes-close-notify-v58
if ($LASTEXITCODE -ne 0) { throw "Git pull failed" }
.\Build-And-Run.cmd
```

単に既存EXEを起動するなら `Build-And-Run.cmd -NoBuild`。ビルド時に同じEXEが起動中なら、安全のため停止する仕様。強制終了させない。

## クリーンアップの原則

**残す**

- `%USERPROFILE%\Documents\GitHub\ffftp`（`.git`・サブモジュール・ソース・EXE・MUIを含む）
- `%LOCALAPPDATA%\Posro\FFFTP-v58\ffftp.ini` と `backup`
- 通常版FFFTPを残す場合はそのインストール先・設定

**削除してよい候補（Windows上で存在を確認してから）**

- `%USERPROFILE%\Documents\Codex\2026-11-06\ffftp-5-8-ftpes-ffftp-5`（Workの過去診断プロジェクト）
- `Downloads`内の旧検証ZIP：`ffftp-5-8-ftpes-ffftp-5.zip`、`FFFTP_v58_fixed_candidate_kit.zip`、`FFFTP_v58_fixed_candidate_kit_v2.zip`、`FFFTP_v58_v2_TLS_EOF_hotfix.zip`、`FFFTP_v58_source_audit_rc.zip`
- その他の`ffftp`関連フォルダは、自動で削除対象に追加せず、内容と場所を確認して個別判断する。

削除前に**現行INI・EXE・日本語MUIをリポジトリ外にバックアップ**し、バックアップを確認する。旧作業環境の設定ファイルに秘密情報が入っている可能性があるため、GitHubに上げたりログの全文を共有したりしない。`git clean`や`Remove-Item`で正本ディレクトリ全体を消さない。

## 継続監査事項

- Release x64のPREfast静的解析の再有効化・既存`C6240`警告対処は未完了。
- この修正をすべてのFTPESサーバーで安全と保証したものではない。
- デフォルトのマスターパスワード利用警告が残る環境では、別途固有マスターパスワードの設定を推奨。

今後はこの文書と修正ブランチを参照し、古い診断キットを前提に作業しない。
