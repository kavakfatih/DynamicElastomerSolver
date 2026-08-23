# DES/26 Yol Haritası

**Tarih yoktur.** Bir sürüm, kapısındaki koşullar sağlandığında çıkar.

Bu bir üslup tercihi değil, bir doğrulama kuralıdır. Tarihe bağlanmış bir
sürüm, tarih yaklaştığında toleransların gevşetilmesi için baskı üretir.
Kapıya bağlanmış bir sürüm üretmez.

---

## v0.0.1 — malzeme çekirdeği · **ÇIKTI**

Malzeme sözleşmesi, sıkıştırılabilir Neo-Hookean, doğrulama altyapısı.
Ağ, eleman ve çözücü yok.

**Kapı — geçildi:**
- Malzeme arayüzü donduruldu, ADR yazıldı
- VER-001 (tek eksenli) ve VER-002 (tanjant) geçti
- Üç platform × iki yapı türünde sıfır uyarıyla derleniyor

---

## v0.1 — ilk gerçek çözüm

Eksenel simetrik Q4 elemanı, F-bar, Newton-Raphson çözücüsü.

Bu sürümle **ilk kez bir parça çözülebilir**. Basit bir kauçuk halkanın
eksenel bastırılması, tork olmadan.

**Kapı:**
- Yama testi (patch test) geçmeli — sabit gerilme durumu makine
  hassasiyetinde yeniden üretilmeli. Bu tartışmaya kapalıdır: yama testini
  geçmeyen bir eleman, ağ inceltildikçe doğru cevaba yakınsamaz.
- Kalın cidarlı silindir (VER-010): analitik çözüme karşı doğrulanmış
- F-bar, hacimsel kilitlenmeyi K/mu = 1e5'te ölçülebilir biçimde
  gidermeli — kilitlenmiş ve F-bar sonuçları yan yana raporlanmalı
- Newton, geri adım (cut-back) ile ters dönmüş elemandan kurtulabilmeli

---

## v0.2 — BURULMA · **program burada kullanılabilir hâle gelir**

Eksenel simetrik + burulma (u_theta) formülasyonu. Tork-açı eğrisi.

Bu, projenin varlık sebebidir. v0.2 ile bir burulmalı titreşim damperi
kauçuğunun tork-açı karakteristiği hesaplanabilir — ki tasarım kararının
dayandığı asıl eğri budur.

**Kapı:**
- Saf burulma altındaki içi boş silindir, analitik çözüme karşı doğrulanmış
  (VER-012)
- Tork-açı eğrisi, doğrusal olmayan bölgede bağımsız bir referansla
  karşılaştırılmış
- Eleman arayüzü düğüm başına 3 DOF taşıyabildiğini göstermiş — bu, eleman
  sözleşmesinin ilk gerçek sınavıdır

---

## v0.3 — sıkıştırılamazlık ve ağ

Karışık formülasyon (mixed u-P), Q8 elemanı, üçgenler, TQMesh entegrasyonu,
üçlü yakınsama kriteri.

**Kapı:**
- inf-sup (LBB) koşulu sayısal olarak kontrol edilmiş — Q4/P0 gibi kararsız
  çiftler kullanılmadığı gösterilmeli
- Doğrusal çözücü, simetrik indefinite sistemleri çözebiliyor (eyer noktası
  sistemi ilk kez burada ortaya çıkar)
- Yakınsama kriteri üç ölçüte birden bakıyor: artık (residual) normu,
  düzeltme normu ve enerji. Tek ölçüt yanıltır; özellikle neredeyse
  sıkıştırılamaz malzemelerde artık küçülürken çözüm hâlâ yürüyor olabilir.
- TQMesh ile üretilen ağda yama testi geçiyor

---

## v0.4 — gerçek kauçuk

Ogden, viskoelastisite (Prony + WLF), Mullins hasarı, PARDISO / Apple
Accelerate doğrudan çözücüleri.

**Kapı:**
- Ogden, tek eksenli/iki eksenli/saf kayma deney verisine eş zamanlı
  oturtulabiliyor
- Viskoelastik gevşeme (relaxation), analitik Prony çözümüne karşı
  doğrulanmış
- WLF kaydırması, `mat_point_t` içindeki sıcaklık alanı üzerinden çalışıyor
  — **hiçbir malzeme imzası değişmeden.** Bu, v0.0.1'de sıcaklığı bağlama
  koymanın gerekçesinin sınavıdır.
- Durum değişkeni sınırları ve `project()` gerçek bir hasar modeliyle
  kullanılmış

---

## v0.5 — yeniden ağ örme

Otomatik yeniden ağ örme ve çözüm aktarımı. HDF5 sonuç dosyaları.

Büyük şekil değiştirmede ağ bozulur; damper kauçuğu %100 kayma açısına
kadar zorlanabilir. Yeniden ağ örmeden bu problemler çözülemez.

**Kapı:**
- Durum aktarımı, hasar değişkenlerini fiziksel aralıkta tutuyor
  (`project()` gerçek yükü altında)
- Aktarım sonrası denge artığı, aktarım öncesine göre kontrollü bir sınırda
- Yeniden başlatma (restart) gidiş-dönüşü bit düzeyinde aynı sonucu veriyor

---

## v0.6 — Qt arayüzü

PySide6 tabanlı grafik arayüz. Türkçe ve İngilizce.

Arayüz standart `tr()` ve Qt Linguist `.ts` / `.qm` dosyalarını kullanır;
altyapı v0.0.1'de kurulan `messages/*.toml` ile tutarlıdır
([ADR 0008](adr/0008-cok-dillilik.md)).

**Kapı:**
- Çekirdek metin üretmiyor — arayüz tüm mesajları koddan çeviriyor
- Ondalık ayırıcı: dosyalarda nokta, ekranda locale'e göre. Bu davranış
  test edilmiş olmalı.
- PySide6 dinamik bağlanmış (LGPLv3 gereği)

---

## v1.x — temas

Temas ve kendi kendine temas. Sürtünme.

**Kapı:**
- Temassız çözücü tam olarak doğrulanmış — 30 problemlik doğrulama
  planının kritik kısmı geçmiş olmalı
- Hertz temas problemi analitik çözüme karşı doğrulanmış

Temasın neden en sona bırakıldığı: [ADR 0005](adr/0005-temas-ertelendi.md).

---

## Sürüm kapısı kuralı

Bir sürüm, kapısındaki her madde **ölçülmüş ve raporlanmışsa** çıkar.

- "Çalışıyor gibi görünüyor" bir kapı değildir.
- "Test geçiyor" tek başına bir kapı değildir — hangi toleransla ve o
  toleransın gerekçesi nedir?
- Kapıyı geçemeyen bir özellik, sürümü geciktirmez: sürümden çıkarılır.
