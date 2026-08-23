# ADR 0005 — Temas v1.x'e ertelendi

**Durum:** KABUL EDİLDİ

---

## Bağlam

Temas (contact), elastomer bileşen analizinde sık istenen bir özelliktir:
sıkı geçme montajı, kauçuğun kendi kendine temas etmesi (self-contact),
metal parçalara oturma. Ticari çözücülerin hepsinde vardır ve yokluğu bir
eksiklik olarak algılanır.

Öte yandan temas, bir FE çözücüsüne eklenebilecek **en pahalı** özelliktir
ve pahalılığı kod satırı sayısında değildir.

## Karar

Temas v1.x'e ertelenir. v0.1–v0.6 arası sürümlerde temas yoktur.

Temasın kapısı: temassız çözücünün doğrulama planındaki kritik problemleri
geçmiş olması.

## Gerekçe

**Temas, her şeyi aynı anda değiştirir.** Eklenmesi şunları etkiler:

- **Yakınsama davranışı.** Temas durumu (açık/kapalı) her Newton
  yinelemesinde değişebilir; bu, düzgün olmayan (non-smooth) bir problem
  yaratır. Kuadratik yakınsama kaybolur.
- **Tanjantın simetrisi.** Sürtünmeli temas simetrik olmayan bir tanjant
  üretir. Doğrusal çözücü sözleşmesi ([MIMARI.md](../MIMARI.md), sözleşme 3)
  simetrik indefinite için tasarlandı; simetrik olmayan destek eklemek onu
  yeniden açmak demektir.
- **Adım kontrolü.** Temas durumu değişimi, adım küçültmenin en sık
  sebeplerinden biri hâline gelir ve `dt_factor` mantığı malzemeden
  temasa kayar.
- **Durum aktarımı.** Temas durumu da bir durumdur; yeniden ağ örmede
  taşınmalıdır.

**İki belirsizliği karıştırmamak.** Temassız bir çözücü doğrulanmadan
temas eklenirse, bir yakınsama hatasının malzemeden mi, elemandan mı,
temastan mı geldiği anlaşılamaz. Doğrulama, tek seferde tek bir belirsizlik
azaltmakla ilerler. Bu, ASME V&V 10 çerçevesinin de temel önermesidir.

**Hedef ürünlerin önemli bir kısmı temassız çözülebilir.** Yapıştırılmış
damper kauçuğu ve vulkanize burç, metale kimyasal olarak bağlıdır ve
ayrılmaz — sınır koşulu olarak temsil edilebilir. Motor takozlarının
tasarım yükü genellikle bağlı bölgede kalır. Temas gerektiren vakalar
(sıkı geçme montaj, büyük kayma açısında kendi kendine temas) gerçektir ama
azınlıktır.

**Burulma daha değerli.** v0.2'deki eksenel simetrik + burulma
formülasyonu, projenin ayırt edici özelliğidir ve genel amaçlı paketlerde
zayıf karşılanır. Temas ise her yerde vardır. Kıt geliştirme zamanını
rakiplerin iyi yaptığı bir işe değil, kötü yaptığı bir işe harcamak daha
akıllıcadır.

## Sonuçlar

**Olumlu**

- v0.1–v0.3, temiz bir doğrulama zinciri kurabiliyor: her sürümde tek bir
  yeni belirsizlik
- Doğrusal çözücü sözleşmesi simetrik durumda kalabiliyor (v0.3'e kadar
  simetrik indefinite yeter)
- Yakınsama kriterleri düzgün (smooth) problemler için ayarlanabiliyor

**Olumsuz**

- Bazı gerçek problemler v1.x'e kadar çözülemez. Bu, kullanıcı için somut
  bir eksikliktir ve öyle söylenmelidir; "yakında" denmemelidir.
- Temas eklendiğinde bazı erken kararlar yeniden açılacak. Özellikle
  doğrusal çözücü arayüzü simetrik olmayan desteği kazanmalı. Bu maliyet
  bilinçli olarak kabul ediliyor — o noktada çözücünün geri kalanı
  doğrulanmış olacağı için değişiklik güvenli yapılabilir.
- Rekabet karşılaştırmalarında bir eksik kutu.

## Değerlendirilen alternatifler

**v0.3'te basit tek taraflı temas (rijit yüzeye).** Cazip bir ara yol:
kauçuğun rijit bir metale oturması, sürtünmesiz, penaltı yöntemiyle. Tam
temasın karmaşıklığının küçük bir kısmı.

Reddedildi ama **kesin olarak değil**. Gerekçe: penaltı temasının bile
yakınsama etkisi var ve v0.3'te aynı anda karışık u-p formülasyonu
geliyor. İkisini birden devreye almak, bir yakınsama sorununun kaynağını
belirsizleştirir. Eğer v0.3 sorunsuz oturursa, v0.4'te sürtünmesiz rijit
temas yeniden değerlendirilebilir; bu durumda bu ADR güncellenir.

**Temas için harici bir kütüphane kullanmak.** Reddedildi: olgun temas
kütüphanelerinin çoğu GPL veya bir çözücüye sıkı bağlı
([ADR 0004](0004-copyleft-bagimlilik-yok.md)). Ayrıca temas, çözücünün
Newton döngüsünün içine girer; harici bir bileşen olarak takılabilir bir
şey değildir.

**Teması v0.1'de eklemek.** Reddedildi: yama testi (patch test) bile
geçmemiş bir elemanın üzerine temas eklemek, hata ayıklanamaz bir yığın
üretir.
