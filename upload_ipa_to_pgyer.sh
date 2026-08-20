#!/bin/sh
if [ -z "${BASH_VERSION:-}" ]; then
  exec /bin/bash "$0" "$@"
fi

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# 蒲公英固定配置
PGYER_API_KEY="${PGYER_API_KEY:-24e363194c2e936c183d6331961780ea}"
PGYER_API_URL="${PGYER_API_URL:-https://www.pgyer.com/apiv2/app/upload}"

# 项目配置
SCHEME_NAME="${SCHEME_NAME:-JournalNote}"
TEAM_ID="${TEAM_ID:-4NX335G8BX}"
EXPORT_METHOD="${EXPORT_METHOD:-enterprise}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"

# 安装配置
PGYER_INSTALL_TYPE="${PGYER_INSTALL_TYPE:-1}"
PGYER_INSTALL_PASSWORD="${PGYER_INSTALL_PASSWORD:-}"
PGYER_UPDATE_DESCRIPTION="${PGYER_UPDATE_DESCRIPTION:-}"

# 行为控制
KEEP_BUILD_ARTIFACTS="${KEEP_BUILD_ARTIFACTS:-1}"
USE_EXISTING_IPA="${USE_EXISTING_IPA:-0}"
EXISTING_IPA_PATH="${EXISTING_IPA_PATH:-}"
AUTO_OPEN_DOWNLOAD_URL="${AUTO_OPEN_DOWNLOAD_URL:-1}"

# 构建路径
OUTPUT_DIR="$PROJECT_ROOT/build"
ARCHIVE_PATH="$OUTPUT_DIR/${SCHEME_NAME}.xcarchive"
IPA_DIR="$OUTPUT_DIR/ipa"
EXPORT_OPTIONS_PLIST="$OUTPUT_DIR/ExportOptions.plist"
ARCHIVE_LOG="$OUTPUT_DIR/archive.log"
EXPORT_LOG="$OUTPUT_DIR/export.log"

# 备份目录
CURRENT_USER="$(whoami)"
if [ -z "${MAC_SAVE_DIR:-}" ]; then
  case "$CURRENT_USER" in
    "mac")
      MAC_SAVE_DIR="${HOME}/Documents/IPA_Backup"
      ;;
    *)
      MAC_SAVE_DIR="${HOME}/Desktop/JournalNote_Archive"
      ;;
  esac
fi

TEMP_FILES=()
TEMP_DIRS=()

cleanup() {
  local file
  local dir

  for file in "${TEMP_FILES[@]:-}"; do
    [ -n "$file" ] && [ -e "$file" ] && rm -f "$file"
  done

  for dir in "${TEMP_DIRS[@]:-}"; do
    [ -n "$dir" ] && [ -e "$dir" ] && rm -rf "$dir"
  done

  if [ "$KEEP_BUILD_ARTIFACTS" != "1" ]; then
    rm -rf "$OUTPUT_DIR"
  fi
}
trap cleanup EXIT

step() {
  printf '\n▶ %s\n' "$1"
}

success() {
  printf '✅ %s\n' "$1"
}

warn() {
  printf '⚠️  %s\n' "$1"
}

fail() {
  printf '❌ %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少命令: $1"
}

require_value() {
  local value="$1"
  local field_name="$2"
  [ -n "$value" ] || fail "缺少配置: ${field_name}"
}

copy_to_clipboard() {
  local content="$1"
  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$content" | pbcopy
  fi
}

open_url() {
  local url="$1"
  if [ "$AUTO_OPEN_DOWNLOAD_URL" = "1" ] && command -v open >/dev/null 2>&1; then
    open "$url" >/dev/null 2>&1 || true
  fi
}

tail_log_or_fail() {
  local log_file="$1"
  local message="$2"
  if [ -f "$log_file" ]; then
    tail -n 80 "$log_file" || true
  fi
  fail "$message"
}

plist_get() {
  local plist_file="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :${key}" "$plist_file" 2>/dev/null || true
}

json_get() {
  local json_file="$1"
  local key_path="$2"
  python3 - "$json_file" "$key_path" <<'PY'
import json
import sys
from pathlib import Path

json_file = Path(sys.argv[1])
key_path = sys.argv[2].split('.')
with json_file.open('r', encoding='utf-8') as f:
    data = json.load(f)

value = data
for key in key_path:
    if isinstance(value, dict) and key in value:
        value = value[key]
    else:
        value = None
        break

if value is None:
    print("")
elif isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
}

