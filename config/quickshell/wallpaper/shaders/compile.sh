#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

QSB="${QSB_BIN:-$(command -v qsb || true)}"
if [ -z "$QSB" ]; then
    QSB="$(compgen -G '/nix/store/*-qtshadertools-*/bin/qsb' | head -n1 || true)"
fi
if [ -z "$QSB" ] || [ ! -x "$QSB" ]; then
    echo "qsb (qtshadertools) not found" >&2
    exit 1
fi

for f in *.frag; do
    echo "Compiling $f -> ${f}.qsb"
    "$QSB" --qt6 --qsbversion 64 -o "${f}.qsb" "$f"
done
