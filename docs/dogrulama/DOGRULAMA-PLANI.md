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
| **GEÇTİ** | 2 |
| Planlandı | 28 |
| **Toplam** | 30 |

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

## Sürümlere göre dağılım

| Sürüm | Problemler | Sayı |
|---|---|---|
| v0.0.1 | VER-001, 002 | 2 · **GEÇTİ** |
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
