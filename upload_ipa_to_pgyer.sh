#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
WORKSPACE_PATH="$PROJECT_ROOT/JournalNote.xcworkspace"
SCHEME="${JOURNALNOTE_SCHEME:-JournalNote}"
CONFIGURATION="${JOURNALNOTE_CONFIGURATION:-Release}"
TEAM_ID="${JOURNALNOTE_TEAM_ID:-4NX335G8BX}"
PGYER_API_URL="${PGYER_API_URL:-https://www.pgyer.com/apiv2/app/upload}"
# 蒲公英凭证（按需求写入脚本；环境变量可临时覆盖）
PGYER_API_KEY="${PGYER_API_KEY:-24e363194c2e936c183d6331961780ea}"
PGYER_USER_KEY="${PGYER_USER_KEY:-a44e1b634edbb5453470d8d8eb113330}"
KEYCHAIN_SERVICE="com.yolanda.JournalNote.pgyer"
API_KEY_ACCOUNT="api_key"
USER_KEY_ACCOUNT="user_key"

usage() {
  echo "用法："
  echo "  $0 --configure              将蒲公英密钥保存到 macOS 钥匙串"
  echo "  $0                          自动归档、导出企业 IPA 并上传"
  echo "  $0 --ipa /path/to/app.ipa   上传已有 IPA，跳过构建"
  echo ""
  echo "可选环境变量："
  echo "  PGYER_API_KEY                蒲公英 API Key（优先于钥匙串）"
  echo "  PGYER_USER_KEY               蒲公英 User Key（兼容旧账号，可不填）"
  echo "  PGYER_UPDATE_DESCRIPTION     版本更新说明"
  echo "  PGYER_INSTALL_TYPE           安装方式：1公开，2密码，3邀请；默认1"
  echo "  PGYER_INSTALL_PASSWORD       PGYER_INSTALL_TYPE=2 时的安装密码"
  echo "  JOURNALNOTE_TEAM_ID          企业开发团队 ID，默认 $TEAM_ID"
}

save_secret() {
  local account="$1"
  local value="$2"
  security add-generic-password \
    -U \
    -s "$KEYCHAIN_SERVICE" \
    -a "$account" \
    -w "$value" >/dev/null
}

read_secret() {
  local account="$1"
  security find-generic-password \
    -s "$KEYCHAIN_SERVICE" \
    -a "$account" \
    -w 2>/dev/null || true
}

configure_credentials() {
  local api_key
  local user_key

  read -r -s -p "请输入蒲公英 API Key：" api_key
  echo ""
  if [ -z "$api_key" ]; then
    echo "错误：API Key 不能为空。" >&2
    exit 1
  fi

  read -r -s -p "请输入蒲公英 User Key（可留空）：" user_key
  echo ""

  save_secret "$API_KEY_ACCOUNT" "$api_key"
  if [ -n "$user_key" ]; then
    save_secret "$USER_KEY_ACCOUNT" "$user_key"
  fi
  echo "蒲公英密钥已安全保存到 macOS 钥匙串。"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "错误：找不到命令 $1。" >&2
    exit 1
  fi
}

create_export_options() {
  local path="$1"
  plutil -create xml1 "$path"
  /usr/libexec/PlistBuddy -c "Add :method string enterprise" "$path"
  /usr/libexec/PlistBuddy -c "Add :signingStyle string automatic" "$path"
  /usr/libexec/PlistBuddy -c "Add :teamID string $TEAM_ID" "$path"
  /usr/libexec/PlistBuddy -c "Add :stripSwiftSymbols bool true" "$path"
  /usr/libexec/PlistBuddy -c "Add :compileBitcode bool false" "$path"
}

build_enterprise_ipa() {
  local work_dir="$1"
  local archive_path="$work_dir/JournalNote.xcarchive"
  local export_path="$work_dir/export"
  local export_options="$work_dir/ExportOptions.plist"

  mkdir -p "$export_path"
  create_export_options "$export_options"

  echo "[1/3] 正在归档 ${SCHEME:-JournalNote}（${CONFIGURATION:-Release}）..." >&2
  xcodebuild archive \
    -workspace "$WORKSPACE_PATH" \
    -scheme "${SCHEME:-JournalNote}" \
    -configuration "${CONFIGURATION:-Release}" \
    -destination "generic/platform=iOS" \
    -archivePath "$archive_path" \
    -allowProvisioningUpdates >&2

  echo "[2/3] 正在导出 Enterprise IPA..." >&2
  xcodebuild -exportArchive \
    -archivePath "$archive_path" \
    -exportPath "$export_path" \
    -exportOptionsPlist "$export_options" \
    -allowProvisioningUpdates >&2

  local ipa_path
  ipa_path="$(find "$export_path" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
  if [ -z "$ipa_path" ]; then
    echo "错误：导出完成，但没有找到 IPA。" >&2
    exit 1
  fi
  echo "$ipa_path"
}

