# ADR 0004 — Copyleft bağımlılık yok, kaynak kodu okumak dahil

**Durum:** KABUL EDİLDİ

---

## Bağlam

DES/26, Business Source License 1.1 altında dağıtılır ve 2030-01-01'de
Apache License 2.0'a döner ([ADR 0003](0003-lisanslama.md)).

Bu, bağımlılık seçimini bir tercih değil bir kısıt hâline getirir: bugün
eklenen her kütüphane, hem BUSL altında dağıtılabilir hem de dört yıl sonra
Apache-2.0 altında dağıtılabilir olmalıdır.

Sonlu elemanlar dünyasında güçlü ve cazip GPL kütüphaneler vardır —
deal.II'nin bazı bileşenleri, bazı ağ üreticileri, bazı doğrusal
çözücüler. Bunları kullanmanın maliyeti önceden netleştirilmelidir.

## Karar

### İzin verilen

MIT, BSD-2-Clause, BSD-3-Clause, Apache-2.0, MPL-2.0, ISC, Zlib, Boost.

Serbestçe eklenir; atıf `NOTICE` dosyasına yazılır.

### Koşullu

**LGPL** — yalnızca **dinamik bağlama (dynamic linking)** ile ve bir ADR
kaydıyla.

### Yasak

GPL (tüm sürümler), AGPL, SSPL, "ticari kullanım yasaktır" kaydı taşıyan
her lisans ve lisansı belirsiz olan her şey.

> **Yasak, linklemenin ötesine geçer: KAYNAK KODUNU OKUMAYIN.**

Bu kural insan katkıcılar için de, yapay zekâ asistanları için de aynen
geçerlidir. Bir asistandan "şu GPL projesinin şu dosyasına bak, aynısını
yaz" istenmez.

**Algoritmayı makalesinden öğrenin.**

## Gerekçe

**Apache-2.0'a dönüş, GPL ile bağdaşmaz.** 2030'da DES/26 Apache-2.0
olacak. İçinde GPL bir bileşen varsa bu dönüş yapılamaz — GPL, türev eserin
tamamının GPL olmasını ister. Bugün eklenen bir GPL bağımlılık, 2030
taahhüdünü sessizce imkânsız kılar. Bu tür bir hata, fark edildiğinde
düzeltmesi en pahalı hatadır: kodun o bileşene dokunan her parçası yeniden
yazılmak zorundadır.

**AGPL, müşteri tarafında zehirlidir.** Bir otomotiv tedarikçisinin hukuk
departmanı, iç ağda çalışan AGPL bir bileşeni gördüğünde satın alma
sürecini durdurur. Teknik olarak haklı olup olmadıkları önemli değildir;
sonuç aynıdır.

**Kaynak okuma yasağının sebebi, "temiz oda" (clean room) ilkesidir.** GPL
bir kaynak dosyayı okuyup ardından aynı işi yapan kendi sürümünüzü yazmak,
türev eser iddiasına açıktır. "Ben sadece baktım, kopyalamadım" savunması
mahkemede ucuzdur, ve bu riski almanın teknik bir karşılığı yoktur.

Buna karşılık **yayımlanmış bir makaledeki matematik telif hakkına tabi
değildir.** Simo & Taylor'ın 1991 tarihli makalesindeki tutarlı tanjant
denklemini Fortran'a yazmak tamamen serbesttir. Bir GPL projesinin
`.cpp` dosyasını açıp aynı şeyi yazmak serbest değildir. Fark, kaynağın
biçiminde değil, hukuki niteliğindedir.

**FEBio (MIT) bu yüzden stratejik olarak değerlidir.** Olgun, doğrulanmış
bir hiperelastik FE çözücüsü ve lisansı okumaya, hatta kopyalayıp BUSL
altında yeniden lisanslamaya izin veriyor. Analitik çözümü olmayan
doğrulama problemlerinde karşılaştırma hedefi olarak kullanılabilir.

## Sonuçlar

**Olumlu**

- 2030 Apache-2.0 dönüşü garanti altında
- Müşteri hukuk departmanı sorunsuz geçer
- Bağımlılık ağacı küçük kalıyor — v0.0.1'de sıfır dış bağımlılık var
- "Temiz oda" disiplini, kod kalitesine de yarıyor: bir algoritmayı
  makalesinden anlayıp yazmak, bir uygulamayı taklit etmekten daha derin
  bir kavrayış üretiyor

**Olumsuz**

- Bazı iyi kütüphaneler dışarıda kalıyor. Özellikle bazı olgun ağ
  üreticileri ve seyrek doğrusal çözücüler GPL.
- Kendi Cholesky'mizi yazmak zorunda kaldık (`des_tensor.f90`). Küçük bir
  maliyet, ama sıfır değil.
- Kural, bir geliştiricinin merakını kısıtlıyor ve bunu kabullenmek gerek:
  "nasıl yapmışlar" diye bakmak yasak.
- Kural yalnızca disiplinle işler; CI'daki lisans denetimi `src/` altında
  GPL metni arar ama bir geliştiricinin ne okuduğunu denetleyemez.

## Değerlendirilen alternatifler

**GPL bağımlılığa izin ver, DES/26'yı GPL yap.** Reddedildi:
[ADR 0003](0003-lisanslama.md) gerekçeleri — müşteri tarafında zehirli ve
ticari modeli ortadan kaldırıyor.

**GPL bileşenleri ayrı bir işlem (process) olarak çalıştır.** Hukuken
savunulabilir bir yol: ayrı süreçler arası iletişim, türev eser sayılmaz
(tartışmalı olsa da). Reddedildi: bir doğrusal çözücüyü ayrı süreçte
çalıştırmanın veri aktarım maliyeti, Newton döngüsünün içinde kabul
edilemez. Bir de "tartışmalı" kelimesi, bir tedarikçi denetiminde
istenmeyen bir kelimedir.

**Kaynak okumaya izin ver, yalnızca linklemeyi yasakla.** Yaygın bir
yorum. Reddedildi: risk/fayda oranı kötü. Faydası "biraz daha hızlı
öğrenmek", riski "türev eser iddiası". Makaleler zaten mevcut.

**Lisans denetimini yalnızca insan gözden geçirmesine bırak.** Reddedildi:
CI'ya ayrı bir iş olarak lisans denetimi eklendi (`.github/workflows/ci.yml`
içindeki `lisans-denetimi`). Otomatik denetim her şeyi yakalamaz ama
kopyala-yapıştır bir GPL başlığını yakalar, ve bu en olası kaza türüdür.
