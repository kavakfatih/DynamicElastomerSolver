# ADR 0003 — Business Source License 1.1

**Durum:** KABUL EDİLDİ

---

## Bağlam

DES/26 ticari bir mühendislik aracıdır ama kapalı kaynak olmasını
gerektiren bir sebep yoktur. İki hedef aynı anda tutulmak isteniyor:

1. Kaynak kod okunabilir, denetlenebilir ve akademik olarak kullanılabilir
   olsun. Bir FEA çözücüsünün doğruluğuna güvenmek, içine bakabilmeyi
   gerektirir; kapalı bir kutu, doğrulama iddialarını doğrulanamaz kılar.
2. Bir rakip, kodu alıp aynı pazarda ücretli bir hizmet olarak sunamasın.

Klasik açık kaynak lisansları (MIT, Apache) ikinciyi karşılamaz. Kapalı
kaynak birinciyi karşılamaz.

## Karar

**Business Source License 1.1** kullanılır.

| Parametre | Değer |
|---|---|
| Lisans Veren (Licensor) | Fatih Kavak |
| Lisanslı Eser (Licensed Work) | DynamicElastomerSolver 2026 (DES/26) |
| Ek Kullanım İzni | Akademik araştırma/eğitim + kuruluş başına 90 günlük değerlendirme |
| Değişim Tarihi (Change Date) | 2030-01-01 |
| Değişim Lisansı (Change License) | Apache License, Version 2.0 |

`LICENSE` dosyası **İngilizce ve değiştirilmeden** kalır. BUSL
taahhütlerinin 4. maddesi, lisans metninin parametreler dışında başka
şekilde değiştirilmesini yasaklar.

Resmi olmayan Türkçe çeviri `LISANS.tr.md` içindedir ve en üstte bağlayıcı
olmadığı büyük harfle belirtilir.

## Gerekçe

**BUSL, tam olarak bu sorunu çözmek için tasarlandı.** Kaynak açıktır,
üretim dışı kullanım serbesttir, üretim kullanımı Ek Kullanım İzni ile
sınırlıdır ve belirlenen tarihte lisans kendiliğinden açık kaynağa döner.
MariaDB, HashiCorp, Sentry ve Couchbase aynı modeli kullanıyor; hukuki
metin denenmiş durumda.

**Akademik izin, doğrulama için gerekli.** Bir çözücünün doğrulama
iddiaları, bağımsız araştırmacılar tarafından tekrar üretilebiliyorsa
anlamlıdır. Akademik kullanımı kısıtlamak, projenin en değerli geri bildirim
kanalını kapatırdı.

**90 günlük değerlendirme, satış döngüsünün gerçeğidir.** Bir mühendislik
ekibi, bir çözücüyü kendi problemleriyle denemeden satın almaz ve
denememeleri gerektiğini söylemek satış yapmanın yolu değildir.

**Değişim Tarihi bir taahhüttür, bir tehdit değil.** 2030'da bu sürüm
Apache-2.0 olur. Bu, kullanıcıya "proje ölürse elimde bir şey kalacak"
güvencesi verir — ticari bir araca bağlanırken sorulan ilk sorudur.

### Apache-2.0 neden geçerli bir Değişim Lisansı

BUSL taahhütlerinin 1. maddesi, Değişim Lisansı'nın "GPL Sürüm 2.0 veya
daha sonraki bir sürümüyle uyumlu" olmasını ister.

Apache-2.0, GPL-2.0 ile **uyumlu değildir** (patent ve tazminat maddeleri
yüzünden), ancak GPL-3.0 ile uyumludur. Taahhüt metni "GPL Version 2.0
**or a later version**" dediği için Apache-2.0 koşulu sağlar: Apache-2.0
altındaki yazılım, GPLv3 bir programa dâhil edilebilir.

Bu okuma sektörde yerleşiktir — Sentry aynı gerekçeyle Apache-2.0'ı
Değişim Lisansı olarak kullanıyor. Yine de bu, hukuki bir yorumdur;
lisanslama kesinleşmeden önce bir avukat görüşü alınması önerilir.

## Sonuçlar

**Olumlu**

- Kaynak açık, doğrulama iddiaları denetlenebilir
- Akademik kullanım ve değerlendirme serbest
- Rakip bir SaaS/lisans ürünü kuramaz (2030'a kadar)
- Terk edilme riskine karşı kullanıcıya güvence

**Olumsuz**

- **BUSL açık kaynak değildir.** OSI onaylı değil, FSF "özgür" saymaz.
  Bunu açık kaynak diye pazarlamak dürüst olmaz ve topluluk tepkisi çeker.
  README'de "Business Source License" olarak adlandırılır, "open source"
  olarak değil.
- Bazı kurumlar (özellikle kamu ve bazı büyük şirketler) OSI onaylı olmayan
  lisansları tedarik süreçlerinden geçirmekte zorlanır.
- GitHub, BUSL depolarını "lisanssız" göstermez ama otomatik lisans
  tespiti sınırlıdır; `.gitattributes` içinde `linguist-license` işareti
  konuldu.
- Katkı kabul etmek, katkıcı lisans sözleşmesi (CLA) gerektirebilir. Bu
  henüz kurulmadı; ilk dış katkıdan önce çözülmeli.

## Değerlendirilen alternatifler

**MIT / Apache-2.0.** En basit yol. Reddedildi: bir rakibin kodu alıp
ticari bir ürün olarak sunmasını engellemiyor ve bu projenin ticari
gerekçesini ortadan kaldırıyor.

**GPL-3.0 / AGPL-3.0.** Copyleft, rakibin kapalı ürün yapmasını engeller.
Reddedildi: müşteri tarafında zehirli. Bir otomotiv tedarikçisi, kendi
tasarım akışına GPL bir çözücü sokmak istemez; AGPL ise iç ağda çalıştırmayı
bile hukuk departmanına taşır. Ayrıca DES/26'nın kendi bağımlılık
politikasıyla ([ADR 0004](0004-copyleft-bagimlilik-yok.md)) tutarsız olurdu.

**Çift lisans (GPL + ticari).** Qt ve MySQL modeli. Reddedildi: iki ayrı
lisans metni, iki ayrı katkı yolu ve sürekli bir CLA yönetimi demek. Tek
kişilik bir projede yönetilebilir değil.

**Kapalı kaynak, ikili dağıtım.** Reddedildi: doğrulama iddiaları
denetlenemez hâle gelir. Bir FEA çözücüsü için bu, satılabilirliği
doğrudan azaltır — ciddi bir müşteri "sayılarınıza neden güveneyim"
sorusunu sorar.

**Elastic License 2.0 veya PolyForm.** Benzer hedefler. BUSL tercih edildi
çünkü otomatik açık kaynağa dönüş (Değişim Tarihi) mekanizması var ve daha
yaygın biliniyor.
