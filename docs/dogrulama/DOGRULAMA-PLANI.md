# DES/26 Doğrulama Planı

**Çerçeve:** ASME V&V 10 — *Guide for Verification and Validation in
Computational Solid Mechanics*

---

## Doğrulama (verification) ile geçerleme (validation) ayrımı

ASME V&V 10 iki soruyu ayırır:

- **Doğrulama (verification):** *Denklemleri doğru mu çözüyoruz?*
  Referans, matematiksel bir gerçektir — analitik çözüm, yakınsama mertebesi
  veya bağımsız bir sayısal sonuç. Fiziksel deney gerekmez.
- **Geçerleme (validation):** *Doğru denklemleri mi çözüyoruz?*
  Referans, fiziksel deneydir. Model formu ve malzeme karakterizasyonu
  sınanır.

Bu belge **doğrulamayı** kapsar. Geçerleme, gerçek damper ve burç ölçümleri
elde edildiğinde ayrı bir plana yazılacaktır (VAL-xxx).

---

## Tolerans kuralı

Her problem için üç şey zorunludur:

1. **Bağımsız referans** — analitik çözüm, yakınsama mertebesi ya da başka
   bir kodun sonucu. "Kendi çıktımıza benziyor" referans değildir.
2. **Belirtilen tolerans** — sayı olarak, önceden.
3. **Toleransın gerekçesi** — bu sayı neden bu?

> **"Geçiyor" bir tolerans gerekçesi değildir.**

### Numaralandırma politikası

**VER numaraları asla yeniden kullanılmaz ve asla kaydırılmaz.** Yeni bir
doğrulama problemi, konusu hangi gruba girerse girsin, listenin sonuna
eklenir. Sebep: numaralar teori notlarından, ADR'lerden, commit
mesajlarından ve CI günlüklerinden referans alınır; kaydırma bu
referansların hepsini sessizce yanlışlar.

Bir toleransın gerekçesi şunlardan biri olmalıdır:

- **Yuvarlama tabanı** — çift hassasiyette ulaşılabilecek en iyi değer
  (örn. merkezi farkta $\epsilon/h \approx 10^{-10}$)
