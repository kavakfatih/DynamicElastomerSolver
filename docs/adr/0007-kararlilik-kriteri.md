# ADR 0007 — Kararlılık kriteri: Drucker mi, kuvvetli eliptiklik mi

**Durum:** ÖNERİLDİ — **karar bekliyor**

Bu ADR bir karar kaydetmiyor; ölçülmüş bir bulguyu kaydediyor ve bir karar
istiyor. Mevcut uygulama değiştirilmedi.

---

## Bağlam

v0.0.1'de genel bir kararlılık kontrolü, malzeme temel sınıfına konuldu
([ADR 0006](0006-malzeme-sozlesmesi.md)). Tasarım şöyleydi:

> Drucker kararlılığı `dS:dE > 0` ister. `dE = dC/2` ve `dS = (1/2)·CC:dC`
> ile bu koşul, `CC`'nin simetrik ikinci mertebe tensörler uzayında pozitif
> tanımlı olmasına indirgenir. Tanjantı ortonormal Mandel/Kelvin bazında
> 6x6 matrise indirge, Cholesky dene. Başarı = tam olarak pozitif
> tanımlılık.

Bu, olduğu gibi uygulandı ve doğru çalışıyor. Sorun uygulamada değil,
**kriterin ne söylediğinde**.

## Bulgu

Uygulama sırasında, F = diag(1.20, 0.95, 0.95) — yani %20 çekme, tamamen
sıradan bir elastomer durumu — için kontrol `DES_STAB_UNSTABLE` döndürdü.

Bunun bir port hatası olmadığı üç bağımsız yolla doğrulandı:

1. **Tanjant zaten doğrulanmış durumda.** VER-002, aynı deformasyon
   gradyanında `CC`'yi `S`'nin merkezi farkına karşı 1e-10 bağıl hatayla
   doğruluyor. Formül doğru.
2. **Mandel indirgemesi ve Cholesky teoriye karşı doğrulandı.** C = I'de
   marjın `2μ / (2μ·(2/3) + K)` olması gerekir; K = 1e3, μ = 1.2 için bu
   2.396e-03'tür ve ölçülen değer birebir aynıdır.
3. **Elle yeniden türetildi.** Aşağıdaki mekanizma analitik olarak
   doğrulandı.

### Mekanizma

Hacimsel tanjant:

$$
\mathbb{C}_{\text{vol}} = K\left[\, J(2J-1)\,(\mathbf{C}^{-1} \otimes \mathbf{C}^{-1})
\;-\; 2J(J-1)\,\mathbb{I}_{C} \,\right]
$$

İkinci terim `J > 1` için negatiftir ve `K` ile ölçeklenir. Kayma
bileşenlerinde `Cinv ⊗ Cinv` hiç katkı vermez (köşegen `C` için
`Cinv_12 = 0`), dolayısıyla orada **yalnızca negatif terim kalır**:

$$
\mathbb{C}_{1212} = \tfrac{1}{3} a_{\text{iso}} I_1 \,\mathbb{I}_{C,1212}
\;-\; 2KJ(J-1)\,\mathbb{I}_{C,1212}
$$

İkinci terim `K` mertebesinde, birincisi `C10` mertebesindedir.
`K/C10 ≫ 1` olan her malzemede ikincisi kazanır.

F = diag(1.20, 0.95, 0.95), C10 = 0.6, K/C10 = 1.7e3 için Mandel matrisi:

```
  5.3325E+02   9.9036E+02   9.9036E+02   0.0000E+00   0.0000E+00   0.0000E+00
  9.9036E+02   1.3586E+03   1.5807E+03   0.0000E+00   0.0000E+00   0.0000E+00
  9.9036E+02   1.5807E+03   1.3586E+03   0.0000E+00   0.0000E+00   0.0000E+00
  0.0000E+00   0.0000E+00   0.0000E+00  -1.3921E+02   0.0000E+00   0.0000E+00
  0.0000E+00   0.0000E+00   0.0000E+00   0.0000E+00  -2.2211E+02   0.0000E+00
  0.0000E+00   0.0000E+00   0.0000E+00   0.0000E+00   0.0000E+00  -1.3921E+02
```

