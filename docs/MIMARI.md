# DES/26 Mimarisi

Bu belge, sistemin katmanlarını ve katmanlar arası sözleşmeleri tanımlar.
Kod yazmadan önce okunur.

---

## Beş katman

Bağımlılık **yalnızca aşağı yönlüdür**. Bir katman, kendisinden yukarıdaki
hiçbir katmanı bilmez, çağırmaz, `use` etmez.

```
  ┌─────────────────────────────────────────────────────┐
  │ 1  SUNUM                          Qt / CLI / Python │
  │    Kullanıcıya görünen her şey. Metin burada üretilir│
  └────────────────────────┬────────────────────────────┘
                           │
  ┌────────────────────────▼────────────────────────────┐
  │ 2  UYGULAMA                                  Python │
  │    İş akışı, senaryo kurulumu, sonuç toplama        │
  └────────────────────────┬────────────────────────────┘
                           │
  ┌────────────────────────▼────────────────────────────┐
  │ 3  AĞ ve GEOMETRİ                               C++ │
  │    Ağ üretimi, geometri işlemleri, yeniden ağ örme  │
  └────────────────────────┬────────────────────────────┘
                           │
  ═══════════════════ C ABI SINIRI ═══════════════════════
                           │
  ┌────────────────────────▼────────────────────────────┐
  │ 4  ANALİZ ÇEKİRDEĞİ                    Fortran 2018 │
  │    Malzemeler, elemanlar, Newton, zaman entegrasyonu│
  └────────────────────────┬────────────────────────────┘
                           │
  ┌────────────────────────▼────────────────────────────┐
  │ 5  SAYISAL TEMEL                       Fortran 2018 │
  │    Tensör cebiri, doğrusal cebir, kök bulma         │
  └─────────────────────────────────────────────────────┘
```

### Neden bu sınırlar

**Fortran, katman 4-5'te.** Hesaplama çekirdeği sıkı iç içe döngülerden
oluşur: her integrasyon noktasında bir malzeme değerlendirmesi, her
elemanda bir sertlik matrisi. Fortran'ın dizi semantiği ve takma ad
(aliasing) varsayımları bu döngülerde derleyiciye C'den daha fazla alan
bırakır, dil de altmış yıldır tam olarak bu iş için ayarlanmıştır.

**C++, katman 3'te.** Ağ üretimi ve geometri, işaretçi ağırlıklı veri
yapıları, yarım-kenar (half-edge) topolojileri ve şablonlu geometrik
yüklemler ister. Bu, Fortran'ın rahat olduğu bir alan değildir.

**Python, katman 1-2'de.** İş akışı, dosya biçimleri, parametre taraması ve
grafik. Burada geliştirme hızı çalışma zamanı hızından önemlidir.

**C ABI sınırı, 3 ile 4 arasında.** Fortran ile C++ arasındaki tek geçiş
noktası düz bir C arayüzüdür: türetilmiş tipler, istisnalar veya şablonlar
sınırı geçmez. Ayrıntı: [ADR 0002](adr/0002-c-abi-siniri.md).

### Katman 4'ün üç yasağı

Analiz çekirdeği (`src/`):

1. **Yazdırmaz.** `print`, `write(*,...)` yok. (Karakter değişkenine yapılan
   iç yazma G/Ç sayılmaz.)
2. **Durmaz.** `stop`, `error stop` yok.
3. **Dosya açmaz.** `open`, `read`, `close` yok.

Sebep: aynı çekirdek hem bir CLI'dan, hem Qt arayüzünden, hem de toplu bir
Python betiğinden çağrılacak. Hangisinin çalıştığını bilemez; kullanıcıya
nasıl hitap edileceğine, hatta bir kullanıcı olup olmadığına karar veremez.
Bir kütüphanenin `stop` çağırması, çağıranın kurtarma şansını elinden alır.

Bunun yerine: hata `stat` kodu ile, adım küçültme talebi `dt_factor` ile
bildirilir. Kodun insan diline çevrilmesi katman 1'in işidir
([ADR 0008](adr/0008-cok-dillilik.md)).

---

## Dört dondurulmuş sözleşme

Bu dört arayüz, üzerlerine yazılacak her şeyin temelidir. Değiştirmek için
önce ADR yazılır.

### 1. Malzeme arayüzü — DONDURULDU (v0.0.1)

