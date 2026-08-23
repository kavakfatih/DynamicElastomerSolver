# ADR 0006 — Malzeme sözleşmesi donduruldu

**Durum:** KABUL EDİLDİ · **DONDURULMUŞ SÖZLEŞME 1/4**

Uygulama: [`src/des_material.f90`](../../src/des_material.f90)

---

## Bağlam

Malzeme arayüzü, DES/26'nın en çok genişletilecek noktasıdır. v0.4'te
Ogden, viskoelastisite ve Mullins gelecek; ileride kullanıcı malzemeleri
eklenebilecek. Aynı arayüz, v0.1'den v1.x'e kadar beş farklı eleman
formülasyonuna hizmet edecek.

Bu arayüz yanlış tasarlanırsa, her yeni malzeme ve her yeni eleman onu
biraz daha eğip büker; üç yıl sonra kimsenin dokunamadığı bir şeye dönüşür.

Referans noktaları: ANSYS USERMAT, MSC Marc HYPELA2, Abaqus UMAT. Bu
arayüzler on yıllarca kullanıldı ve neyin işe yaradığı biliniyor.

## Karar

```fortran
subroutine eval(this, C, pt, state_n, S, CC, state_np1, stat, dt_factor)
   class(material_t),      intent(in)    :: this
   real(dp),               intent(in)    :: C(3,3)
   type(mat_point_t),      intent(in)    :: pt
   type(material_state_t), intent(in)    :: state_n
   real(dp),               intent(out)   :: S(3,3)
   real(dp),               intent(out)   :: CC(3,3,3,3)
   type(material_state_t), intent(inout) :: state_np1
   integer(ip),            intent(out)   :: stat
   real(dp),               intent(out)   :: dt_factor
end subroutine
```

### Üç tasarım kuralı

**1. Malzeme her zaman tam 3x3 C alır ve analiz tipini asla bilmez.**

Düzlem şekil değiştirme, eksenel simetrik, burulmalı ve genelleştirilmiş
düzlem şekil değiştirme — hepsi malzemeye tam bir 3x3 sağ Cauchy-Green
tensörü uzatır. Malzeme hangisi olduğunu sormaz, sorамaz.

**2. Malzeme tahsis etmez, dosya açmaz, yazdırmaz, durmaz.**

Hata `stat` ile, adım küçültme talebi `dt_factor` ile bildirilir.
`state_np1` çağıran tarafından önceden tahsis edilir.

**3. `state_n` `intent(in)`dir ve değiştirilemez.**

## Gerekçe

### Neden tam 3x3

Bu kararın alternatifi, malzemeye indirgenmiş bir gerilme/şekil değiştirme
vektörü (Voigt) ve bir analiz tipi bayrağı vermektir. O yol seçilseydi:

