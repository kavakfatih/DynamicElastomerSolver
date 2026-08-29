#!/usr/bin/env bash
# DES/26 -- depo durum ozeti
#
# Bir oturuma baslarken veya bir raporu dogrularken tek komutla nerede
# oldugunu gosterir. Hicbir sey DEGISTIRMEZ; salt okunurdur.
#
#   scripts/durum.sh          -> mevcut build/ dizinini kullanir
#   scripts/durum.sh --temiz  -> sifirdan derler (yavas ama kesin)

set -uo pipefail
cd "$(dirname "$0")/.."

TEMIZ=0
[ "${1:-}" = "--temiz" ] && TEMIZ=1

bolum() { printf '\n=== %s ===\n' "$1"; }

bolum "DAL VE COMMIT"
printf '  dal          : %s\n' "$(git branch --show-current)"
printf '  HEAD         : %s\n' "$(git log --oneline -1)"
printf '  main commit  : %s\n' "$(git rev-list --count origin/main 2>/dev/null || echo '?')"
BEKLEYEN=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
printf '  main disinda : %s commit\n' "$BEKLEYEN"
KIRLI=$(git status --porcelain | wc -l | tr -d ' ')
printf '  calisma agaci: %s degisiklik\n' "$KIRLI"

bolum "SURUM"
TAGS=$(git tag -l | tr '\n' ' ')
printf '  tag          : %s\n' "${TAGS:-yok}"

bolum "KAYNAK"
printf '  src modul    : %s\n' "$(ls src/*.f90 2>/dev/null | wc -l | tr -d ' ')"
printf '  test         : %s\n' "$(ls test/check_*.f90 2>/dev/null | wc -l | tr -d ' ')"
printf '  ADR          : %s\n' "$(ls docs/adr/0*.md 2>/dev/null | wc -l | tr -d ' ')"

bolum "DERLEME"
if [ "$TEMIZ" -eq 1 ]; then
    rm -rf build
    cmake -B build -DCMAKE_BUILD_TYPE=Debug >/dev/null 2>&1
fi
if [ ! -d build ]; then
    cmake -B build -DCMAKE_BUILD_TYPE=Debug >/dev/null 2>&1
fi
UYARI=$(cmake --build build --parallel 2>&1 | grep -cEi "error|Warning:" || true)
printf '  derleyici uyarisi: %s\n' "$UYARI"

bolum "TESTLER"
ctest --test-dir build 2>&1 | grep -E "tests passed|tests failed" | sed 's/^/  /'

bolum "REFERANS SAYILAR"
run() { [ -x "build/$1" ] && ./build/"$1" 2>/dev/null; }
printf '  VER-001 E        : %s\n' "$(run check_uniaxial | grep 'E (sayisal' | sed 's/.*= *//')"
printf '  VER-002 tanjant  : %s\n' "$(run check_material_tangent | grep 'CC bagil' | sed 's/.*= *//; s/ .*//' | sort -g | tail -1)"
printf '  VER-031 dP/dl(1) : %s\n' "$(run check_stability | grep 'vs E bagil' | sed 's/.*= *//; s/ .*//')"
printf '  VER-032 tanjant  : %s\n' "$(run check_elem_axi_q4 | grep 'sonlu fark' | sed 's/.*= *//; s/ .*//' | sort -g | tail -1)"
printf '  VER-033 yama     : %s\n' "$(run check_patch | grep 'sigma = 33' | sed 's/.*= *//; s/ .*//' | sort -g | tail -1)"
printf '  VER-034 basinc   : %s\n' "$(run check_cylinder | grep 'P bagil hata' | sed 's/.*= *//; s/ .*//' | sort -g | tail -1)"

bolum "SON"
