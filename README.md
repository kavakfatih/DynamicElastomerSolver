# DES/26 — DynamicElastomerSolver 2026

**Türkçe (bu dosya)** · English (`README.en.md`, henüz eklenmedi)

Elastomer ve kauçuk bileşenler için 2B nonlineer sonlu elemanlar (finite
element) çözücüsü.

Hedef ürünler: burulmalı titreşim damperi (torsional vibration damper)
kauçuğu, decoupler, burç (bushing), motor takozu, şanzıman takozu, kaplin.

> **Durum: v0.1 — ilk gerçek çözüm.**
> Program artık bir sınır değer problemi çözüyor: eksenel simetrik Q4
> elemanı (tam integrasyon ve F-bar), montaj, sınır koşulları, profil
> LDL^T doğrusal çözücüsü ve yük adımlamalı Newton. Yama testi ve kalın
> cidarlı silindir analitik çözüme karşı doğrulanmış durumda.
>
> **Henüz yok:** burulma (v0.2), karışık u-p (v0.3), viskoelastisite
> (v0.4), yeniden ağ örme (v0.5), temas (v1.x). Ağ üretimi de yok —
> testler ağı elle kuruyor. Yol haritası:
> [docs/YOL-HARITASI.md](docs/YOL-HARITASI.md).

---

## Neden bir tane daha FEA çözücüsü

**Konumlanma:** DES/26'nın tanımlayıcı yeteneği "eksenel simetrik +
burulma" **değildir** — o özellik pazar liderlerinde zaten vardır.
Tanımlayıcı yetenek şudur:

> **Burulma, otomatik yeniden ağ örme ve hoop yönünde sürtünme — birlikte.**

Bu üçünün aynı analizde çalışması, burç ve burulmalı titreşim damperi
(TVD) parçalarında gereklidir: büyük burulmalı kayma ağı bozar, hoop yönü
de yük yönüdür. Pazar lideri burulmayı destekler, yeniden ağ örmeyi ayrıca
destekler, ama ikisini birlikte desteklemez.

Burulmanın kendisi bir boşluk değildir — ANSYS'te PLANE182 ve PLANE183,
`KEYOPT(3)=6` ile burulmalı eksenel simetrik analizi yapar; Abaqus'te CGAX
eleman ailesi vardır. Gerçek boşluk, bu seçeneğin taşıdığı kısıtlardadır.
ANSYS'in kendi dokümantasyonuna göre burulmalı eksenel simetrik seçenek
için:

- yeniden bölgeleme (rezoning) ve nonlineer adaptivite **desteklenmiyor**
- yalnızca tam integrasyon mevcut (karışık u-P ile kullanılabiliyor)
- temas elemanlarıyla kullanıldığında **hoop yönündeki sürtünme hesaba
  katılmıyor**

Bunun yanında iki pratik gerekçe daha var:

- **Yeniden ağ örme.** Büyük şekil değiştirmede ağ bozulur; otomatik
  yeniden ağ örme ve çözüm aktarımı v0.5'te birinci sınıf bir yetenek
  olarak gelir.
- **Lisans maliyeti.** Bir damper geometrisini yüz kez taramak, çözüm
  başına lisans ödeyerek yapılabilecek bir şey değildir.

> **Rekabet iddiaları hakkında uyarı.** Yukarıdaki rakip kısıtları,
> alıntılandıkları sürümlerin dokümantasyonunda belgelenmiştir. Kamuya
> açık herhangi bir rekabet iddiası **yayınlanmadan önce güncel sürüme
> karşı yeniden doğrulanmalıdır**; bu kısıtlar sürümden sürüme değişir.
> Ayrıca ilgili lisans sözleşmesi karşılaştırmalı başarım (benchmark)
> yayınını yasaklıyorsa, karşılaştırma yayınlanmamalıdır.

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
| VER-031 | Mod bazlı kararlılık, dP/dλ | Bağımsız referans tablosu | mutlak fark ≤ 4.3e-06 |
| VER-032 | Eksenel simetrik Q4 elemanı | Analitik + sonlu fark | tanjant ≤ 2.4e-10, gerilme ≤ 9.3e-15 |
| VER-033 | Yama testi (patch test) | Analitik, çarpık ağ | ≤ 2.0e-15 |
| VER-034 | Kalın cidarlı silindir | Analitik (sıkıştırılamaz) | basınç ≤ 2.0e-04, u_r(B) ≤ 8.7e-06 |

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
- [0007 — Kararlılık ölçütü](docs/adr/0007-kararlilik-kriteri.md): tanjant
  pozitif tanımlılığının neden yanlış ölçüt olduğu ve yerine gelen mod
  bazlı monotonluk kontrolü
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

[CONTRIBUTING.md](CONTRIBUTING.md) ve [AGENTS.md](AGENTS.md) dosyalarını
okuyunuz. En kısa özet: tolerans gevşetmeyin, `ctest` çalıştırmadan
"çalışıyor" demeyin, tasarımda yanlış gördüğünüzü söyleyin.

`AGENTS.md` hem insan katkıcılar hem yapay zekâ ajanları için bağlayıcı
kural setidir ([açık standart](https://agents.md/); 30'dan fazla araç
doğal olarak okur). `CLAUDE.md` ona bağlı bir symlink'tir.

Araç zinciri, derleyici bayrakları ve sıfır uyarı kuralı:
[docs/TOOLCHAIN.md](docs/TOOLCHAIN.md).