- Her malzeme, desteklediği her analiz tipi için ayrı bir dal taşırdı
- Yeni bir eleman formülasyonu (v0.2'deki burulma), **mevcut bütün
  malzemeleri** değiştirmeyi gerektirirdi
- Düzlem gerilme durumu, malzemenin içinde bir sıfırlama yinelemesi
  gerektirir; bu, her malzemeye ayrı ayrı yazılırdı

Tam 3x3 ile: burulma eklemek malzeme kütüphanesine hiç dokunmaz. Eleman,
kendi kinematiğinden 3x3 C'yi kurar ve uzatır. **Bir malzeme, hiç
tanımadığı bir eleman tipiyle çalışır.**

Maliyeti: düzlem gerilmede C'nin 33 bileşeni bilinmez ve eleman tarafında
bir yinelemeyle bulunmalıdır. Bu maliyet bilinçli olarak elemana yüklendi —
eleman sayısı malzeme sayısından az olacak.

### Neden `pt` (mat_point_t) var

`pt` bir dolaylama katmanıdır. İçinde bugün kullanılmayan alanlar var:

```fortran
real(dp)    :: temperature = 293.15   ! K
real(dp)    :: time        = 0.0      ! artımın BAŞINDAKİ toplam zaman
real(dp)    :: dt          = 0.0
real(dp)    :: radius      = 0.0      ! eksenel simetride r
integer(ip) :: element     = 0        ! tanılama
integer(ip) :: point       = 0        ! tanılama
```

**Sıcaklık şimdi konulmazsa, WLF zaman-sıcaklık kaydırması eklenirken HER
malzemenin imzası kırılır.** v0.4'te viskoelastisite geldiğinde sıcaklık
zorunlu olacak. O gün imzayı değiştirmek, o tarihte var olan bütün
malzemeleri ve bütün çağrı yerlerini dokundurmak demektir.

`pt` sayesinde ileride alan eklemek hiçbir malzemeyi etkilemez: mevcut
malzemeler yeni alanı okumaz, yeni malzemeler okur.

`element` ve `point` alanları tanılama içindir. Malzeme bunları yazdıramaz
(kural 2) ama `stat` ile birlikte üst katmana taşınabilirler; kullanıcı
"eleman 2871, nokta 3'te eleman ters dönmüş" mesajını böyle görür.

### Neden `dt_factor` zorunlu, opsiyonel değil

UMAT'taki PNEWDT ile aynı rol:

- `1.0` — artım sorunsuzdu
- `< 1.0` — çözücüden bu oranda küçültme iste
- `> 1.0` — büyümeye izin ver

Opsiyonel yapılsaydı, çoğu malzeme onu yazmazdı ve çözücü varsayılan
davranışa düşerdi. **Bu olmadan malzeme "başarısız oldum" diyebilir ama
"daha küçük adımla olurdu" diyemez** — ki pratikte asıl vaka budur. Bir
elastomer analizinde yakınsama sorunlarının çoğu, adım küçültmeyle
çözülebilecek türdendir.

Zorunlu tutmak, malzeme yazarını bu konuda düşünmeye zorlar. Bu, arayüzün
öğretici bir tarafıdır.

### Neden `state_n` değiştirilemez

Çözücü, aynı malzeme noktasını aynı `state_n` ile **defalarca** çağırır:

- Newton yinelemesinin her adımında
- Hat araması (line search) sırasında her deneme adımında
- Geri adım (cut-back) sonrası, aynı artımı yeniden denerken

Malzeme, bunun kaçıncı çağrı olduğunu bilemez ve bilmemelidir. `state_n`
yazılabilir olsaydı, ikinci çağrı birinciden farklı sonuç verirdi ve bu
hata, yalnızca hat araması devreye girdiğinde ortaya çıkardı — hata
ayıklaması en zor sınıftan.

### Neden durum aktarımı bu tipte

`serialise` / `restore` / `project`, `material_state_t` üzerindedir.
Kilit gözlem: **geri adım, yeniden başlatma ve yeniden ağ örme aynı
mekanizmadır.** Üçü de "durumu bir tampona yaz, sonra geri oku"ya
indirgenir.

`project()`, yeniden ağ örme sonrası interpolasyonun fiziksel aralık
dışına taşırdığı değişkenleri (hasar gibi) geri kırpar. Sınırsız
bırakılmış bileşenlere dokunmaz.

Tampon küçükse `serialise` ve `restore` **-1 döndürür ve hedefe
dokunmaz.** Yarım yazılmış bir durum, hiç yazılmamış durumdan tehlikelidir:
ilki sessizce yanlış sonuç verir, ikincisi hemen fark edilir.

### Neden kararlılık kontrolü temel sınıfta

`check_stability => check_drucker` yalnızca `eval`e dayanır. Bu yüzden
**bütün malzemeler kontrolü bedava alır** — bugün yazılmamış olanlar dahil.
Bir kullanıcı malzemesi yazan mühendis, kararlılık kontrolünü ayrıca
düşünmek zorunda kalmaz.

Kriterin anlamı ayrı bir tartışmadır:
[ADR 0007](0007-kararlilik-kriteri.md).

## Sonuçlar

**Olumlu**

- v0.2'de burulma eklenirken malzeme kütüphanesine dokunulmayacak
- v0.4'te WLF eklenirken imza değişmeyecek
- Kullanıcı malzemeleri kararlılık kontrolünü ücretsiz alıyor
- Geri adım, restart ve remesh tek mekanizma paylaşıyor

**Olumsuz**

- Düzlem gerilme, eleman tarafında bir yineleme gerektiriyor
- Tam 3x3 ve tam 4. mertebe tanjant, indirgenmiş gösterimden daha fazla
  bellek ve işlem harcıyor. 3x3x3x3 = 81 sayı, simetriler kullanılsa 21
  yeterdi. Ölçüldüğünde darboğaz olursa, iç gösterim değişebilir; **arayüz
  değişmez**.
- `state_np1`in çağıran tarafından tahsis edilmesi, çağrı yerlerini biraz
  daha ayrıntılı yapıyor
- `check_stability` imzası `state_np1`i çalışma alanı olarak istiyor
  (çünkü içeride `eval` çağrılıyor ve malzeme tahsis edemez). Şık değil,
  ama kural 2'nin doğrudan sonucu.

## Değerlendirilen alternatifler

**Voigt vektörü + analiz tipi bayrağı.** Ticari çözücülerin çoğunun yolu.
Reddedildi: yukarıdaki "neden tam 3x3" gerekçeleri. Ayrıca Voigt
gösteriminde 2 ve 4 çarpanı muhasebesi, tanjant simetrisi tartışmalarında
klasik bir hata kaynağıdır. (Kararlılık kontrolünde bu yüzden ortonormal
Mandel bazı kullanılıyor — orada çarpan muhasebesi yoktur.)

**`state_n`i `intent(inout)` yapıp malzemenin güncellemesine izin vermek.**
Daha az parametre, daha basit imza. Reddedildi: hat araması ve geri adım
altında sessizce bozulur.

**`dt_factor`ı opsiyonel yapmak.** Reddedildi: yukarıya bakınız.

**Malzemenin kendi durumunu tahsis etmesine izin vermek.** Reddedildi:
sıcak döngüde tahsis, hem yavaş hem de iş parçacığı güvenliği (thread
safety) açısından sorunlu. Paralelleştirme v0.4'te gündeme gelecek ve o
gün bu karar işe yarayacak.

**Gerilmeyi Cauchy olarak döndürmek.** Reddedildi: toplam Lagrange
formülasyonu 2. Piola-Kirchhoff ile çalışır; Cauchy'ye çevirmek elemanın
işidir ve elemanın zaten F'si vardır.