prepare_existing_ipa() {
  local inspect_dir
  local ipa_app_path

  mkdir -p "$OUTPUT_DIR" "$IPA_DIR"

  if [ -n "$EXISTING_IPA_PATH" ]; then
    IPA_RAW_PATH="$EXISTING_IPA_PATH"
  else
    IPA_RAW_PATH="$(find "$PROJECT_ROOT/build" -name '*.ipa' | sort | tail -n 1)"
  fi
  [ -f "$IPA_RAW_PATH" ] || fail "未找到可复用的 IPA，请设置 EXISTING_IPA_PATH 或先导出 IPA"

  inspect_dir="$(mktemp -d)"
  TEMP_DIRS+=("$inspect_dir")
  unzip -q "$IPA_RAW_PATH" -d "$inspect_dir"

  ipa_app_path="$(find "$inspect_dir/Payload" -maxdepth 1 -name '*.app' | head -n 1)"
  [ -n "$ipa_app_path" ] || fail "无法从现有 IPA 中找到 .app 目录"

  INFO_PLIST="${ipa_app_path}/Info.plist"
}

build_and_export_ipa() {
  rm -rf "$OUTPUT_DIR"
  mkdir -p "$IPA_DIR"

  cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${EXPORT_METHOD}</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF

  step "Archive"
  xcodebuild archive \
    -workspace "${SCHEME_NAME}.xcworkspace" \
    -scheme "${SCHEME_NAME}" \
    -destination "$DESTINATION" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    > "$ARCHIVE_LOG" 2>&1 || tail_log_or_fail "$ARCHIVE_LOG" "归档失败，详见 build/archive.log"

  step "Export IPA"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -exportPath "$IPA_DIR" \
    -allowProvisioningUpdates \
    > "$EXPORT_LOG" 2>&1 || tail_log_or_fail "$EXPORT_LOG" "导出失败，详见 build/export.log"

  IPA_RAW_PATH="$(find "$IPA_DIR" -maxdepth 1 -name '*.ipa' | head -n 1)"
  [ -n "$IPA_RAW_PATH" ] || fail "导出成功但未找到 IPA 文件"

  ARCHIVE_APP_PATH="$(find "${ARCHIVE_PATH}/Products/Applications" -maxdepth 1 -name '*.app' | head -n 1)"
  [ -n "$ARCHIVE_APP_PATH" ] || fail "未找到归档后的 .app 目录"

  INFO_PLIST="${ARCHIVE_APP_PATH}/Info.plist"
}

prepare_output_ipa() {
  local timestamp

  BUILD_NUMBER="$(plist_get "$INFO_PLIST" 'CFBundleVersion')"
  VERSION="$(plist_get "$INFO_PLIST" 'CFBundleShortVersionString')"
  APP_DISPLAY_NAME="$(plist_get "$INFO_PLIST" 'CFBundleDisplayName')"
  if [ -z "$APP_DISPLAY_NAME" ]; then
    APP_DISPLAY_NAME="$(plist_get "$INFO_PLIST" 'CFBundleName')"
  fi
  [ -n "$APP_DISPLAY_NAME" ] || APP_DISPLAY_NAME="$SCHEME_NAME"

  timestamp="$(date +%Y%m%d%H%M)"
  UPLOAD_IPA_NAME="${SCHEME_NAME}_v${VERSION}_${timestamp}.ipa"
  UPLOAD_IPA_PATH="${OUTPUT_DIR}/${UPLOAD_IPA_NAME}"

  if [ "$IPA_RAW_PATH" != "$UPLOAD_IPA_PATH" ]; then
    cp "$IPA_RAW_PATH" "$UPLOAD_IPA_PATH"
  fi

  TARGET_SAVE_DIR="${MAC_SAVE_DIR}/${SCHEME_NAME}_v${VERSION}"
  mkdir -p "$TARGET_SAVE_DIR"
  cp "$UPLOAD_IPA_PATH" "${TARGET_SAVE_DIR}/${UPLOAD_IPA_NAME}"
}

