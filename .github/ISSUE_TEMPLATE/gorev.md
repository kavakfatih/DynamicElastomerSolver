---
name: Görev
about: Uygulanacak bir iş. Bir ajanın tek başına okuyup çalışabileceği kadar eksiksiz olmalı.
title: '[GÖREV] '
labels: gorev
assignees: ''
---

<!--
Bu şablonun amacı: bir ajan tüm yol haritasını değil, YALNIZCA bu issue'yu
okur. Buradaki bilgi eksikse iş eksik yapılır.
-->

## Ne yapılacak

<!-- Bir paragraf. Ne, neden. -->

## Sürüm

<!-- v0.1 / v0.2 / v0.3 / v0.4 / v0.5 / v0.6 / v1.x — docs/YOL-HARITASI.md -->

## Dizin ve sahip

<!--
AGENTS.md §2'deki sahiplik tablosu. Sahibi olmadığın dizinde değişiklik
gerekiyorsa DUR ve sor.

  src/                     -> Claude Code
  test/check_*.f90         -> Claude Code
  docs/adr/                -> Claude Code
  verification/            -> Codex
  python/                  -> Codex
  docs/teori/              -> Codex
  .github/, CMakeLists.txt -> Codex
-->

- **Dizin:**
- **Sahip:**

## Bitmiş sayılma koşulu

<!-- Ölçülebilir olsun. "Çalışıyor" bir koşul değildir. -->

- [ ] Debug ve Release derleniyor, **sıfır uyarı** (derleyici VE fortls)
- [ ] `ctest` geçiyor, sayılar PR açıklamasında
- [ ] VER-001 / VER-002 / VER-031 sayıları **değişmedi**
- [ ] `CHANGELOG.md` güncel
- [ ]

## İlgili ADR

<!--
Dondurulmuş bir sözleşmeye dokunuluyorsa ADR ZORUNLUDUR — önce ADR, sonra kod.
  1 Malzeme · 2 Eleman · 3 Doğrusal çözücü · 4 Durum aktarımı
Yoksa "yok" yazın.
-->

## Kısıtlar

<!-- Bu görevde YAPILMAYACAK şeyler. Kapsam kayması en pahalı hatadır. -->