upload_ipa() {
  local ipa_path="$1"
  local response_path="$2"
  local api_key="${PGYER_API_KEY:-24e363194c2e936c183d6331961780ea}"
  local user_key="${PGYER_USER_KEY:-}"
  local install_type="${PGYER_INSTALL_TYPE:-1}"
  local update_description="${PGYER_UPDATE_DESCRIPTION:-JournalNote 企业测试版本}"

  if [ -z "$api_key" ]; then
    api_key="$(read_secret "$API_KEY_ACCOUNT")"
  fi
  if [ -z "$user_key" ]; then
    user_key="$(read_secret "$USER_KEY_ACCOUNT")"
  fi
  if [ -z "$api_key" ]; then
    echo "错误：没有找到蒲公英 API Key。请先运行：$0 --configure" >&2
    exit 1
  fi
  if [ "$install_type" = "2" ] && [ -z "${PGYER_INSTALL_PASSWORD:-}" ]; then
    echo "错误：密码安装模式需要设置 PGYER_INSTALL_PASSWORD。" >&2
    exit 1
  fi

  echo "[3/3] 正在上传 $(basename "$ipa_path") 到蒲公英..."
  local curl_args=(
    --fail-with-body
    --silent
    --show-error
    --request POST
    "$PGYER_API_URL"
    --form "_api_key=$api_key"
    --form "file=@$ipa_path"
    --form "buildInstallType=$install_type"
    --form "buildUpdateDescription=$update_description"
    --output "$response_path"
  )
  if [ -n "$user_key" ]; then
    curl_args+=(--form "uKey=$user_key")
  fi
  if [ -n "${PGYER_INSTALL_PASSWORD:-}" ]; then
    curl_args+=(--form "buildPassword=${PGYER_INSTALL_PASSWORD}")
  fi
  curl "${curl_args[@]}"
}

print_upload_result() {
  local response_path="$1"
  python3 - "$response_path" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as file:
        result = json.load(file)
except Exception as error:
    print(f"错误：无法解析蒲公英返回结果：{error}", file=sys.stderr)
    sys.exit(1)

code = result.get("code")
if code not in (0, "0"):
    message = result.get("message") or result.get("msg") or "未知错误"
    print(f"上传失败：{message}（code={code}）", file=sys.stderr)
    sys.exit(1)

data = result.get("data") or {}
shortcut = data.get("buildShortcutUrl")
download_url = data.get("buildQRCodeURL")
version = data.get("buildVersion") or "未知"
build = data.get("buildBuildVersion") or "未知"

print("上传成功。")
print(f"版本：{version} ({build})")
if shortcut:
    print(f"安装地址：https://www.pgyer.com/{shortcut}")
if download_url:
    print(f"二维码地址：{download_url}")
PY
}

main() {
  require_command xcodebuild
  require_command curl
  require_command python3
  require_command security

  local provided_ipa=""
  case "${1:-}" in
    --configure)
      configure_credentials
      exit 0
      ;;
    --ipa)
      provided_ipa="${2:-}"
      if [ -z "$provided_ipa" ] || [ ! -f "$provided_ipa" ]; then
        echo "错误：请提供存在的 IPA 文件路径。" >&2
        exit 1
      fi
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    "")
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac

  local work_dir
  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/journalnote-pgyer.XXXXXX")"
  trap 'rm -rf "$work_dir"' EXIT

  local ipa_path="$provided_ipa"
  if [ -z "$ipa_path" ]; then
    ipa_path="$(build_enterprise_ipa "$work_dir")"
  fi

  local response_path="$work_dir/pgyer-response.json"
  upload_ipa "$ipa_path" "$response_path"
  print_upload_result "$response_path"
}

main "$@"
