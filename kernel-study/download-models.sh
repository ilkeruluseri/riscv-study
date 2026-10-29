#!/bin/sh
# Official immutable GGUF downloads; published SHA-256 is checked before use.
set -eu
cd "$(dirname "$0")"
mkdir -p workspace/models/qwen2.5-0.5b-instruct
cd workspace/models/qwen2.5-0.5b-instruct
model_url=https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/9217f5db79a29953eb74d5343926648285ec7e67

for quant in q4_0 q8_0; do
    case "$quant" in
        q4_0) expected=7671c0c304e6ce5a7fc577bcb12aba01e2c155cc2efd29b2213c95b18edaf6ed ;;
        q8_0) expected=ca59ca7f13d0e15a8cfa77bd17e65d24f6844b554a7b6c12e07a5f89ff76844e ;;
    esac
    file="qwen2.5-0.5b-instruct-$quant.gguf"
    if [ -f "$file" ] && printf '%s  %s\n' "$expected" "$file" | sha256sum --check --status; then
        printf 'Verified existing %s\n' "$file"
        continue
    fi
    curl --fail --location --retry 3 --continue-at - --output "$file.part" "$model_url/$file"
    if ! printf '%s  %s\n' "$expected" "$file.part" | sha256sum --check; then
        echo "Checksum mismatch; removing corrupt partial download. Rerun to retry." >&2
        rm -f "$file.part"
        exit 1
    fi
    mv "$file.part" "$file"
done
