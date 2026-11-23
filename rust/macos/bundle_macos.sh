#!/usr/bin/env bash
set -euo pipefail

# Empacota o executável compilado do PIT em um bundle macOS (PIT.app) + imagem PIT-macOS.dmg
# Uso: ./rust/macos/bundle_macos.sh [caminho-do-binario]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_PATH="${1:-$RUST_DIR/target/release/compartilhador-de-tela}"
OUT_DIR="$RUST_DIR/target/macos-bundle"
APP_DIR="$OUT_DIR/PIT.app"
LOGO_PNG="$RUST_DIR/crates/ct-app/assets/logo.png"

if [[ ! -f "$BIN_PATH" ]]; then
    echo "Erro: binário não encontrado em $BIN_PATH" >&2
    exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/compartilhador-de-tela"
chmod +x "$APP_DIR/Contents/MacOS/compartilhador-de-tela"
cp "$SCRIPT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

# Gera PIT.icns a partir de logo.png usando sips + iconutil (nativos do macOS)
if command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
    ICONSET_DIR="$OUT_DIR/PIT.iconset"
    mkdir -p "$ICONSET_DIR"
    sips -z 16 16     "$LOGO_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
    sips -z 32 32     "$LOGO_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
    sips -z 32 32     "$LOGO_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
    sips -z 64 64     "$LOGO_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
    sips -z 128 128   "$LOGO_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
    sips -z 256 256   "$LOGO_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
    sips -z 256 256   "$LOGO_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
    sips -z 512 512   "$LOGO_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
    sips -z 512 512   "$LOGO_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
    cp "$LOGO_PNG" "$ICONSET_DIR/icon_512x512@2x.png"
    iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/PIT.icns"
    rm -rf "$ICONSET_DIR"
fi

# Garante que /usr/lib/swift esteja no rpath do binário (para libswift_Concurrency.dylib do ScreenCaptureKit)
if command -v install_name_tool >/dev/null 2>&1; then
    install_name_tool -add_rpath /usr/lib/swift "$APP_DIR/Contents/MacOS/compartilhador-de-tela" 2>/dev/null || true
fi

# Assinatura ad-hoc para que o macOS Gatekeeper e o TCC (ScreenCaptureKit) identifiquem o bundle de forma consistente
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR"
fi

# Cria um arquivo .zip preservando symlinks/permissões e um .dmg pronto para enviar
(
    cd "$OUT_DIR"
    ditto -c -k --sequesterRsrc --keepParent "PIT.app" "PIT-macOS-Universal.zip"
)

if command -v hdiutil >/dev/null 2>&1; then
    DMG_STAGE="$OUT_DIR/dmg-stage"
    mkdir -p "$DMG_STAGE"
    cp -R "$APP_DIR" "$DMG_STAGE/PIT.app"
    ln -s /Applications "$DMG_STAGE/Applications"
    hdiutil create -volname "PIT" -srcfolder "$DMG_STAGE" -ov -format UDZO "$OUT_DIR/PIT-macOS-Universal.dmg" >/dev/null
    rm -rf "$DMG_STAGE"
fi

echo "Bundle macOS gerado em: $OUT_DIR"
ls -lh "$OUT_DIR"
