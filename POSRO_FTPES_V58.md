# Posro FFFTP v5.8 — FTPES receive-side fix

## 正本と変更範囲

- ベース：公式 `ffftp/ffftp` のタグ `v5.8`、コミット `731e2259e3709d46a1a204eb949975edb8646aa3`
- 所有：`posro-dev/ffftp`
- 開発ブランチ：`fix/ftpes-close-notify-v58`
- **公式 `master`、通常版FFFTP、既存のINIは変更しない**
- ソース差分：`common.h`、`getput.cpp`、`socket.cpp` の受信データ接続TLS終了処理と、`common.h`、`connect.cpp`、`statuswin.cpp`、`toolmenu.cpp`、`ffftp.vcxproj` のMSVC v143互換修正。合計7ファイル、+24/-14行（導入時点）。

## なぜ直したか

ロリポップのFTPESで制御接続・ログイン・PASVデータ接続は成功するのに、`LIST` 後に一覧取得が失敗した。

BaselineのSchannel詳細ログでは、受信データ接続のTLSハンドシェイクが成功し1,781バイトの一覧を復号したあと、`DecryptMessage` が `SEC_I_CONTEXT_EXPIRED` を返していた。FFFTP v5.8の `AttachSSL` は、この終了状態をTLS初期化失敗と扱っていた。

このブランチは、**受信用データ接続のみ**、TLSハンドシェイク完了後の `SEC_I_CONTEXT_EXPIRED` を正常なEOFとして認め、復号済みデータを失わないようにする。TLS証明書検証を除外しない。別のSchannelステータスを一律に成功扱いしない。アップロードの接続動作は元のまま。さらに、`QueryContextAttributesW` の結果で`sslReadStatus`を上書きしないようにする。

## すでに実施した実機検証（移行前のCandidate/修復版）

- Baselineで不具合を再現。
- Candidateでロリポップの一覧取得10回連続成功。
- 30MB動画のアップロードとダウンロードが成功し、SHA-256一致。
- Xserver接続・操作で問題報告なし。
- 監査用ソースのSHA-256、日英MUIの配置はチェックPASS。

**GitHubに再構成したこのブランチの新規ビルドは、まだWindows実機の回帰テスト前。** 旧版のテスト結果を新規ビルドの実績として扱わないこと。

## Windowsでの使用

前提：Git、Visual Studio 2026 Community、MSVC v143、Windows SDK。

```powershell
Set-Location "$HOME\Documents\GitHub"
git clone --branch fix/ftpes-close-notify-v58 --recurse-submodules https://github.com/posro-dev/ffftp.git ffftp
Set-Location .\ffftp
.\Build-And-Run.cmd
```

ビルド後に`Release\x64\ffftp.exe`をMUI同梱の元の名前のまま起動する。再ビルド不要の場合は`Build-And-Run.cmd -NoBuild`。

設定ファイルはリポジトリ外の `%LOCALAPPDATA%\Posro\FFFTP-v58\ffftp.ini` に保存する。過去のINIや認証情報は自動で持ち込まない。秘密情報・EXE・ログはGitに登録しない。

## 最終QA（このブランチのビルドに対して実施）

1. Windows Release x64ビルドが成功し、日本語UI・右クリックメニューが表示される。
2. ロリポップで一覧取得10回、フォルダ移動、30MB程度の送受信、SHA-256一致。
3. Xserverで一覧表示・転送を確認。
4. メニューの大きな空白は現時点で未解決。TLS修正とは別に調査する。
5. Release x64のPREfast静的解析は現在無効。原本の`ftpproc.cpp`のC6240警告への対応・再有効化は別課題。

合格前に通常版や過去の動作済みCandidateを削除しない。古いZIPや診断フォルダの削除は新規ビルドの実機確認後に実施する。

## 右クリックメニューの余白の比較（2026-11-09）

Windows環境で「開く／外部ビューアで開く」とダウンロード・アップロードの間に大きな空白が見えるとの報告あり。日本語・英語MUIの `popup_menu` 内の最初の区切り線（ローカル／リモート各1件）だけを外した。メニュー項目やコマンドID、`toolmenu.cpp`、TLS処理は不変。これは**レイアウトの試験修正**であり、実機で改善するかは未検証。改善しなければ原本との比較・Win32メニュー項目のランタイム列挙を行う。
