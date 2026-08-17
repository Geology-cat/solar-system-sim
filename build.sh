#!/bin/bash
#
# 太陽系シミュレーター ビルドスクリプト
#
# macOS Sierra (10.12) から最新の macOS まで、単一のユニバーサルバイナリで動く
# .app を組み立てる。
#
#   x86_64 スライス … デプロイメントターゲット 10.12 (Sierra 以降の Intel Mac)
#   arm64  スライス … デプロイメントターゲット 11.0 (Apple Silicon)
#
# 10.14.4 より前の macOS には Swift 5 のランタイムが同梱されていないため、
# Xcode に付属する後方互換ライブラリ (swift-5.0 / swift-5.5) を .app 内に同梱し、
# rpath で「OS 側にあればそれを、無ければ同梱版を」使うようにする。
#
# 使い方:
#   ./build.sh          … ビルドして dist/SolarSystemSim.app を作る
#   ./build.sh run      … ビルドして起動する
#   ./build.sh verify   … 軌道計算の検証ツールを実行する
#   ./build.sh clean    … 生成物を消す

set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="SolarSystemSim"
DISPLAY_NAME="太陽系シミュレーター"
BUILD_DIR="build"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"

X86_TARGET="x86_64-apple-macosx10.12"
ARM_TARGET="arm64-apple-macosx11.0"

if [ "${1:-}" = "clean" ]; then
    rm -rf "${BUILD_DIR}" "${DIST_DIR}"
    echo "生成物を削除しました。"
    exit 0
fi

SOURCES=(Sources/*.swift)

TOOLCHAIN_LIB="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib"

# --- 検証ツール ---
# Sources/ の実装をそのままリンクするので、検証用の書き写しが本体とずれない。
# main.swift だけはエントリポイントが衝突するため差し替える。
if [ "${1:-}" = "verify" ]; then
    mkdir -p "${BUILD_DIR}"
    VERIFY_SOURCES=()
    for f in "${SOURCES[@]}"; do
        [ "$(basename "$f")" = "main.swift" ] && continue
        VERIFY_SOURCES+=("$f")
    done
    echo "==> 検証ツールをビルド"
    swiftc -swift-version 5 -O \
        -o "${BUILD_DIR}/verify-tool" \
        "${VERIFY_SOURCES[@]}" Tools/verify/main.swift
    echo ""
    exec "${BUILD_DIR}/verify-tool"
fi

echo "==> ソース: ${#SOURCES[@]} ファイル"
mkdir -p "${BUILD_DIR}"

# --- 各アーキテクチャをコンパイル ---
# -swift-version 5 を明示する。Swift 6 の並行性チェックは 10.15 未満へ
# 後方展開できない機能に依存するため、このアプリでは 5 モードで通す。
build_slice() {
    local target="$1"
    local out="$2"
    echo "==> コンパイル: ${target}"
    swiftc \
        -target "${target}" \
        -swift-version 5 \
        -O \
        -o "${out}" \
        "${SOURCES[@]}"
}

build_slice "${X86_TARGET}" "${BUILD_DIR}/${APP_NAME}-x86_64"

# Apple Silicon 用スライスは SDK が対応していれば作る
if build_slice "${ARM_TARGET}" "${BUILD_DIR}/${APP_NAME}-arm64" 2>/dev/null; then
    HAS_ARM=1
else
    echo "!! arm64 スライスのビルドに失敗しました。x86_64 のみで続行します"
    echo "   (Apple Silicon では Rosetta 2 経由で動作します)"
    HAS_ARM=0
fi

# --- ユニバーサルバイナリに結合 ---
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources" "${APP_BUNDLE}/Contents/Frameworks"

if [ "${HAS_ARM}" = "1" ]; then
    echo "==> lipo でユニバーサル化 (x86_64 + arm64)"
    lipo -create \
        "${BUILD_DIR}/${APP_NAME}-x86_64" \
        "${BUILD_DIR}/${APP_NAME}-arm64" \
        -output "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
else
    cp "${BUILD_DIR}/${APP_NAME}-x86_64" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
fi

# --- Swift ランタイムの後方互換ライブラリを同梱 ---
# 10.14.4 未満には OS 内に Swift ランタイムが無いので、これが無いと起動しない。
echo "==> Swift 後方互換ライブラリを同梱"
for libdir in "${TOOLCHAIN_LIB}/swift-5.0/macosx" "${TOOLCHAIN_LIB}/swift-5.5/macosx"; do
    if [ -d "${libdir}" ]; then
        cp -f "${libdir}"/*.dylib "${APP_BUNDLE}/Contents/Frameworks/" 2>/dev/null || true
    fi
done

# rpath は OS 標準の /usr/lib/swift を先に探し、
# 見つからない古い OS でだけ同梱版へ落ちるようにする。
install_name_tool -add_rpath "/usr/lib/swift" \
    "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
install_name_tool -add_rpath "@executable_path/../Frameworks" \
    "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

# --- リソース ---
cp Resources/Info.plist "${APP_BUNDLE}/Contents/Info.plist"
printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

if [ -d Resources/AppIcon.iconset ]; then
    echo "==> アイコンを生成"
    iconutil -c icns Resources/AppIcon.iconset \
        -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# --- 署名 ---
# 配布用の署名鍵は前提にしない。ad-hoc 署名にしておくと
# Apple Silicon で「壊れているため開けません」と言われるのを避けられる。
echo "==> ad-hoc 署名"
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || \
    echo "!! 署名に失敗しました (署名なしのまま続行)"

echo ""
echo "完成: ${APP_BUNDLE}"
lipo -info "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
vtool -show-build "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null \
    | grep -E 'architecture|minos|platform' || true

if [ "${1:-}" = "run" ]; then
    echo ""
    echo "==> 起動"
    open "${APP_BUNDLE}"
fi
