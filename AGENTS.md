# AGENTS.md — DES/26

Elastomer bileşenler için 2B nonlineer sonlu elemanlar çözücüsü. Fortran
2018 çekirdek, C++ ağ (sonra), Python orkestrasyon (sonra), Qt GUI (v0.6).

Bu dosya bu depodaki **tüm** ajanlar için bağlayıcıdır. `CLAUDE.md` buraya
bağlıdır. Ayrıntı: `docs/MIMARI.md`, `docs/TOOLCHAIN.md`, `docs/adr/`.

## 1. Komutlar

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure

fpm build --build-dir build-fpm     # --build-dir ZORUNLU: fpm de build/ kullanir
fpm test  --build-dir build-fpm
```

**Her sayısal değişiklikten sonra `ctest`. İstisnasız.** Çalıştırmadan
"çalışıyor" denmez; çıkan SAYI yazılır.

## 2. Sahiplik sınırları

Bu depoda birden fazla ajan çalışır.

| Dizin | Sahip |
|---|---|
| `src/` | **Claude Code** — dört sözleşme burada, başkası DOKUNMAZ |
| `test/check_*.f90` | Claude Code |
| `docs/adr/` | Claude Code |
| `verification/` | Codex — analitik referans çözümler |
| `python/` | Codex — kalibrasyon, araçlar |
| `docs/teori/` | Codex — türetmeler |
| `.github/`, `CMakeLists.txt` | Codex — build ve CI |

**Sahibi olmadığın dizinde değişiklik gerekiyorsa DUR ve sor.**

## 3. Dört dondurulmuş sözleşme — ADR yazmadan değiştirilemez

1. **Malzeme:** `eval(C, pt, state_n, S, CC, state_np1, stat, dt_factor)`
2. **Eleman:** değişken DOF/düğüm + eleman-dışı global DOF + formülasyon
   stratejisi
3. **Doğrusal çözücü:** simetrik indefinite destekli
4. **Durum aktarımı:** `serialise` / `restore` / `project`

## 4. Değiştirilemezler

- **Test toleransları.** Test geçmiyorsa KOD yanlıştır, tolerans değil.
- **`LICENSE`** — BUSL-1.1 metni; değiştirilmesi lisansça yasak.
- **VER-001 referansı:** `E = 3.599986 = 9Kmu/(3K+mu)`.
  Sıkıştırılamaz sınır `6*C10 = 3.600000` **DEĞİL**.
- **Kararlılık ölçütü:** mod bazlı `dP/dlambda > 0`. Tam tanjant pozitif
  tanımlılığı **DEĞİL** — sağlıklı Neo-Hookean bunu sağlamaz (ADR-0007).

## 5. Bağımlılık lisansı

**İZİN:** MIT, BSD-2/3, Apache-2.0, MPL-2.0, ISC, Zlib, Boost
**KOŞULLU:** LGPL, yalnızca dinamik bağlama + ADR
**YASAK:** GPL, AGPL, SSPL, "ticari kullanım yasak"

Yasak olanlarda kural linklemenin ötesine geçer: **KAYNAK KODUNU OKUMA.**
Algoritmayı makalesinden öğren. (ADR-0004, `THIRD_PARTY.md`)

## 6. Kod kuralları

- Yorumlar ve dokümanlar **Türkçe**, tanımlayıcılar **İngilizce**
  (`des_material`, `dt_factor`, `DES_MAT_OK`).
- Hassasiyet `des_kinds`tan: `dp`, `ip`. `real(8)` yasak.
- `src/` içinde `stop`, `print`, dosya G/Ç **yok**. (Karakter değişkenine
  iç yazma G/Ç sayılmaz.) Hata `stat`, adım küçültme `dt_factor` ile.
- **İç prosedürlerde host değişkenini MASKELEME.** fortls uyarısı gerçek
  hatadır: host'u değiştirdiğini sanırken yerel kopyayı değiştirirsin.
- Fortran büyük/küçük harf duyarsızdır: hacim oranı `J` ile döngü indisi
  `j` **aynı isimdir**. Tensör döngülerinde `ii, jj, kk, ll`.
- **Yorumlarda `/` ve `*` yan yana yazılmaz** — Ninja kaynakları C ön
  işlemcisinden geçirir, `unterminated comment` verir. Makefile
  üreticisinde sessizce çalışır, Windows CI'da patlar.
- Kullanıcıya görünen metin `messages/tr.toml` ve `en.toml` içinde.
- Ondalık ayırıcı: dosyalarda **her zaman nokta**, virgül sadece ekranda.
- Girinti 3 boşluk, satır ≤ 90 karakter, `implicit none`, `use ... only:`.

## 7. Git

- `main` her zaman yeşil.
- Kısa ömürlü dallar: `feat/`, `fix/`, `docs/`, `verify/`.
- Sürüm = git tag + GitHub Release. **Uzun ömürlü sürüm dalı YOK.**
- `.sln`, `.vcxproj`, `.vfproj` commit **EDİLMEZ** — CMake üretir
  (`docs/TOOLCHAIN.md`).
- `push --force` **yasak**; `--force-with-lease` kullan.
- `reset --hard` kullanıcı onayı olmadan **yasak**.

## 8. Bitmiş sayılma

- Derleniyor: Debug **ve** Release, **sıfır uyarı — derleyici VE fortls**
- `ctest` geçiyor
- Yeni malzeme: kararlılık **ve** tanjant testini geçiyor
- Yeni eleman: yama testini (patch test) geçiyor
- `THIRD_PARTY.md` güncel · teori notu var · `CHANGELOG.md` güncel

## 9. Yanlış gördüğünü söyle

Bir şey yanlış görünüyorsa **sessizce etrafından dolaşma, SÖYLE.**

Bu bir nezaket kuralı değil; bu depoda iki kez işe yaradı:

- **VER-001 referans değeri.** Verilen beklenti 3.599964 idi; doğrusu
  sonlu K için `9Kmu/(3K+mu) = 3.599986`. Spesifikasyondaki değer sonlu
  fark türevinden gelen 2.2e-5'lik bir hata taşıyordu.
- **ADR-0007 kararlılık ölçütü.** Tam tanjant pozitif tanımlılığı yanlış
  ölçüttü: sağlıklı Neo-Hookean (C10 = +0.6, K = 1e3) `F = diag(1.40,
  0.85, 0.85)` altında `dC:CC:dC = -3.9389e+01` verir. Ölçüt değişti.

İkisi de spesifikasyondaki hatalardı ve sorgulandıkları için düzeldiler.