Uygulama: `src/des_material.f90` · Karar: [ADR 0006](adr/0006-malzeme-sozlesmesi.md)

```fortran
subroutine eval(this, C, pt, state_n, S, CC, state_np1, stat, dt_factor)
```

Üç kural:

1. Malzeme **her zaman tam 3x3** sağ Cauchy-Green tensörü alır ve analiz
   tipini (düzlem şekil değiştirme / eksenel simetrik / burulmalı /
   genelleştirilmiş düzlem şekil değiştirme) **asla bilmez**. Böylece tek
   malzeme kütüphanesi bütün 2B eleman ailesine hizmet eder; yeni bir eleman
   formülasyonu hiçbir malzemeyi kırmaz.
2. Malzeme **tahsis etmez** (allocate), dosya açmaz, yazdırmaz, durmaz.
3. `state_n` **`intent(in)`dir ve değiştirilemez.** Çözücü; hat araması
   (line search), geri adım (cut-back) veya Newton yinelemesi sırasında aynı
   noktayı aynı `state_n` ile defalarca çağırabilir. Malzeme bunun kaçıncı
   çağrı olduğunu bilemez, bilmemelidir.

`dt_factor` zorunludur, opsiyonel değildir. Bu olmadan malzeme "başarısız
oldum" diyebilir ama "daha küçük adımla olurdu" diyemez — ki pratikte asıl
vaka budur.

### 2. Eleman arayüzü — DONDURULDU (v0.0.2)

Uygulama: `src/des_element.f90` · Karar: [ADR 0009](adr/0009-eleman-sozlesmesi.md)
Doğrulama: `test/check_element_contract.f90`

Soyut sözleşme yazıldı; gerçek bir eleman (eksenel simetrik Q4) v0.1'de
gelecek.

Üç gereklilik:

**Düğüm başına değişken serbestlik derecesi (DOF).** Eksenel simetrik eleman
düğüm başına 2 DOF (u_r, u_z), burulma eklendiğinde 3 DOF (u_r, u_z,
u_theta), karışık u-p formülasyonunda köşe düğümlerinde ek basınç DOF'u
taşır. Eleman kendi DOF haritasını bildirir; çözücü sabit bir sayı
varsaymaz.

**Eleman dışı global DOF.** Genelleştirilmiş düzlem şekil değiştirmede
eksenel uzama, tüm modele ait **tek bir** serbestlik derecesidir; hiçbir
düğüme ait değildir. Aynı şekilde burulma yüklemesinde toplam dönme açısı
tek bir global DOF olabilir. Bunun için yer bırakılmazsa, sonradan eklemek
montaj (assembly) kodunu baştan yazmayı gerektirir.

**Formülasyon stratejisi bir seçenek olarak taşınır:**
`full | srI | bbar | fbar | mixed_up`. Kauçukta tam integrasyon hacimsel
kilitlenme (volumetric locking) üretir; hangi çarenin kullanılacağı elemanın
değil, analizin kararıdır.

### 3. Doğrusal çözücü arayüzü — DONDURULDU (v0.1)

Uygulama: `src/des_linsolve.f90` — `analyse` / `factorize` / `solve` /
`inertia` / `free`.

Bu sürümdeki tek uygulama profil (skyline) LDL^T'dir ve **pivotlama
yapmaz**: simetrik pozitif tanımlı sistemlerde her zaman çalışır, genel
indefinite sistemlerde sıfır pivotla karşılaşırsa `DES_LIN_ZERO_PIVOT`
döndürür — sessizce yanlış cevap üretmez. Pivotlu bir uygulama
(Bunch-Kaufman veya seyrek doğrudan çözücü) v0.3'te karışık u-p ile
gelir; **arayüz o gün değişmeyecek.**

Arayüz **simetrik indefinite** sistemleri desteklemek zorundadır.

Sebep: karışık u-p formülasyonu bir eyer noktası (saddle point) sistemi
üretir. Basınç blokunun köşegeni sıfırdır; matris simetriktir ama pozitif
tanımlı **değildir**. Yalnızca Cholesky varsayan bir arayüz v0.3'te çöker.
Bu yüzden sözleşme baştan indefinite destekler ve LDL^T / Bunch-Kaufman
pivotlamasına yer bırakır.

### 4. Durum aktarımı — DONDURULDU (v0.0.1)