Üç kayma köşegeni doğrudan negatif. Normal blok da pozitif tanımlı değil;
Cholesky ikinci pivotta düşüyor (normalize pivot -0.354).

### Eşik taraması

Saf hacimsel zorlanma (F = s·I), C10 = 0.6, normalize Cholesky marjı:

| K/C10 | J = 0.941 | J = 0.970 | **J = 1.000** | J = 1.015 | J = 1.061 | J = 1.093 |
|---|---|---|---|---|---|---|
| 1.7e1 | +3.15e-01 | +2.60e-01 | **+2.03e-01** | +1.16e-01 | +8.65e-02 | +2.61e-02 |
| 1.7e3 | +1.20e-01 | +6.17e-02 | **+2.35e-03** | −1.86e-01 | −2.54e-01 | −4.00e-01 |
| 1.7e5 | +1.18e-01 | +5.94e-02 | **+2.35e-05** | −1.91e-01 | −2.60e-01 | −4.05e-01 |

İzokorik zorlanma (F = diag(λ, 1/λ, 1), yani J = 1 tam):

| K/C10 | λ = 1.25 | λ = 1.50 | λ = 2.00 | λ = 2.50 |
|---|---|---|---|---|
| 1.7e1 | +5.33e-02 | +1.93e-02 | +2.38e-03 | +2.98e-04 |
| 1.7e3 | +6.57e-04 | +2.54e-04 | +6.40e-05 | +2.36e-05 |
| 1.7e5 | +6.58e-06 | +2.54e-06 | +6.43e-07 | +2.38e-07 |

### Bulgunun okunuşu

- Gerçekçi kauçuk için (`K/C10 ≈ 1e4 … 1e6`) kararlılık, **%0.5 hacimsel
  zorlanmada** kaybolur.
- `J = 1`'deki marj `1/(K/C10)` ile sıfıra yapışır: kriter neredeyse
  sıkıştırılamaz malzemede zaten bıçak sırtındadır.
- İzokorik durumlar λ = 2.5'e kadar "kararlı" kalır, ama marj yine
  `1/(K/C10)` ile söner — yani kararı belirleyen şey malzemenin fiziği
  değil, penaltı katılığıdır.

**Sonuç: bu kontrol, pratikte bir malzeme kararlılığı göstergesi değil,
bir "J ≈ 1 mi?" detektörüdür.**

## Bu neden bir hata değil

Drucker kararlılığı — referans konfigürasyonda, `S`–`E` eşleniği üzerinde
tanımlanan malzeme tanjantının pozitif tanımlılığı — iyi kurulmuş
hiperelastik modeller için **yeterli ama gereğinden çok güçlü** bir
koşuldur. Polikonveks ve kuvvetli eliptik malzemelerin bunu sonlu
deformasyonda ihlal etmesi, literatürde bilinen ve beklenen bir durumdur.
`S`, `E`'nin monoton bir fonksiyonu olmak zorunda değildir.

Yani kriter tam olarak tanımının gerektirdiğini yapıyor. Sorun,
kullanıcıya "kararsız" diye sunulan şeyin, kullanıcının anladığı
kararsızlık olmaması.

## Bu neden önemli

DES/26'nın hedef ürünlerinin hepsi neredeyse sıkıştırılamazdır. Dahası,
yol haritasının önemli bir kısmı (v0.1'de F-bar, v0.3'te karışık u-p) tam
olarak `J`'nin 1'den saptığı durumları yönetmek içindir.

İki somut risk:

1. **Newton yinelemesi sırasında yanlış alarm.** Ara yinelemelerde `J`
   geçici olarak 1'den uzaklaşır. Kararlılık bayrağı her yinelemede
   kırmızıya döner.
