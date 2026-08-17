--------------------------------------------------------------------
--  太陽系シミュレーター  かんたんインストーラ
--------------------------------------------------------------------
--
--  【使い方】
--    このウインドウ上部の「実行」（▶）ボタンを押すだけです。
--    （キーボードなら command + R）
--
--    アプリケーションフォルダへのコピー、Gatekeeper の解除、
--    起動まで、まとめて行います。
--    先に手動でドラッグしておく必要はありません。
--
--  【このスクリプトがすること】
--    1. SolarSystemSim.app を「アプリケーション」フォルダへコピーする
--    2. アプリに付いた「隔離属性」(com.apple.quarantine) を取り除く
--    3. アプリを起動する
--
--    インターネット経由で受け取ったアプリには macOS がこの隔離属性を付けます。
--    本アプリは Apple の開発者証明書による署名・公証を受けていないため、
--    この印が付いたままではダブルクリックで開けません。
--
--    取り除くのはこのアプリに付いた印だけです。
--    システムのセキュリティ設定は一切変更しませんし、
--    他のアプリの扱いにも影響しません。
--
--  【なぜ「実行」を押す必要があるのか】
--    ダブルクリックだけで自動的に処理を済ませる形式
--    （アプレット形式の .app や .command）にすると、
--    そのファイル自体が Gatekeeper に止められてしまい、
--    かえって手順が増えます。
--    スクリプトエディタで開いて「実行」を押す形式は、
--    Apple が署名したスクリプトエディタが処理を代行するため、
--    この堂々巡りを避けられる唯一の方法です。
--
--------------------------------------------------------------------

property appFileName : "SolarSystemSim.app"
property appDisplayName : "太陽系シミュレーター"
property installedPath : "/Applications/SolarSystemSim.app"

on run
	-- 1. コピー元（配布ディスクイメージ上のアプリ）を探す
	set sourcePath to findSourceApp()

	-- 2. インストール済みかどうかで分岐する
	set alreadyInstalled to pathExists(installedPath)

	if sourcePath is missing value and not alreadyInstalled then
		-- どこにも見つからない。利用者に選んでもらう。
		set sourcePath to askForApplication()
		if sourcePath is missing value then return
	end if

	if sourcePath is not missing value and sourcePath is not installedPath then
		if alreadyInstalled then
			set answer to display dialog ¬
				appDisplayName & " はすでにインストールされています。" & return & return & ¬
				"新しいものに置き換えますか？" ¬
				with title appDisplayName ¬
				buttons {"やめる", "そのまま解除", "置き換える"} ¬
				default button "置き換える" with icon note
			if button returned of answer is "やめる" then return
			if button returned of answer is "置き換える" then
				if not installApp(sourcePath) then return
			end if
		else
			if not installApp(sourcePath) then return
		end if
	end if

	if not pathExists(installedPath) then
		reportError("アプリケーションフォルダに " & appFileName & " が見つかりません。")
		return
	end if

	-- 3. 隔離属性を取り除く
	if not runPrivileged("/usr/bin/xattr -dr com.apple.quarantine " & ¬
		quoted form of installedPath, "隔離属性の解除") then
		return
	end if

	-- 4. 起動する
	set answer to display dialog ¬
		"準備ができました。" & return & return & ¬
		appDisplayName & " をアプリケーションフォルダにインストールし、" & ¬
		"Gatekeeper の隔離属性を解除しました。" & return & return & ¬
		"今すぐ起動しますか？" ¬
		with title appDisplayName ¬
		buttons {"あとで", "起動する"} default button "起動する" with icon note

	if button returned of answer is "起動する" then
		try
			do shell script "/usr/bin/open " & quoted form of installedPath
		on error errMsg
			reportError("起動できませんでした。" & return & return & errMsg)
		end try
	end if
end run

--------------------------------------------------------------------
--  コピー元のアプリを探す
--------------------------------------------------------------------
--  マウント済みのディスクイメージ上を最優先で見る。
--  （このスクリプトは配布ディスクイメージに同梱されているため）
--
--  スクリプトエディタで実行しているときの `path to me` は
--  スクリプトエディタ自身を指してしまうので当てにできない。
--  そのため /Volumes 以下を実際に探しにいく。
on findSourceApp()
	try
		set found to do shell script ¬
			"/bin/ls -d /Volumes/*/" & appFileName & " 2>/dev/null | /usr/bin/head -1"
		if found is not "" then return found
	end try

	-- osascript から直接動かした場合はスクリプトの隣も見る
	try
		set myFolder to POSIX path of ((path to me as text) & "::")
		set candidate to myFolder & appFileName
		if pathExists(candidate) then return candidate
	end try

	return missing value
end findSourceApp

--  利用者にアプリ本体を選んでもらう
on askForApplication()
	set answer to display dialog ¬
		appFileName & " が見つかりません。" & return & return & ¬
		"配布ディスクイメージ（.dmg）を開いた状態で、もう一度このスクリプトを実行してください。" & return & return & ¬
		"手元にアプリがある場合は「場所を選ぶ」を押してください。" ¬
		with title appDisplayName ¬
		buttons {"やめる", "場所を選ぶ"} default button "やめる" with icon caution

	if button returned of answer is not "場所を選ぶ" then return missing value

	try
		set chosen to choose file of type {"com.apple.application-bundle"} ¬
			with prompt appDisplayName & " の本体（" & appFileName & "）を選んでください"
		return POSIX path of chosen
	on error number -128
		return missing value
	end try
end askForApplication

--------------------------------------------------------------------
--  アプリケーションフォルダへコピーする
--------------------------------------------------------------------
on installApp(sourcePath)
	-- 置き換えのときは先に古いものを消す。ditto は差分を残すことがあるため。
	if pathExists(installedPath) then
		if not runPrivileged("/bin/rm -rf " & quoted form of installedPath, ¬
			"古いバージョンの削除") then return false
	end if

	return runPrivileged("/usr/bin/ditto " & quoted form of sourcePath & " " & ¬
		quoted form of installedPath, "アプリケーションフォルダへのコピー")
end installApp

--------------------------------------------------------------------
--  共通のヘルパー
--------------------------------------------------------------------
--  まず通常の権限で試し、失敗したら管理者権限で再試行する
on runPrivileged(cmd, whatFailed)
	try
		do shell script cmd
		return true
	on error
		try
			do shell script cmd with administrator privileges
			return true
		on error errMsg number errNum
			if errNum is -128 then return false -- 利用者が取り消した
			reportError(whatFailed & "に失敗しました。" & return & return & errMsg)
			return false
		end try
	end try
end runPrivileged

on pathExists(posixPath)
	try
		do shell script "/bin/test -e " & quoted form of posixPath
		return true
	on error
		return false
	end try
end pathExists

on reportError(message)
	display dialog message with title appDisplayName ¬
		buttons {"OK"} default button 1 with icon stop
end reportError
