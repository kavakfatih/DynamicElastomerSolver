# Değişiklik Günlüğü

Bu dosyanın biçimi [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/)
esasına, sürüm numaralandırması [Semantic Versioning](https://semver.org/lang/tr/)
esasına dayanır.

Sürümlerde **tarih yoktur**. Bir sürüm, kapısındaki koşullar sağlandığında
çıkar — bkz. [docs/YOL-HARITASI.md](docs/YOL-HARITASI.md).

---

## [Yayımlanmadı]

Sıradaki: v0.1 — eksenel simetrik Q4 elemanı, F-bar, Newton çözücüsü,
yama testi (patch test), kalın cidarlı silindir doğrulaması.

---

## [0.0.1] — malzeme çekirdeği

İlk sürüm. Ağ (mesh), eleman ve çözücü **yoktur**; bu sürüm yalnızca malzeme
arayüzünü, ilk malzemeyi ve doğrulama altyapısını kurar.

### Eklendi

**Malzeme sözleşmesi** (`src/des_material.f90`) — dondurulmuş arayüz.
ANSYS USERMAT, Marc HYPELA2 ve Abaqus UMAT konvansiyonlarına göre
tasarlandı. Malzeme her zaman tam 3x3 sağ Cauchy-Green tensörü alır ve
analiz tipini asla bilmez; böylece tek malzeme kütüphanesi bütün 2B eleman
ailesine hizmet eder. Ayrıntı: [ADR 0006](docs/adr/0006-malzeme-sozlesmesi.md).

- `mat_point_t` — sıcaklık, zaman, zaman artımı, yarıçap ve tanılama
  alanlarını taşıyan bağlam tipi. Sıcaklık şimdiden konuldu; ısıl-mekanik
  kuplaj eklenirken hiçbir malzemenin imzası kırılmayacak.
- `material_state_t` — durum değişkenleri, fiziksel sınırlar ve
  `init` / `set_bounds` / `project` / `serialise` / `restore` yordamları.
  Geri adım (cut-back), yeniden başlatma (restart) ve yeniden ağ örme
  (remesh) aynı mekanizma üzerinden yürür.
- `material_t` — soyut temel tip. Türetilmiş malzemeler yalnızca `eval`
  yazar; kararlılık kontrolünü ve durum değişkeni adlandırmasını temel
  sınıftan alır.
- `dt_factor` zorunlu çıkış parametresi (UMAT'taki PNEWDT ile aynı rol).
  Bu olmadan malzeme "başarısız oldum" diyebilir ama "daha küçük adımla
  olurdu" diyemez.
- Hata kodları: `DES_MAT_OK`, `DES_MAT_SINGULAR`, `DES_MAT_NONPHYSICAL`,
  `DES_MAT_NOTCONV`, `DES_STAB_OK`, `DES_STAB_UNSTABLE`, `DES_STAB_UNKNOWN`.

**Sıkıştırılabilir Neo-Hookean malzemesi** (`src/des_mat_neohookean.f90`) —
hacimsel/izokorik ayrışmalı, penaltı formunda. Gerilme ve tutarlı tanjant
(consistent tangent) analitik olarak verilmiştir. Türetme:
[docs/teori/0001-hiperelastik-neo-hookean.md](docs/teori/0001-hiperelastik-neo-hookean.md).

**Tensör araçları** (`src/des_tensor.f90`) — 3x3 determinant, ters, iz,
Cauchy dönüşümü, ortonormal Mandel/Kelvin indirgemesi ve marj döndüren
Cholesky. Kararlılık kontrolü LAPACK'siz çalışır.

**Genel Drucker kararlılık kontrolü** — temel sınıfta bir kez yazıldı,
yalnızca `eval`e dayanır. Bütün malzemeler bunu bedava alır. Kriterin
neredeyse sıkıştırılamaz malzemelerdeki davranışı ölçüldü ve tartışmaya
açıldı: [ADR 0007](docs/adr/0007-kararlilik-kriteri.md).

**Doğrulama testleri**

- `check_material_tangent` (VER-002) — analitik tanjant, altı belirlenimci
  deformasyon gradyanında ve iki sıkıştırılabilirlik oranında merkezi farka
  karşı doğrulandı. Bağıl hata 1.9e-11 … 1.1e-10; major simetri 12 vakadan
  8'inde tam sıfır, en kötü 1.5e-16.
- `check_uniaxial` (VER-001) — yanal uzama, sigma_22 = 0 koşulundan ikiye
  bölmeyle çözüldü. Bağıl hata lambda = 1.05'te 4.8e-06, lambda = 3.0'da
  5.9e-05. Elastisite modülü 3.599986 (kesin sıkıştırılamaz değer 6·C10 =
  3.600000, sonlu K = 1e5 için analitik değer 3.599986).
- `check_contract` — sözleşme davranışı: serialise/restore gidiş-dönüşü,
  sınır kırpma, `det C <= 0` tespiti ve Drucker kararlılığı.

**Yapı ve altyapı** — CMake 3.20+ ve fpm; GitHub Actions üzerinde Linux,
macOS (arm64) ve Windows × Debug/Release; ayrı bir iş olarak lisans denetimi.

**Dokümantasyon** — mimari, kapsam, yol haritası, sekiz ADR, Neo-Hookean
teori türetmesi, ASME V&V 10 çerçevesinde 30 problemlik doğrulama planı.

**Çok dillilik altyapısı** — `messages/tr.toml` ve `messages/en.toml`.
Fortran çekirdeği metin üretmez, kod döndürür. Ondalık ayırıcı dosyalarda
her zaman noktadır. Ayrıntı: [ADR 0008](docs/adr/0008-cok-dillilik.md).

### Bilinen sınırlar

- Ağ, eleman ve çözücü yok. Bu sürümle bir parça çözülemez.
- Tek malzeme: Neo-Hookean. Ogden, viskoelastisite ve Mullins v0.4'te.
- Drucker kararlılık kriteri, neredeyse sıkıştırılamaz malzemelerde J birden
  uzaklaşır uzaklaşmaz "kararsız" bildirir. Bu bir hata değil, kriterin
  tanımının sonucudur; ölçülmüş ve belgelenmiştir
  ([ADR 0007](docs/adr/0007-kararlilik-kriteri.md)).
- `README.en.md` henüz yazılmadı.
