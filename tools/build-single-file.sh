#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly OUTPUT_DIR="${1:-$PROJECT_DIR/dist}"
readonly OUTPUT_FILE="$OUTPUT_DIR/EasyLinux"
readonly PAYLOAD_MARKER="__EASYLINUX_PAYLOAD_BELOW__"

mkdir -p "$OUTPUT_DIR"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

payload_file="$tmp_dir/easylinux.tar.gz"

tar -czf "$payload_file" \
  -C "$PROJECT_DIR" \
  install.sh \
  functions \
  modules \
  config

cat > "$OUTPUT_FILE" <<EOF
#!/usr/bin/env bash

set -Eeuo pipefail

readonly PAYLOAD_MARKER="$PAYLOAD_MARKER"
readonly SELF="\$(readlink -f "\${BASH_SOURCE[0]}")"
readonly WORK_DIR="\$(mktemp -d -t easylinux.XXXXXX)"

cleanup() {
  rm -rf "\$WORK_DIR"
}
trap cleanup EXIT

payload_line="\$(awk -v marker="\$PAYLOAD_MARKER" '\$0 == marker { print NR + 1; exit }' "\$SELF")"
if [[ -z "\$payload_line" ]]; then
  printf '%s\\n' 'EasyLinux: embedded payload not found' >&2
  exit 1
fi

tail -n +"\$payload_line" "\$SELF" | base64 --decode | tar -xzf - -C "\$WORK_DIR"
exec bash "\$WORK_DIR/install.sh" "\$@"

$PAYLOAD_MARKER
EOF

base64 --wrap=76 "$payload_file" >> "$OUTPUT_FILE"
chmod +x "$OUTPUT_FILE"
printf 'Built %s (%s bytes)\n' "$OUTPUT_FILE" "$(wc -c < "$OUTPUT_FILE")"