upload_to_pgyer() {
  local ipa_path="$1"
  local response_json="$2"

  require_value "$PGYER_API_KEY" "PGYER_API_KEY"

  if [ -z "$PGYER_UPDATE_DESCRIPTION" ]; then
    PGYER_UPDATE_DESCRIPTION="${SCHEME_NAME} v${VERSION} (${BUILD_NUMBER})"
  fi

  local curl_args=(
    --fail-with-body
    --silent
    --show-error
    -X POST "$PGYER_API_URL"
    -F "_api_key=${PGYER_API_KEY}"
    -F "file=@${ipa_path}"
    -F "buildInstallType=${PGYER_INSTALL_TYPE}"
    -F "buildUpdateDescription=${PGYER_UPDATE_DESCRIPTION}"
  )

  if [ -n "$PGYER_INSTALL_PASSWORD" ]; then
    curl_args+=(-F "buildPassword=${PGYER_INSTALL_PASSWORD}")
  fi

  curl "${curl_args[@]}" > "$response_json"
}

parse_pgyer_response() {
  local response_json="$1"

  PGYER_CODE="$(json_get "$response_json" "code")"
  if [ "$PGYER_CODE" != "0" ]; then
    PGYER_MESSAGE="$(json_get "$response_json" "message")"
    fail "蒲公英上传失败: ${PGYER_MESSAGE} (code=${PGYER_CODE})"
  fi

  PGYER_BUILD_VERSION="$(json_get "$response_json" "data.buildVersion")"
  PGYER_BUILD_BUILD_VERSION="$(json_get "$response_json" "data.buildBuildVersion")"
  PGYER_SHORTCUT="$(json_get "$response_json" "data.buildShortcutUrl")"
  PGYER_QR_CODE_URL="$(json_get "$response_json" "data.buildQRCodeURL")"

  if [ -n "$PGYER_SHORTCUT" ]; then
    PGYER_DOWNLOAD_URL="https://www.pgyer.com/${PGYER_SHORTCUT}"
  else
    PGYER_DOWNLOAD_URL=""
  fi
}

build_summary() {
  cat <<EOF
【${SCHEME_NAME} v${VERSION}】
版本号：${BUILD_NUMBER}
下载地址：${PGYER_DOWNLOAD_URL}
二维码：${PGYER_QR_CODE_URL}
EOF
}

require_command xcodebuild
require_command curl
require_command python3
require_command unzip
require_executable /usr/libexec/PlistBuddy

cd "$PROJECT_ROOT"

step "校验项目信息"
SETTINGS="$(xcodebuild -showBuildSettings \
  -workspace "${SCHEME_NAME}.xcworkspace" \
  -scheme "${SCHEME_NAME}" \
  -configuration Release 2>/dev/null)"

BUNDLE_ID="$(printf '%s\n' "$SETTINGS" | grep 'PRODUCT_BUNDLE_IDENTIFIER' | grep -v ' = NO' | head -1 | awk '{print $3}')"
[ -n "$BUNDLE_ID" ] || fail "无法解析 PRODUCT_BUNDLE_IDENTIFIER"
success "包名 ${BUNDLE_ID}"

if [ "$USE_EXISTING_IPA" = "1" ]; then
  step "准备现有 IPA"
  prepare_existing_ipa
  success "已复用现有 IPA"
else
  step "构建 IPA"
  build_and_export_ipa
  success "构建与导出完成"
fi

step "整理产物"
prepare_output_ipa
success "IPA 已就绪: ${UPLOAD_IPA_PATH}"
success "已备份到: ${TARGET_SAVE_DIR}/${UPLOAD_IPA_NAME}"

step "上传蒲公英"
PGYER_RESPONSE_JSON="$(mktemp)"
TEMP_FILES+=("$PGYER_RESPONSE_JSON")

upload_to_pgyer "$UPLOAD_IPA_PATH" "$PGYER_RESPONSE_JSON"
parse_pgyer_response "$PGYER_RESPONSE_JSON"

success "蒲公英上传成功"
success "版本：${PGYER_BUILD_VERSION} (${PGYER_BUILD_BUILD_VERSION})"
success "下载地址：${PGYER_DOWNLOAD_URL}"

SUMMARY_CONTENT="$(build_summary)"
copy_to_clipboard "$SUMMARY_CONTENT"
open_url "$PGYER_DOWNLOAD_URL"

step "完成"
success "脚本执行结束"