2. **Uyarı körlüğü.** Kullanıcı iki hafta içinde bu uyarıyı yok saymayı
   öğrenir. Bir kararlılık uyarısı için olabilecek en kötü sonuç budur —
   gerçek bir kararsızlık geldiğinde de görülmez.

## Değerlendirilen seçenekler

### (a) Olduğu gibi bırak, kriteri belgele

Kod değişmez; `DES_STAB_UNSTABLE`'ın anlamı dokümantasyonda ve
`messages/*.toml` içinde netleştirilir.

*Artı:* iş yok, sözleşme donmuş kalır.
*Eksi:* varsayılan davranış yanlış alarm üretmeye devam eder. Belgelemek,
kullanıcının okuyacağı anlamına gelmez.

### (b) Kuvvetli eliptiklik ekle, varsayılan yap — **önerilen**

`check_ellipticity` eklenir: akustik tensör

$$
Q_{ik}(\mathbf{n}) = A_{AiBk}\, n_A n_B, \qquad
A_{AiBk} = F_{iJ} F_{kL}\, \mathbb{C}_{AJBL} + S_{AB}\,\delta_{ik}
$$

her birim `n` yönünde pozitif tanımlı mı diye bakılır (2B'de yön açısı
taranarak). `check_stability` varsayılanı buna bağlanır; mevcut Drucker
kontrolü `check_tangent_pd` adıyla erişilebilir kalır.

*Artı:* gerçek malzeme kararsızlığını (lokalizasyon, kayma bandı) yakalar;
kullanıcıya anlamlı bir uyarı verir. Jeometrik (initial stress) terimi
içerdiği için Newton davranışıyla da daha ilgilidir.
*Eksi:* iş var. Yön taraması maliyetli (2B'de kabul edilebilir). Temel
sınıf sözleşmesi genişler — ADR 0006 güncellenmeli.

### (c) Yalnızca yeniden adlandır

Mevcut kontrol `check_tangent_pd` olur, `DES_STAB_*` kodları
`DES_TANPD_*` olur. "Kararlılık" adı ileride eliptikliğe ayrılır.

*Artı:* ucuz ve dürüst; yanlış isimlendirme hemen ortadan kalkar.
*Eksi:* kullanıcı hâlâ anlamlı bir kararlılık kontrolünden yoksun.

## Öneri

**(b)**, v0.4'te yapılmak üzere. O sürümde Ogden ve Mullins geliyor;
gerçek malzeme kararsızlığı ilk kez orada fiilen mümkün hâle gelecek
(Mullins yumuşaması yeterince ilerlediğinde eliptiklik gerçekten
kaybolabilir). Ara dönemde **(c)**'nin yeniden adlandırma kısmı ucuz bir
iyileştirme olur.

## Şimdilik yapılanlar

- Kod **değiştirilmedi**. Kriter, ADR 0006'da tanımlandığı gibi duruyor.
- `check_contract` testindeki kararlılık kontrolleri, spesifikasyonun
  gerçekten istediği iki iddiaya indirildi: C = I'de kararlı, C10 < 0'da
  kararsız. Üçüncü olarak izokorik bir deforme durum (λ = 1.3, J = 1)
  eklendi — kontrolün yalnızca C = I'de çalışmadığını göstermek için.
- Aynı teste **iddiaya bağlanmamış bir tanı taraması** kondu: J'ye karşı
  marj tablosu her CI çalışmasında basılıyor. Böylece bulgu görünür
  kalıyor, ama kriter ileride değiştirilirse sahte bir regresyon
  üretmiyor.

## Kaynaklar

- Truesdell & Noll, *The Non-Linear Field Theories of Mechanics*, §52 —
  Drucker koşulunun aşırı kısıtlayıcılığı
- Marsden & Hughes, *Mathematical Foundations of Elasticity*, böl. 6 —
  kuvvetli eliptiklik ve polikonvekslik
- Ogden, *Non-Linear Elastic Deformations*, §6.2 — akustik tensör ve
  yerel kararlılık
- Bonet & Wood (2008), böl. 6 — hacimsel/izokorik ayrışmalı tanjant
