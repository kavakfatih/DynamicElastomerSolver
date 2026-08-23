# DES/26 — DynamicElastomerSolver 2026

**Türkçe (bu dosya)** · English (`README.en.md`, henüz eklenmedi)

Elastomer ve kauçuk bileşenler için 2B nonlineer sonlu elemanlar (finite
element) çözücüsü.

Hedef ürünler: burulmalı titreşim damperi (torsional vibration damper)
kauçuğu, decoupler, burç (bushing), motor takozu, şanzıman takozu, kaplin.

> **Durum: v0.0.1 — malzeme çekirdeği.**
> Bu sürümde ağ (mesh), eleman ve çözücü **yoktur**. Yalnızca malzeme
> arayüzü, sıkıştırılabilir Neo-Hookean malzeme ve doğrulama altyapısı
> kuruludur. Programla bir parça çözülemez; bir sonraki adım için
> [docs/YOL-HARITASI.md](docs/YOL-HARITASI.md) dosyasına bakınız.

---

## Neden bir tane daha FEA çözücüsü

Ticari genel amaçlı çözücüler elastomer işini yapar, ama üç yerde pahalıya
mal olur:

- **Burulma.** Eksenel simetrik + burulma (u_theta) formülasyonu, burulmalı
  titreşim damperi tasarımının tam merkezinde olmasına rağmen genel amaçlı
  paketlerde ya yoktur ya da 3B'ye zorlar. DES/26 bunu v0.2'de birinci sınıf
  bir yetenek olarak verir.
- **Yeniden ağ örme (remesh).** Büyük şekil değiştirmede ağ bozulur.
  Otomatik yeniden ağ örme ve çözüm aktarımı v0.5'te.
- **Lisans maliyeti.** Bir damper geometrisini yüz kez taramak, çözüm başına
  lisans ödeyerek yapılabilecek bir şey değildir.

Kapsam bilinçli olarak dardır. 3B, metal plastisitesi, açık dinamik ve CFD
**kalıcı olarak** kapsam dışıdır — bkz. [docs/KAPSAM.md](docs/KAPSAM.md).

---

## Mimari özeti

Beş katman, bağımlılık yalnızca aşağı yönlü:

| Katman | Sorumluluk | Dil |
|---|---|---|
| 1 | Sunum (Qt / CLI / Python API) | Python, C++ |
| 2 | Uygulama (iş akışı, senaryo) | Python |
| 3 | Ağ ve geometri | C++ |
| — | **C ABI sınırı** | — |
| 4 | Analiz çekirdeği | Fortran 2018 |
| 5 | Sayısal temel | Fortran 2018 |

Mimari kural: **Fortran çekirdeği metin üretmez.** Hata kodu döndürür,
kodu insan diline çevirmek üst katmanın işidir. Ayrıntı:
[docs/MIMARI.md](docs/MIMARI.md).

---

## Derleme

Gereken: Fortran 2018 derleyicisi (gfortran 13+ veya Intel ifx) ve
CMake 3.20+.

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

Alternatif olarak [fpm](https://fpm.fortran-lang.org/) ile:

```sh
fpm build --build-dir build-fpm
fpm test  --build-dir build-fpm
```

`--build-dir` gereklidir: fpm de varsayılan olarak `build/` kullanır ve
CMake ile aynı dizini paylaşırlarsa iki çıktı ağacı iç içe girer.
Dilerseniz `export FPM_BUILD_DIR=build-fpm` ile bir kez ayarlayın.

Depo **sıfır derleyici uyarısı** ile derlenir (`-std=f2018 -Wall -Wextra
-fimplicit-none`). Yeni bir uyarı üretmek regresyon sayılır.

Desteklenen platformlar: Windows, macOS (Apple Silicon ve Intel), Linux.

---

## Doğrulama

Sayısal bir çözücünün tek ciddi vaadi, doğruluğunun bağımsız olarak
gösterilebilmesidir. Doğrulama çerçevesi ASME V&V 10'a dayanır ve plan
[docs/dogrulama/DOGRULAMA-PLANI.md](docs/dogrulama/DOGRULAMA-PLANI.md)
içindedir. Her problem için bağımsız bir referans, belirtilmiş bir tolerans
ve **toleransın gerekçesi** vardır. "Geçiyor" bir tolerans gerekçesi
değildir.

Bu sürümde geçen doğrulamalar:

| Kimlik | Problem | Referans | Sonuç |
|---|---|---|---|
| VER-001 | Tek eksenli gerilme, Neo-Hookean | Analitik tam çözüm | bağıl hata 4.8e-06 … 5.9e-05 |
| VER-002 | Tutarlı tanjant (consistent tangent) | Sonlu fark | bağıl hata ≤ 1.1e-10 |

VER-001'de küçük şekil değiştirme elastisite modülü **3.599986** ölçülür;
sıkıştırılamaz sınırdaki kesin değer 6·C10 = 3.600000, sonlu K = 1e5 için
analitik değer 9Kμ/(3K+μ) = 3.599986'dır.

---

## Teori

Sıkıştırılabilir Neo-Hookean modelinin tam türetmesi — serbest enerji,
2. Piola-Kirchhoff gerilmesi, tutarlı tanjant ve penaltı formunun
kilitlenme (locking) sınırı —
[docs/teori/0001-hiperelastik-neo-hookean.md](docs/teori/0001-hiperelastik-neo-hookean.md)
içindedir.

---

## Mimari kararlar

Önemli kararlar ve gerekçeleri [docs/adr/](docs/adr/) altındadır. Özellikle:

- [0006 — Malzeme sözleşmesi](docs/adr/0006-malzeme-sozlesmesi.md): neden
  malzeme her zaman tam 3x3 alır ve analiz tipini asla bilmez
- [0007 — Kararlılık kriteri](docs/adr/0007-kararlilik-kriteri.md): Drucker
  kararlılığının neredeyse sıkıştırılamaz malzemelerde neden yanıltıcı
  olduğu — **açık karar bekliyor**
- [0008 — Çok dillilik](docs/adr/0008-cok-dillilik.md): ondalık ayırıcının
  neden her zaman nokta olduğu

---

## Lisans

[Business Source License 1.1](LICENSE). Değişim Tarihi (Change Date)
**2030-01-01**, Değişim Lisansı (Change License) **Apache License 2.0**.

Ek kullanım izni: akademik araştırma ve eğitim, artı kuruluş başına 90 günlük
değerlendirme. Ayrıntı `LICENSE` dosyasındadır.

Bağlayıcı metin İngilizce `LICENSE` dosyasıdır. Resmi olmayan Türkçe çeviri
bilgi amaçlıdır: [LISANS.tr.md](LISANS.tr.md).

Üçüncü taraf bağımlılık lisans politikası: [THIRD_PARTY.md](THIRD_PARTY.md).
Kısaca: MIT/BSD/Apache-2.0/MPL-2.0 serbest, LGPL yalnızca dinamik bağlama ile
ve ADR kaydıyla, GPL/AGPL/SSPL yasak — **kaynak kodu okumak dahil**.

---

## Katkı

[CONTRIBUTING.md](CONTRIBUTING.md) ve [CLAUDE.md](CLAUDE.md) dosyalarını
okuyunuz. En kısa özet: tolerans gevşetmeyin, `ctest` çalıştırmadan
"çalışıyor" demeyin, tasarımda yanlış gördüğünüzü söyleyin.