- **Kesme hatası** — sayısal yöntemin mertebesinden hesaplanan sınır
- **Fiziksel sapma** — modelin referanstan bilerek ayrıldığı miktar
  (örn. sonlu $K$'nın sıkıştırılamaz çözümden sapması, $\mu/K$ mertebesinde)
- **Mühendislik kabulü** — açıkça gerekçelendirilmiş, tasarım kararını
  değiştirmeyecek büyüklük

Toleransı gevşetmek bir hata düzeltmesi değildir. Bir test kalıyorsa sebep
bulunur; tolerans gerçekten yanlışsa, gerekçesi bu belgede güncellenir.

---

## Durum özeti

| Durum | Sayı |
|---|---|
| **GEÇTİ** | 6 |
| Planlandı | 28 |
| **Toplam** | 34 |

---

## A — Malzeme doğrulaması (VER-001 … VER-009)

### VER-001 — Tek eksenli gerilme, Neo-Hookean · **GEÇTİ**

**Referans:** Analitik tam çözüm,
$\sigma_{11} = 2C_{10}(\lambda^2 - 1/\lambda)$ (sıkıştırılamaz sınır).
Yanal uzama $\sigma_{22} = 0$ koşulundan ikiye bölmeyle çözülür.

**Tolerans:** $\lambda$'ya göre 1.0e-5 … 1.2e-4 (aşağıdaki tablo).

**Gerekçe:** *Fiziksel sapma.* Referans sıkıştırılamaz malzeme içindir,
model sonlu $K = 10^5$ taşır. Beklenen sapma $\mu/K = 1.2\times10^{-5}$
mertebesindedir ve uzamayla büyür. Tolerans, beklenenin iki katı alınmıştır:
daha fazlası formül hatasını gizler, daha azı platform gürültüsüne takılır.

| $\lambda$ | tolerans | ölçülen |
|---|---|---|
| 1.05 | 1.0e-5 | 4.810e-06 |
| 1.25 | 1.6e-5 | 8.283e-06 |
| 1.50 | 2.6e-5 | 1.322e-05 |
| 2.00 | 5.0e-5 | 2.533e-05 |
| 3.00 | 1.2e-4 | 5.911e-05 |

Ek kontroller: $E$ vs $6C_{10}$ (tolerans 1e-4, ölçülen 3.98e-06);
$E$ vs $9K\mu/(3K+\mu)$ (tolerans 1e-6, ölçülen 2.16e-08);
$\sigma_{22}$ artığı (tolerans 1e-14, ölçülen 8.52e-17).

**Uygulama:** `test/check_uniaxial.f90`

### VER-002 — Tutarlı tanjant, Neo-Hookean · **GEÇTİ**

**Referans:** $\mathbf{S}$'nin simetrik yönlerde merkezi farkı,
$h = 10^{-6}$. Altı belirlenimci deformasyon gradyanı, iki
sıkıştırılabilirlik oranı ($K/C_{10} = 1.7\times10^3$ ve $1.7\times10^5$).

**Tolerans:** tanjant bağıl hatası 1e-8; major simetri 1e-12.

**Gerekçe:** *Yuvarlama tabanı.* Merkezi farkta erişilebilir en iyi bağıl
hata $O(\epsilon/h) \approx 10^{-10}$'dur. Tolerans iki mertebe pay
bırakır; farklı derleyici ve optimizasyon seviyelerinde yuvarlama tabanı
birkaç kat oynayabilir, ama 1e-8'i aşan bir sapma yuvarlama değil formül
hatasıdır. Major simetri analitik olarak tam sağlanır; sapma yalnızca
toplama sırasından gelebilir.

**Ölçülen:** tanjant 1.87e-11 … 1.04e-10; major simetri 12 vakanın 8'inde
tam sıfır, en kötü 1.48e-16.

**Uygulama:** `test/check_material_tangent.f90`

### VER-003 — Ogden modeli, tek eksenli/iki eksenli/saf kayma

**Referans:** Üç deformasyon modunun analitik çözümleri, Ogden (1997) §4.3.
**Tolerans:** 1e-6 bağıl. **Gerekçe:** *Yuvarlama tabanı* — analitik çözüm
tam olduğu için fiziksel sapma yok; kalan tek kaynak asal uzama
ayrıştırmasının koşullandırmasıdır. **Sürüm:** v0.4

### VER-004 — Ogden tanjantı, tekrarlı asal uzamalar

**Referans:** Sonlu fark. **Tolerans:** 1e-8. **Gerekçe:** VER-002 ile
aynı. **Not:** $\lambda_1 = \lambda_2$ durumunda asal uzama formülasyonu
0/0 belirsizliği üretir; L'Hôpital dalının ayrıca sınanması gerekir. Bu,
Ogden uygulamalarının klasik hata noktasıdır. **Sürüm:** v0.4

### VER-005 — Prony serisi gevşemesi (relaxation)

**Referans:** Sabit şekil değiştirme altında analitik üstel gevşeme.
**Tolerans:** 1e-9 bağıl, zaman adımı yeterince küçükken.
**Gerekçe:** *Kesme hatası* — iç değişken entegrasyonu üstel algoritmayla
yapılırsa sabit şekil değiştirmede tam olur. **Sürüm:** v0.4

### VER-006 — Prony serisi sünmesi (creep)

**Referans:** Sabit gerilme altında analitik sünme cevabı.
**Tolerans:** 1e-6. **Gerekçe:** *Kesme hatası* — gerilme kontrollü
yükleme yerel bir yineleme gerektirir. **Sürüm:** v0.4

### VER-007 — WLF zaman-sıcaklık kaydırması

**Referans:** İki farklı sıcaklıkta hesaplanan gevşeme eğrilerinin,
WLF kaydırma çarpanıyla tek bir ana eğriye (master curve) oturması.
**Tolerans:** 1e-8. **Gerekçe:** *Yuvarlama tabanı* — kaydırma cebirsel
bir dönüşümdür, kesme hatası içermez. **Not:** Bu test aynı zamanda
`mat_point_t%temperature` alanının hiçbir imza değişikliği olmadan
kullanılabildiğinin sınavıdır. **Sürüm:** v0.4

### VER-008 — Mullins hasarı, yükleme-boşaltma çevrimi

**Referans:** Analitik sözde-elastik hasar fonksiyonu.
**Tolerans:** 1e-8. **Gerekçe:** *Yuvarlama tabanı.*
**Ek kontrol:** ikinci çevrim, ilkinden hasar değişkeni kadar farklı
olmalı ve hasar $[0,1]$ dışına çıkmamalı — `project()` sınavı.
**Sürüm:** v0.4

### VER-009 — Malzeme durumu gidiş-dönüşü, gerçek yük altında

**Referans:** Aynı yükleme yolunun kesintisiz ve serialise/restore ile
bölünmüş hâlleri. **Tolerans:** bit düzeyinde aynı.
**Gerekçe:** *Yuvarlama tabanı* — aynı işlemler aynı sırada yapıldığı için
sonuç birebir aynı olmalıdır; olmuyorsa durum eksik aktarılıyordur.
**Sürüm:** v0.4

---

## B — Eleman ve yakınsama doğrulaması (VER-010 … VER-018)

### VER-010 — Yama testi (patch test), eksenel simetrik Q4

**Referans:** Sabit gerilme durumu, analitik.
**Tolerans:** 1e-13 bağıl (makine hassasiyeti).
**Gerekçe:** *Yuvarlama tabanı.* Yama testi bir yaklaşım değil bir
kimliktir: düzgün olmayan bir ağda bile sabit gerilme durumu **tam olarak**
yeniden üretilmelidir. Bu testi geçmeyen eleman, ağ inceltildikçe doğru
cevaba yakınsamaz. Tolerans tartışmaya kapalıdır. **Sürüm:** v0.1

### VER-011 — Kalın cidarlı silindir, iç basınç

**Referans:** Lamé analitik çözümü (doğrusal elastik sınırda).
**Tolerans:** 1e-4 bağıl, ağ yakınsaması gösterilmiş olmak kaydıyla.
**Gerekçe:** *Kesme hatası* — Q4 elemanı ikinci mertebe yakınsar; verilen
ağ yoğunluğunda beklenen ayrıklaştırma hatası bu mertebededir.
**Sürüm:** v0.1

### VER-012 — İçi boş silindirin saf burulması

**Referans:** Analitik tork-açı bağıntısı (Neo-Hookean, sıkıştırılamaz).
**Tolerans:** 1e-4 bağıl. **Gerekçe:** *Kesme hatası.*
**Önem:** Bu, eksenel simetrik + burulma formülasyonunun ilk gerçek
sınavıdır ve v0.2'nin çıkış kapısıdır. **Sürüm:** v0.2

### VER-013 — Yakınsama mertebesi, Q4 ve Q8

**Referans:** Ağ inceltmede gözlenen yakınsama mertebesi.
**Tolerans:** Q4 için $2.0 \pm 0.15$, Q8 için $3.0 \pm 0.20$.
**Gerekçe:** *Mühendislik kabulü.* Ölçülen mertebe, teorik mertebeye
yakınsar ama ağ dizisi sonlu olduğu için tam çıkmaz; pay, asimptotik
olmayan bölgenin etkisini karşılar. Mertebenin **düşük** çıkması eleman
hatasına işaret eder. **Sürüm:** v0.3

### VER-014 — Hacimsel kilitlenme, F-bar etkisi

**Referans:** $K/\mu \to \infty$ sınırında analitik sıkıştırılamaz çözüm.
**Tolerans:** F-bar ile 1e-3 bağıl, $K/\mu = 10^5$'te.
**Gerekçe:** *Mühendislik kabulü.* Kritik olan mutlak değer değil,
karşılaştırmadır: **kilitlenmiş (tam integrasyon) ve F-bar sonuçları yan
yana raporlanmalıdır.** Tam integrasyonun aynı ağda mertebe olarak daha
kötü olması beklenir; olmuyorsa F-bar uygulanmamış demektir. **Sürüm:** v0.1

### VER-015 — inf-sup (LBB) sayısal testi, karışık u-p

**Referans:** Ağ inceltmede inf-sup sabitinin sıfıra gitmemesi
(Chapelle-Bathe sayısal inf-sup testi).
**Tolerans:** Sabit, ağ inceltildikçe bir alt sınırın üstünde kalmalı.
**Gerekçe:** *Matematiksel koşul.* Bu bir doğruluk testi değil, bir
kararlılık testidir: kararsız bir eleman çifti (Q4/P0 gibi) basınç
salınımı üretir ve bu salınım ağ inceltmeyle **büyür**. **Sürüm:** v0.3

### VER-016 — Üçlü yakınsama kriteri tutarlılığı

**Referans:** Artık (residual) normu, düzeltme normu ve enerji ölçütünün
aynı çözüme yakınsaması. **Tolerans:** Üç ölçütün de sağlandığı noktada
çözümler 1e-10 bağıl içinde aynı olmalı.
**Gerekçe:** *Yuvarlama tabanı.* Tek ölçüt yanıltır; özellikle neredeyse
sıkıştırılamaz malzemelerde artık küçülürken çözüm hâlâ yürüyor olabilir.
**Sürüm:** v0.3

### VER-017 — Newton kuadratik yakınsama mertebesi

**Referans:** Ardışık artık normlarının oranı; tutarlı tanjantla yakınsama
kuadratik olmalıdır. **Tolerans:** Gözlenen mertebe $\geq 1.8$.
**Gerekçe:** *Mühendislik kabulü.* Kuadratik yakınsamanın kaybı, tanjantın
tutarsız olduğunun **en duyarlı göstergesidir** — sonuçlar hâlâ doğru
çıkarken bile yakalar. **Sürüm:** v0.1

### VER-018 — Geri adım (cut-back) ile kurtarma

**Referans:** Ters dönmüş eleman üretecek kadar büyük bir yük adımı.
**Tolerans:** Çözücü `DES_MAT_NONPHYSICAL` alıp `dt_factor` ile adımı
küçültmeli ve sonunda yakınsamalı; kesintisiz çözümle 1e-8 içinde aynı
sonucu vermeli. **Gerekçe:** *Yuvarlama tabanı* — farklı adım yolları aynı
denge noktasına gitmeli. **Sürüm:** v0.1

---

## C — Sistem ve altyapı doğrulaması (VER-019 … VER-024)

### VER-019 — Rijit cisim hareketi, sıfır gerilme

**Referans:** Büyük dönme ve öteleme altında gerilme tam olarak sıfır
olmalı. **Tolerans:** 1e-12 mutlak (gerilme ölçeğine göre).
**Gerekçe:** *Yuvarlama tabanı.* Toplam Lagrange formülasyonunda bu bir
kimliktir. Sıfır olmayan bir gerilme, kinematik hatasına işaret eder.
**Sürüm:** v0.1

### VER-020 — FEBio karşılaştırması, basit kauçuk blok

**Referans:** FEBio (MIT lisanslı) sonucu.
**Tolerans:** 1e-3 bağıl. **Gerekçe:** *Mühendislik kabulü.* İki bağımsız
kod, aynı ağ ve aynı malzeme ile bu mertebede uyuşmalıdır; kalan fark
eleman teknolojisi farklarından gelir. **Not:** FEBio'nun MIT lisansı,
kaynak kodunun okunmasına ve karşılaştırmaya lisans sorunu olmadan izin
verir ([ADR 0004](../adr/0004-copyleft-bagimlilik-yok.md)). **Sürüm:** v0.3

### VER-021 — FEBio karşılaştırması, burulma yüklemesi

**Referans:** FEBio 3B modeli (DES/26 2B eksenel simetrik + burulma).
**Tolerans:** 1e-2 bağıl tork. **Gerekçe:** *Mühendislik kabulü.* 2B ve 3B
ayrıklaştırmalar aynı değildir; tolerans bu farkı karşılar. Bu test,
burulma formülasyonunun 3B ile aynı fiziği verdiğinin bağımsız kanıtıdır.
**Sürüm:** v0.3

### VER-022 — Yeniden başlatma (restart) gidiş-dönüşü

**Referans:** Kesintisiz çözüm ile restart'lı çözüm.
**Tolerans:** bit düzeyinde aynı. **Gerekçe:** *Yuvarlama tabanı.*
**Sürüm:** v0.5

### VER-023 — Yeniden ağ örme sonrası çözüm aktarımı

**Referans:** Aktarım öncesi ve sonrası denge artığı.
**Tolerans:** Aktarım sonrası artık, yükleme artığının %5'ini geçmemeli;
hasar değişkenleri fiziksel aralıkta kalmalı (`project()` sonrası tam).
**Gerekçe:** *Mühendislik kabulü.* Aktarım kaçınılmaz olarak hata katar;
kabul edilebilir sınır, bir Newton adımında geri kazanılabilir olmasıdır.
**Sürüm:** v0.5

### VER-024 — Platformlar arası tekrarlanabilirlik

**Referans:** Linux, macOS (arm64) ve Windows sonuçları.
**Tolerans:** 1e-12 bağıl. **Gerekçe:** *Yuvarlama tabanı.* Farklı
derleyiciler ve komut setleri (FMA gibi) farklı yuvarlama üretir; ama
sapma bu mertebeyi aşıyorsa tanımsız davranış vardır. **Sürüm:** v0.1

---

## D — Mühendislik doğrulama problemleri (VER-025 … VER-030)

Bu grup, hedef ürünlere yakın gerçekçi geometrilerdir. Analitik çözümleri
yoktur; referans, bağımsız bir kod veya yakınsamış ince ağ çözümüdür.

### VER-025 — Kauçuk burç, radyal yükleme

**Referans:** FEBio. **Tolerans:** 1e-2 bağıl radyal rijitlik.
**Gerekçe:** *Mühendislik kabulü* — tasarım kararını değiştirmeyecek fark.
**Sürüm:** v0.3

### VER-026 — Kauçuk burç, eksenel yükleme

**Referans:** FEBio, genelleştirilmiş düzlem şekil değiştirme ile
karşılaştırma. **Tolerans:** 1e-2. **Sürüm:** v0.3

### VER-027 — Burulmalı titreşim damperi, tork-açı eğrisi

**Referans:** Yakınsamış ince ağ çözümü (ağ yakınsaması ayrıca
gösterilmiş). **Tolerans:** Kaba ağ ile ince ağ arasında 2e-2 bağıl tork.
**Gerekçe:** *Mühendislik kabulü.* Bu, projenin amaç fonksiyonudur; tork
tahmininin %2'den iyi olması tasarım için yeterlidir. **Sürüm:** v0.2

### VER-028 — Motor takozu, birleşik basma + kayma

**Referans:** FEBio. **Tolerans:** 2e-2 bağıl rijitlik.
**Gerekçe:** *Mühendislik kabulü.* **Sürüm:** v0.3

### VER-029 — Viskoelastik damper, harmonik yükleme

**Referans:** Prony serisinden analitik karmaşık modül.
**Tolerans:** Depolama ve kayıp modüllerinde 1e-3 bağıl.
**Gerekçe:** *Kesme hatası* — zaman entegrasyonunun periyot başına adım
sayısına bağlı hatası. **Sürüm:** v0.4

### VER-030 — Büyük kayma açısında yeniden ağ örme

**Referans:** Yeniden ağ örmeli ve örmesiz (mümkün olduğu kadar) çözümler.
**Tolerans:** Ağ örme noktasına kadar 1e-3 bağıl; sonrasında yakınsamış
referansla 2e-2. **Gerekçe:** *Mühendislik kabulü.* **Sürüm:** v0.5

---

## E — Malzeme kararlılığı (VER-031)

### VER-031 — Mod bazlı kararlılık ölçütü · **GEÇTİ**

**Referans:** Bağımsız olarak hesaplanmış nominal gerilme ve
`dP/dlambda` tablosu (C10 = 0.6, K = 1e5, tek eksenli), yedi uzama
oranında; artı C10 = -0.6 için üç nokta.

**Tolerans:** 2.0e-5 mutlak.

**Gerekçe:** *Referansın gösterim hassasiyeti.* Referans değerler beş
ondalık haneye yuvarlanmış verilmiştir; tek başına bu ±5e-6 belirsizlik
taşır. Tolerans bunun dört katıdır. Ölçülen sapmalar 4.3e-06
mertebesindedir, yani referansın kendi yuvarlama payı içinde kalır.

**Ölçülen** (C10 = +0.6):

| λ | P (ref) | P (ölçülen) | dP/dλ (ref) | dP/dλ (ölçülen) |
|---|---|---|---|---|
| 0.50 | −4.19999 | −4.199986 | 20.39992 | 20.399923 |
| 0.70 | −1.60897 | −1.608974 | 8.19706 | 8.197060 |
| 1.00 | 0.00000 | 0.000000 | 3.59999 | 3.599986 |
| 1.50 | +1.26666 | 1.266658 | 1.91109 | 1.911089 |
| 2.00 | +2.09998 | 2.099976 | 1.49996 | 1.499961 |
| 3.00 | +3.46658 | 3.466582 | 1.28880 | 1.288802 |
| 4.00 | +4.72480 | 4.724797 | 1.23735 | 1.237346 |

C10 = −0.6: −3.600014 / −1.911134 / −1.500039 (referans −3.60001 /
−1.91113 / −1.50004). Her iki malzeme de doğru sınıflandırılır.

**Ek kontrol — VER-001 ile çapraz doğrulama.** λ = 1'deki dP/dλ doğrudan
elastisite modülüdür:

| Ne | Tolerans | Ölçülen |
|---|---|---|
| dP/dλ(1) vs 9Kμ/(3K+μ) | 1e-6 bağıl | 3.16e-08 |

Bu, kararlılık kontrolünü VER-001'e bağlar: ikisinden biri bozulursa
ikisi birden kırmızıya döner.

**Sınıflandırma kontrolleri.** C10 = +0.6 üç modun tamamında
λ = 0.5 … 4.0 aralığında kararlı; C10 = −0.6 üç modda da kararsız ve ilk
kararsızlık λ_min'de raporlanıyor.

**Uygulama:** `test/check_stability.f90` · **Ölçüt:**
[ADR 0007](../adr/0007-kararlilik-kriteri.md)

### VER-032 — Eksenel simetrik Q4 elemanı · **GEÇTİ**

ADR-0009 eleman sözleşmesinin ilk gerçek uygulaması. **Yama testi (patch
test) burada YOKTUR** — o, çözücü gerektirir ve VER-010 olarak v0.1'de
gelecektir. Buradaki kontroller eleman düzeyindedir.

**E1 — Tanjant, artığın sonlu farkına karşı.** Bu, malzeme tanjant
kontrolünün (VER-002) eleman karşılığıdır ve elemanın çıkış kapısıdır.

| Formülasyon | Tolerans | Ölçülen |
|---|---|---|
| `full` — K_uu vs merkezi fark | 1e-8 | **1.7762e-10** |
| `full` — major simetri | 1e-10 | **1.3026e-16** |
| `fbar` — K_uu vs merkezi fark | 1e-8 | **4.9578e-10** |
| `fbar` — major simetri | 1e-10 | **2.6400e-16** |
| eksen elemanı `fbar` — K_uu vs fark | 1e-8 | **9.3378e-11** |

*Gerekçe:* yuvarlama tabanı. Merkezi farkta ($h = 10^{-6}$) erişilebilir
en iyi bağıl hata $O(\epsilon/h) \approx 10^{-10}$'dur; tolerans iki
mertebe pay bırakır. Yer değiştirme alanı bilinçli olarak HOMOJEN
DEĞİLDİR — homojen bir alanda F-bar'ın ek tanjant terimi kaybolur ve
sınanmamış olurdu.

**E2 — Homojen deformasyon, analitik referans.** $C_{10} = 0.6$,
$K = 10^5$, bileşen sırası $(r, z, \theta)$. Gerilme **elemandan**
alınır, malzemeden doğrudan değil; aksi hâlde test elemanın kinematiğini
sınamazdı.

| Vaka | Referans | Ölçülen | Bağıl fark |
|---|---|---|---|
| (a) $F = \mathrm{diag}(1.1,1.1,1.1)$, $\sigma_{rr}$ | 33100.000000000 | 33100.000000000 | 1.10e-15 |
| (a) izotropiden sapma | 0 | 0 | **tam 0** |
| (b) $F = \mathrm{diag}(1.2,1.0,1.2)$, $\sigma_{rr}$ | 44000.095846262 | 44000.095846262 | 4.46e-15 |
| (b) $\sigma_{zz}$ | 43999.808307476 | 43999.808307476 | 9.26e-15 |
| (b) $\sigma_{rr} = \sigma_{tt}$ | — | — | **tam 0** |
| (c) izokorik, $\lambda_z = 1.5$, $\sigma_{zz}$ | 1.266666667 | 1.266666667 | 3.51e-16 |
| (c) $\sigma_{zz} - \sigma_{rr}$ | 1.900000000 | 1.900000000 | 2.34e-16 |

Ayrıca dört Gauss noktasının **tam olarak aynı** $F$'yi görmesi
denetlenir: max$|\Delta F| \le 2.8\times10^{-17}$.

*Gerekçe:* homojen deformasyonda **ayrıklaştırma hatası yoktur**; sapma
varsa kinematik yanlıştır. Kalan tek kaynak yuvarlamadır, tolerans 1e-9.

(c) vakası **VER-001 ile çapraz doğrulamadır**: $\sigma_{zz} -
\sigma_{rr} = 2C_{10}(\lambda^2 - 1/\lambda)$ ifadesinin
$\lambda = 1.5$'teki değeri olan 1.9'a birebir eşittir.

**E3 — Rijit cisim hareketi.** Eksenel öteleme: max$|f_{int}| =$ **tam
0.0**.

> **Spesifikasyon düzeltmesi.** Eksenel simetride, burulma serbestliği
> olmadan, **tek rijit cisim hareketi eksenel ötelemedir**. r-z
> düzlemindeki dönme rijit DEĞİLDİR: $u_r$ yarıçapa göre değişir,
> dolayısıyla $F_{tt} = 1 + u_r/R \neq 1$ olur. z ekseni etrafındaki
> dönme gerçek rijit harekettir ama yer değiştirmesi $u_\theta$'dadır ve
> bu eleman onu taşımaz (v0.2). Test bunu kayıt altına alır: r-z dönmesi
> max$|f_{int}| = 2.19\times10^3$ üretir ve bu **doğrudur**.

**E4 — Eksen üzerindeki düğüm.** $R = 0$'a dokunan elemanda düzgün
genişleme: $\sigma_{rr} = $ 33100.000000000, NaN yok, tanjant 9.34e-11.

$F_{tt} = 1 + u_r/R$ eksende belirsizdir; L'Hôpital ile
$F_{tt} \to F_{rr}$ alınır. **Bu dal 2x2 Gauss'ta hiç tetiklenmez**:
ekseni kenarıyla kesen bir elemanda en yakın integrasyon noktasının
yarıçapı $0.2113h$'dir. Dal dejenere elemanlar için bir güvencedir.

**E5 — `quality()`.** Bozulmamış kare: `jacobian_ratio` = 1,
`aspect_ratio` = 1, açılar 90°, `worst` = 1, `inverted` = false — hepsi
tam. Katlanmış eleman: `inverted` = true, `worst` = 0. Referans
konfigürasyonda ters düğüm sırası `setup` tarafından reddedilir
(`DES_ELEM_BAD_ARG`) — bir ağ hatasıdır ve erken yakalanır.

**Uygulama:** `test/check_elem_axi_q4.f90` · **Eleman:**
`src/des_elem_axi_q4.f90` · **Sözleşme:**
[ADR 0009](../adr/0009-eleman-sozlesmesi.md)

### VER-033 — Yama testi (patch test) · **GEÇTİ**

Programın gerçekten bir sınır değer problemi çözdüğünün ilk kanıtı.
Montaj, sınır koşulu, doğrusal çözücü ve Newton'un **tamamı** aynı anda
sınanır: dördünden biri yanlışsa bu test geçmez.

**Kurulum.** Dört elemanlı, bilinçli olarak ÇARPIK bir yama (kenar orta
düğümleri de kaydırılmış). Yalnızca 5 numaralı düğüm içeridedir ve
serbesttir; sekiz sınır düğümüne tam çözüm dayatılır.

**Eksenel simetride "sabit gerilme" ne demek.** Düzlem problemlerde sabit
gerilme durumu doğrusal bir yer değiştirme alanıdır. Eksenel simetride bu
**doğru değildir**, çünkü $F_{tt} = 1 + u_r/R$ kinematiği yer
değiştirmenin kendisini içerir. Doğru seçim **düzgün genişlemedir**:
$u_r = (\lambda-1)R$, $u_z = (\lambda_z-1)Z$. Bu alanda
$F_{rr} = F_{tt} = \lambda$ olur, $F$ sabittir ve
$\sigma_{rr} = \sigma_{tt}$ olduğu için eksenel simetrik denge
denklemindeki hoop terimi kendiliğinden sıfırlanır — yani düzgün
genişleme gerçekten bir denge çözümüdür.

**Referans:** VER-032 (a) ile aynı malzeme durumu. $C_{10} = 0.6$,
$K = 10^5$, $\lambda = 1.1$ → her Gauss noktasında
$\sigma_{rr} = \sigma_{zz} = \sigma_{tt} =$ 33100.000000000.

**Tolerans:** 1e-12 bağıl.

**Gerekçe:** *Yuvarlama tabanı.* Yama testinde **ayrıklaştırma hatası
yoktur** — bilineer şekil fonksiyonları doğrusal alanı tam temsil eder.
Sapma varsa montaj, sınır koşulu, çözücü veya eleman yanlıştır. Tolerans
tartışmaya kapalıdır.

> **Newton toleransı ayrı tutulur.** Yama toleransı 1e-12 sabittir; ona
> ulaşabilmek için çözücünün durma ölçütü belirgin ölçüde sıkı olmalıdır
> (`tol_rel = 1e-14`). Aksi hâlde ölçülen sapma elemanın değil,
> çözücünün erken durmasının sonucu olur — ilk denemede tam bu oldu ve
> 2.9e-12 çıktı.

**Ölçülen:**

| Formülasyon | İç düğüm bağıl hata | 16 Gauss noktası max\|ΔF\| | σ bağıl hata |
|---|---|---|---|
| `full` | **1.7679e-16** | **0.0 (tam)** | **1.0991e-15** |
| `fbar` | **1.4523e-15** | 4.4409e-16 | **1.9784e-15** |

**Uygulama:** `test/check_patch.f90`

### VER-034 — Kalın cidarlı silindir, iç basınç · **GEÇTİ** · v0.1 KAPISI

Programın gerçek bir mühendislik problemini analitik çözümle uyumlu
çözdüğünün ilk kanıtı.

**Kurulum.** $A = 1$, $B = 2$, $C_{10} = 0.6$, $K = 10^5$
($K/C_{10} = 1.67\times10^5$). İki uçta $u_z = 0$ → düzlem şekil
değiştirme, $\lambda_z = 1$. Radyal yönde 16 eleman.

**Yer değiştirme kontrolü, yük kontrolü değil.** Bu problemde iç basınç
şişmeyle birlikte bir üst değere doyar; yük kontrollü çözüm doyma
bölgesinde kötü koşullanır ve v0.1'de yay uzunluğu (arc-length) yoktur.
$u_r(A)$ dayatılıp basınç reaksiyondan okunur.

**Basıncın reaksiyondan okunması.** `des_bc` elemeyi matrise uygular,
artığa değil; yakınsamış durumda dayatılmış serbestlikteki artık
doğrudan mesnet tepkisidir:

$$P = \frac{\text{iç düğümlerdeki toplam radyal artık}}{a \cdot L},
\qquad a = A + u_r(A)$$

Ölçek radyan başınadır; tam çevre konvansiyonundaki $2\pi$ hem
reaksiyonda hem alanda bulunduğu için $P$ aynı çıkar.

**Ölçülen** (F-bar, radyal 16 eleman):

| $u_r(A)$ | P (hesap) | P (ref) | bağıl | $u_r(B)$ (hesap) | $u_r(B)$ (ref) | bağıl |
|---|---|---|---|---|---|---|
| 0.100 | 0.157906056 | 0.157874734 | **1.98e-04** | 0.051828904 | 0.051828453 | **8.71e-06** |
| 0.250 | 0.330893283 | 0.330853844 | **1.19e-04** | 0.136002064 | 0.136000936 | **8.29e-06** |
| 0.500 | 0.513890260 | 0.513874091 | **3.15e-05** | 0.291290077 | 0.291287847 | **7.65e-06** |

**Toleranslar — iki ayrı büyüklük, iki ayrı gerekçe.** Spesifikasyon
1e-3 ile başlamayı ve ölçülen çok daha iyiyse daraltmayı istiyordu;
ölçüldü ve daraltıldı.

| Büyüklük | Tolerans | Gerekçe |
|---|---|---|
| Basınç | **5e-4** | *Ayrıklaştırma.* Q4 ikinci mertebe; ölçülen mertebe 2.006/2.035, 16 elemanda hata 1.19e-04…1.98e-04. Tolerans ~2.5 kat pay. |
| $u_r(B)$ | **5e-5** | *Fiziksel sapma.* $u_r(B)$ sıkıştırılamazlığın doğrudan sonucudur ($b^2-a^2 = B^2-A^2$) ve gerilme içermez; ayrıklaştırma neredeyse hiç girmez. Ölçülen 7.65e-06…8.71e-06, yani tam olarak $\mu/K = 1.2\times10^{-5}$ tabanında. ~6 kat pay. |

### VER-034 D2 — Kilitlenme çalışması

**ADR-0009 (c)'nin doğrulanması: formülasyon çalışma zamanı seçimidir.**
Aynı ağ, aynı malzeme, tek fark formülasyon.

| $u_r(A)$ | P (`full`) | bağıl hata | P (`fbar`) | bağıl hata | full/fbar |
|---|---|---|---|---|---|
| 0.100 | 2.296980751 | **13.55** | 0.157906056 | 1.98e-04 | **14.55×** |
| 0.250 | 3.638946383 | **10.00** | 0.330893283 | 1.19e-04 | **11.00×** |
| 0.500 | 3.793776147 | **6.38** | 0.513890260 | 3.15e-05 | **7.38×** |

Tam integrasyon $K/C_{10} = 1.67\times10^5$'te ders kitabı ölçüsünde
kilitleniyor: basıncı 7–15 kat fazla veriyor. F-bar kilitlenmeyi
tamamen gideriyor.

`full` için **tolerans konmamıştır** — kilitlenmesi beklenen
davranıştır. Testin geçme koşulu `fbar` üzerindendir; tek iddia
`fbar`ın `full`den daha doğru olmasıdır.

### VER-034 D3 — Ağ yakınsaması

F-bar, $u_r(A) = 0.25$:

| Radyal eleman | P (hesap) | bağıl hata |
|---|---|---|
| 4 | 0.331502890 | 1.9617e-03 |
| 8 | 0.331015481 | 4.8854e-04 |
| 16 | 0.330893283 | 1.1920e-04 |

**Ölçülen mertebe: 2.006 (4→8) ve 2.035 (8→16).** Q4 için beklenen
$O(h^2)$ ile birebir.

#### Ağ neden 16'da kesiliyor — ölçüldü

Referans **tam sıkıştırılamaz** çözümdür; ayrık çözüm ise sonlu $K$'lı
**sıkıştırılabilir** çözüme yakınsar. Aradaki fark sabit bir kaymadır ve
burada **negatiftir** (~ −4e-06). Ayrıklaştırma hatası ise **pozitif** ve
$O(h^2)$'dir. Ters işaretli oldukları için ağ inceltildikçe birbirlerini
götürürler:

| Eleman | P | işaretli hata | mertebe |
|---|---|---|---|
| 4 | 0.331502890 | +1.9617e-03 | — |
| 8 | 0.331015481 | +4.8854e-04 | 2.006 |
| 16 | 0.330893283 | +1.1920e-04 | 2.035 |
| 32 | 0.330862675 | +2.6690e-05 | 2.159 |
| 64 | 0.330855073 | +3.7144e-06 | **2.845** ← sahte |
| 128 | 0.330853162 | **−2.0605e-06** | 0.850 ← işaret döndü |
| 256 | 0.330852685 | −3.5034e-06 | **−0.766** ← hata büyüyor |

**İki tuzak, ikincisi daha sinsi:**

1. 128'den sonra hata **tekrar büyür** ve ölçülen mertebe negatif çıkar.
   Bu bir regresyon değildir — ayrık çözüm doğru yere yakınsamaktadır,
   referans başka bir yerdedir.

2. Sıfır geçişinden hemen önce (32→64) mertebe **2.845** ölçülür. Bu
   **sahte bir üstün yakınsamadır** ve Q4'ün ikinci mertebeden iyi olduğu
   izlenimini verir. Yakınsama mertebesi ölçen biri tam buraya denk
   gelirse yanlış sonuç raporlar.

Bu yüzden mertebe ölçümü 4–8–16 aralığında yapılır: orada ayrıklaştırma
hatası, sıkıştırılabilirlik kaymasının iki mertebe üstündedir ve ölçülen
mertebe temizdir. Daha ince ağda mertebe ölçmek gerekirse $K$ büyütülmeli
veya referans sonlu $K$ için çözülmelidir.

> **Tolerans, ağın bir fonksiyonudur.** Basınç toleransı (5e-4) 16
> elemanlı ağa göre seçilmiştir; 8 elemanda hata 4.89e-04'e çıkar ve kıl
> payı geçer. **Ağ, testin tanımının parçasıdır** — ayarlanabilir bir
> parametre değildir.

**Uygulama:** `test/check_cylinder.f90`

---

## Sürümlere göre dağılım

| Sürüm | Problemler | Sayı |
|---|---|---|
| v0.0.1 | VER-001, 002, 031 | 3 · **GEÇTİ** |
| v0.0.2 | VER-032 | 1 · **GEÇTİ** |
| v0.1 | VER-033, 034 | 2 · **GEÇTİ** |
| v0.1 | VER-010, 011, 014, 017, 018, 019, 024 | 7 |
| v0.2 | VER-012, 027 | 2 |
| v0.3 | VER-013, 015, 016, 020, 021, 025, 026, 028 | 8 |
| v0.4 | VER-003 … 009, 029 | 8 |
| v0.5 | VER-022, 023, 030 | 3 |

---

## Bir doğrulama problemi eklemek

1. Bir VER-xxx numarası al.
2. **Bağımsız referansı** belirle. Kendi çıktın referans değildir.
3. Toleransı **önceden** yaz ve gerekçesini yukarıdaki dört kategoriden
   birine bağla.
4. Testi `test/` altına belirlenimci biçimde yaz — rastgele girdi yok.
5. Test çıktısı "GEÇTİ" değil, **ölçülen sayıyı ve toleransı** bastırsın.
6. Bu belgeye satırı ekle; geçtiğinde durumu ve ölçülen değeri yaz.