`serialise` / `restore` / `project`, `material_state_t` üzerinde.

Kilit gözlem: **geri adım, yeniden başlatma ve yeniden ağ örme aynı
mekanizmadır.** Üçü de "durumu bir tampona yaz, sonra geri oku"ya
indirgenir. Üçü için üç ayrı yol yazmak, üçünün de ayrı ayrı bozulması
demektir.

`project()` bunun tamamlayıcısıdır: yeniden ağ örme sonrası interpolasyon,
hasar gibi [0,1] ile sınırlı değişkenleri aralığın dışına taşıyabilir —
interpolasyon o sınırı bilmez. `project()` fiziksel aralığa geri kırpar,
sınırsız bırakılmış bileşenlere dokunmaz.

Tampon küçükse `serialise` ve `restore` **-1 döndürür ve hedefe
dokunmaz.** Yarım yazılmış bir durum, hiç yazılmamış durumdan çok daha
tehlikelidir.

---

## Katman 4 içindeki modüller (mevcut)

| Modül | Katman | Sorumluluk |
|---|---|---|
| `des_kinds` | 5 | Kayan nokta ve tamsayı tür tanımları |
| `des_tensor` | 5 | 3x3 tensör cebiri, Mandel indirgemesi, Cholesky |
| `des_material` | 4 | Malzeme sözleşmesi, durum tipi, kararlılık taraması |
| `des_mat_neohookean` | 4 | Sıkıştırılabilir Neo-Hookean malzemesi |
| `des_mesh` | 4 | Düğüm/eleman dizileri, DOF haritası, global DOF paylaşımı |
| `des_sparse` | 5 | CSR depolama, montaj, RCM sıralaması |
| `des_element` | 4 | Eleman sözleşmesi (soyut) |
| `des_elem_axi_q4` | 4 | Eksenel simetrik Q4, full ve F-bar |
| `des_bc` | 4 | Sınır koşulları, yük eğrileri, reaksiyon |
| `des_assemble` | 4 | Eleman katkılarının global sisteme montajı |
| `des_linsolve` | 5 | Doğrusal çözücü arayüzü + skyline LDL^T |
| `des_newton` | 4 | Yük adımlamalı tam Newton, geri adım |

`des_elem_axi_q4` v0.1'de yalnızca `DES_ANA_AXISYM` destekler; burulma
(`DES_ANA_AXISYM_TORSION`) v0.2'de aynı elemana eklenecektir.

`des_material` yalnızca `des_kinds` ve `des_tensor`a bağımlıdır. Hiçbir
malzeme başka bir malzemeyi bilmez.

---

## Kararlılık kontrolü nerede duruyor

Kararlılık kontrolü **temel sınıfta bir kez** yazılmıştır ve yalnızca
`eval`e dayanır. Bu, ileride eklenecek her malzemenin — Ogden,
viskoelastisite, Mullins, kullanıcı malzemeleri — kontrolü bedava alması
demektir.

Ölçüt **mod bazlı monotonluktur**: tek eksenli, eşit iki eksenli ve
düzlemsel deformasyon modlarında nominal gerilmenin uzamaya göre türevi
pozitif olmalıdır (`dP/dlambda > 0`). Yanal uzamalar, modun serbest Cauchy
bileşeni sıfır olacak şekilde ikiye bölmeyle çözülür.

Tam tanjantın pozitif tanımlılığı (Drucker koşulu) **kullanılmaz**:
sağlıklı bir Neo-Hookean onu sağlamaz, çünkü serbest enerji C uzayında
konveks değil polikonveksdir. Karşı örnek, üç bağımsız doğrulaması ve
ölçüt değişikliğinin gerekçesi: [ADR 0007](adr/0007-kararlilik-kriteri.md).

Bu bir tarama kontrolüdür, nokta kontrolü değil. Kalibrasyon ve model
doğrulama zamanında çağrılır; Newton döngüsünün içinde değil.

---

## Sayı biçimi

Girdi ve çıktı dosyalarında ondalık ayırıcı **her zaman noktadır**,
locale'den bağımsız. Virgül yalnızca ekranda gösterimde kullanılır.

Bir FEA modelinde `1,5` ile `1.5` karışırsa model sessizce yanlış okunur ve
sonuç makul görünmeye devam eder. Gerekçe ve uygulama:
[ADR 0008](adr/0008-cok-dillilik.md).
