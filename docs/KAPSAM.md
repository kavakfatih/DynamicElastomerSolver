# DES/26 Kapsamı

Bir çözücünün ne yapmadığı, ne yaptığı kadar önemlidir. Bu belge sınırları
çizer. Kapsam genişletme önerileri ADR ile yapılır, sessizce kod eklenerek
değil.

---

## İÇİNDE

### Analiz tipleri

- **Düzlem gerilme (plane stress)** — ince kauçuk membranlar, contalar.
- **Düzlem şekil değiştirme (plane strain)** — uzun prizmatik kesitler,
  uzun burçların orta bölgesi.
- **Eksenel simetrik (axisymmetric)** — dönel geometriler: burçlar,
  damper kauçuk halkaları, takoz gövdeleri.
- **EKSENEL SİMETRİK + BURULMA (u_theta)** — dönel geometri, eksen etrafında
  burulma yüklemesiyle. Bu, projenin varlık sebebidir.
- **Genelleştirilmiş düzlem şekil değiştirme** — sabit ama sıfır olmayan
  eksenel uzama; eksenel yük altındaki uzun burçlar için.

Burulmanın neden ayrıca sayıldığı: burulmalı titreşim damperi tasarımının
merkezinde tork-açı eğrisi vardır. Bunu eksenel simetrik bir kesitte
u_theta serbestlik derecesiyle çözmek, aynı problemi 3B'de çözmekten iki
mertebe ucuzdur. Genel amaçlı paketler bu formülasyonu ya vermez ya da
3B'ye zorlar.

### Malzemeler

- **Hiperelastik** — Neo-Hookean (v0.0.1), Ogden, Mooney-Rivlin, Yeoh (v0.4).
- **Viskoelastik** — Prony serisi, WLF zaman-sıcaklık kaydırması (v0.4).
- **Hasarlı** — Mullins etkisi, kalıcı yumuşama (v0.4).
- **Neredeyse sıkıştırılamaz formülasyonlar** — penaltı (v0.1), karışık u-p
  (mixed u-P) (v0.3).

Malzeme arayüzü kullanıcı malzemelerine açıktır; sözleşmeyi uygulayan her tip
çözücüye takılabilir ve kararlılık kontrolünü bedava alır.

### Sayısal yetenekler

- Büyük şekil değiştirme, büyük dönme (toplam Lagrange formülasyonu).
- Newton-Raphson, hat araması (line search) ve otomatik adım küçültme
  (cut-back) ile.
- F-bar ve B-bar hacimsel kilitlenme (locking) çareleri.
- Seçmeli indirgenmiş integrasyon (selective reduced integration).
- Q4, Q8 dörtgenler ve üçgen elemanlar.
- **Yeniden ağ örme (remesh) ve çözüm aktarımı** (v0.5).

### Platformlar

Windows, macOS (Apple Silicon ve Intel), Linux. gfortran ve Intel ifx.

---

## DIŞINDA — KALICI OLARAK

Aşağıdakiler ertelenmiş değildir. Kapsam dışıdır ve öyle kalacaktır.

### 3B

DES/26 bir 2B çözücüdür. Nokta.

Gerekçe: 2B kalmak, projenin tek gerçek rekabet avantajıdır. Eksenel
simetrik + burulma formülasyonuna, F-bar'a ve yeniden ağ örmeye harcanan
her saat, 3B'ye harcanmış olsaydı genel amaçlı paketlerin on yıl önce
geçtiği bir yolda geriden gitmek olurdu. Hedef ürünlerin — damper kauçuğu,
burç, takoz — ezici çoğunluğu dönel veya prizmatiktir; 2B bu geometrileri
tam olarak karşılar.

3B gereken bir problem varsa, doğru cevap DES/26'yı büyütmek değil, ticari
bir çözücü kullanmaktır.

### Metal plastisitesi

von Mises, kinematik pekleşme, sünme (creep) yok. Bu bir elastomer
çözücüsüdür. Metal parçalar (damper göbeği, burç kovanı) rijit veya
doğrusal elastik sınır koşulu olarak temsil edilir.

### Açık (explicit) dinamik

Merkezi fark zaman entegrasyonu, çarpma analizi, dalga yayılımı yok.
Elastomer bileşenlerin tasarım yükleri yarı-statik veya harmoniktir.
Açık dinamik tamamen farklı bir zaman entegrasyonu, kütle matrisi ve
kararlılık kısıtı ailesidir; iki paradigmayı tek kod tabanında taşımak
her ikisini de kötüleştirir.

### CFD, ısı transferi çözücüsü, akustik

Isıl-mekanik kuplaj için sıcaklık bir **girdi alanıdır** (`mat_point_t`
içindeki `temperature`), çözülen bir alan değil. Sıcaklık dağılımı gerekiyorsa
dışarıdan verilir.

---

## ERTELENDİ

Kapsam içindedir, sırasını bekler.

| Konu | Sürüm | Neden ertelendi |
|---|---|---|
| **Temas (contact)** | v1.x | Aşağıya bakınız |
| **Qt arayüzü** | v0.6 | Çekirdek oturmadan arayüz çizmek, iki kez çizmektir |
| **Yeniden ağ örme** | v0.5 | Çözüm aktarımı, sağlam bir durum sözleşmesi ister; sözleşme v0.0.1'de donduruldu ama kullanımı test edilmedi |
| **Ogden, viskoelastisite, Mullins** | v0.4 | Malzeme arayüzü önce tek bir malzemeyle doğrulanmalı |
| **PARDISO / Apple Accelerate** | v0.4 | Yoğun çözücü v0.3'e kadar yeter |

### Temas neden v1.x'e ertelendi

Temas, bir çözücünün en pahalı özelliğidir ve pahalılığı kod satırında
değil, **her şeyi bozmasında**dır: yakınsama davranışını, tanjantın
simetrisini, adım kontrolünü ve durum aktarımını aynı anda değiştirir.
Temassız bir çözücü doğrulanmadan temas eklemek, iki belirsizliği
birbirine karıştırmak demektir — bir yakınsama hatasının malzemeden mi
temastan mı geldiği anlaşılamaz.

Pratik tarafı: hedef ürünlerin önemli bir kısmı — yapıştırılmış damper
kauçuğu, vulkanize burç — temassız çözülebilir. Kauçuk metale bağlıdır,
ayrılmaz. Temas gerektiren vakalar (sıkı geçme montaj, kendi kendine temas)
gerçek ama azınlıktır.

Ayrıntı: [ADR 0005](adr/0005-temas-ertelendi.md).

---

## Sınırda duran şeyler

Bunlar kapsam kararı bekliyor; bir talep geldiğinde ADR açılacak.

- **Harmonik / frekans tanım alanı analizi.** Viskoelastik damper
  karakterizasyonu için doğal bir istek. Yarı-statik altyapıya oturur ama
  karmaşık (complex) aritmetik gerektirir.
- **Şekil optimizasyonu.** Parametre taraması Python katmanında zaten
  mümkün; gerçek gradyan tabanlı optimizasyon türev bilgisi ister.
- **Kordlu / takviyeli kauçuk.** Anizotropik hiperelastisite. Malzeme
  arayüzü buna hazırdır (tam 3x3 C alır), ama eleman tarafında lif yönü
  taşımak gerekir.
