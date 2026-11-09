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

## メニュー表示の追加調査（2026-11-09 継続）

区切り線だけを削除する試験では表示が変わらなかったため、`Resource/ffftp.ja-JP.rc` と `Resource/ffftp.en-US.rc` は公式v5.8へ戻した。

一時的に `toolmenu.cpp` に `[MENU-DIAG]` の読み取り専用ログを追加し、最初に開くリモート右クリックメニューの**項目ID・種類／状態・文字数**および外部ビューア設定の有無・文字数を記録する。メニューの実行・通信・ユーザー設定は変更しない。原因確認後、この診断コードは除去する。コマンド：`git pull --ff-only origin fix/ftpes-close-notify-v58`、`Build-And-Run.cmd`、リモートファイルを右クリック、ログの `[MENU-DIAG]` の行だけを提出する。

## メニュー診断2（2026-11-09）

最初の右クリック結果ではビューアー2（ID 40112）と3（ID 40113）が設定ありなのに表示文字数0だった。原因は**メニューへ挿入する直前に空文字ができたのか、それともWindows APIへの挿入後に文字がなくなったのか**で切り分ける。表示される文字列・ローカルのパス・認証情報はログに出さない。リモート側を右クリックし、`[MENU-DIAG] build viewer=` の3行を確認する。今回もメニュー文字や操作は変更しない。

## メニュー空白の原因と防御（2026-11-09）

診断でビューアー2・3（設定文字数39）が空文字ではなく、生成された表示文字列46文字の**先頭がヌル文字（U+0000）**であることを確認した。Win32はメニュー挿入APIを成功と返すが、表示文字列長は0と認識する。ビューアー1（notepad）は正常。ヌル文字の混入元が保存済み設定かパス加工かは診断ログだけでは未確定。

`toolmenu.cpp` では**設定値・抽出したファイル名・生成した表示文字列**の各段階でヌル文字と空文字を検出し、不正な項目をメニューへ挿入しない防御を追加した。以前の詳細診断ログを削除し、異常時のみ `[MENU-VALIDATION]` でスロット番号と失敗段階を記録する。パス名・ファイル名や認証情報は出さない。ユーザーのビューアー設定は自動で書き換えない。ビューアー2・3を利用したい場合はオプションの外部ビューアー設定から実行ファイルを選び直して保存する。TLSコードは不変。

実機確認：ロリポップ/Xserverの一覧・転送、右クリックで空白が消えたか、`[MENU-VALIDATION]` が出た場合はその該当行だけ記録。今回のコードは**Windows実ビルド・動作未検証**。
