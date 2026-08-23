# Değişiklik Günlüğü

Bu dosyanın biçimi [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/)
esasına, sürüm numaralandırması [Semantic Versioning](https://semver.org/lang/tr/)
esasına dayanır.

Sürümlerde **tarih yoktur**. Bir sürüm, kapısındaki koşullar sağlandığında
çıkar — bkz. [docs/YOL-HARITASI.md](docs/YOL-HARITASI.md).

---

## [Yayımlanmadı]

### Değişti

- **Kararlılık ölçütü değişti** ([ADR 0007](docs/adr/0007-kararlilik-kriteri.md)).
  Tam tanjant pozitif tanımlılığı (Drucker) kaldırıldı; yerine üç
  deformasyon modunda nominal gerilmenin monotonluğu (`dP/dlambda > 0`)
  kondu. Sebep: sağlıklı bir Neo-Hookean (C10 = +0.6, K = 1e3) eski
  ölçütü sağlamıyor — `F = diag(1.40, 0.85, 0.85)` altında
  `dC:CC:dC = -3.9389e+01`. Serbest enerji C uzayında konveks değil,
  polikonveks. Penaltı tamamen kaldırıldığında bile izokorik kısım
  `lambda ~ 1.58`'den sonra ihlal ediyor.
- `check_stability` imzası: tek bir C yerine uzama aralığı ve mod listesi
  alıyor, ilk kararsızlığın (mod, lambda) çiftini döndürüyor. Kalibrasyon
  modülünün (v0.4) kullanacağı arayüz budur. **`eval` imzasına
  dokunulmadı.**
- `material_t`'ye `mu_ref` ve `kappa_ref` eklendi (normalizasyon ve
  hacimsel kararlılık raporu).
- README ve `docs/KAPSAM.md`: burulmanın pazar liderlerinde bulunmadığı
  yönündeki gerçek dışı iddia kaldırıldı. ANSYS PLANE182/183
  `KEYOPT(3)=6` ve Abaqus CGAX bunu yapıyor. Gerçek boşluk
  **burulma + yeniden ağ örme + hoop sürtünmesinin birlikte** olmaması.

### Eklendi

- **Eleman sözleşmesi donduruldu** ([ADR 0009](docs/adr/0009-eleman-sozlesmesi.md)) —
  `src/des_element.f90`. Düğüm başına değişken DOF, eleman-dışı global
  DOF, çalışma zamanı formülasyon seçimi, `quality()`, `serialise` /
  `restore`. Gerçek eleman uygulaması YOK; o v0.1'de.
- `src/des_mesh.f90` — düğüm/eleman dizileri ve DOF haritası. Global
  serbestlikler ANAHTAR üzerinden kaydedilir: aynı anahtarı isteyen her
  eleman aynı indisi alır. Her elemana ayrı serbestlik verilseydi model
  sessizce yanlış çözülürdü.
- `src/des_sparse.f90` — CSR depolama (simetrik ve simetrik olmayan),
  blok montajı, RCM sıralaması. Sembolik desen ile sayısal değerler
  arayüzde AYRI: `analyse` bir kez, `zero` + `add` her Newton adımında.
- `test/check_element_contract.f90` — sahte elemanla sekiz sözleşme
  kontrolü, 65 iddia. Global DOF paylaşımı, Gauss noktası başına state,
  düğüm sıcaklığı interpolasyonu, `recover_internal`, elle hesaplanmış
  CSR montajı, RCM bant genişliği (3 → 1).
- **VER-031** — mod bazlı kararlılık doğrulaması
  (`test/check_stability.f90`). Bağımsız referans tablosuna karşı en
  büyük sapma 4.3e-06. `lambda = 1`'deki eğim doğrudan E olduğu için
  VER-001 ile çapraz doğrulanıyor (bağıl fark 3.16e-08).
- `AGENTS.md` — çok ajanlı çalışma için bağlayıcı kural seti (açık
  standart). `CLAUDE.md` buna symlink.
- `docs/TOOLCHAIN.md` — araç zinciri, sıfır uyarı kuralının kapsamı,
  üretici seçimi, Windows notları.
- `.github/CODEOWNERS`, issue şablonları, PR şablonu,
  `.github/workflows/release.yml`.
- CI'ya `fortls-denetimi` işi: sıfır uyarı kuralı artık derleyiciyi **ve**
  fortls'i kapsıyor.

### Düzeltildi

- İki host değişkeni maskelemesi (`diag3`'ün `c` argümanı host'taki
  `C(3,3)` tensörünü, `slope_of`'un `lam` argümanı host'taki `LAM(7)`
  dizisini maskeliyordu). gfortran bunları yakalamıyor, fortls yakalıyor.
- Visual Studio proje dosyaları `.gitignore`'a eklendi; elle tutulan bir
  `.sln` olmayacak (`docs/TOOLCHAIN.md`).

Sıradaki: v0.1 — eksenel simetrik Q4 elemanı, F-bar, Newton çözücüsü,
yama testi (patch test), kalın cidarlı silindir doğrulaması.
[ADR 0009](docs/adr/0009-eleman-sozlesmesi.md) onay bekliyor.

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
