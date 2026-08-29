# Değişiklik Günlüğü

Bu dosyanın biçimi [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/)
esasına, sürüm numaralandırması [Semantic Versioning](https://semver.org/lang/tr/)
esasına dayanır.

Sürümlerde **tarih yoktur**. Bir sürüm, kapısındaki koşullar sağlandığında
çıkar — bkz. [docs/YOL-HARITASI.md](docs/YOL-HARITASI.md).

---

## [Yayımlanmadı]

### Eklendi — v0.1 kapısı

- **VER-034 kalın cidarlı silindir** (`test/check_cylinder.f90`), 8
  kontrol. A = 1, B = 2, düzlem şekil değiştirme, yer değiştirme
  kontrolü; basınç iç düğümlerdeki reaksiyondan okunuyor.
  - Üç referans vakasında basınç bağıl hatası **1.98e-04 … 3.15e-05**,
    dış yarıçap yer değiştirmesi **8.71e-06 … 7.65e-06**.
  - Toleranslar spesifikasyondaki 1e-3'ten **daraltıldı**: basınç 5e-4
    (ayrıklaştırma baskın, ölçülen mertebe 2.006/2.035), u_r(B) 5e-5
    (gerilme içermez, sapma tam olarak mu/K = 1.2e-5 tabanında).
  - **D2 kilitlenme çalışması:** aynı ağda tam integrasyon basıncı
    **7–15 kat** fazla veriyor (bağıl hata 6.38 … 13.55); F-bar
    kilitlenmeyi tamamen gideriyor. ADR-0009 (c)'nin doğrulanması.
  - **D3 ağ yakınsaması:** 4/8/16 elemanda hata 1.96e-03 → 4.89e-04 →
    1.19e-04, **ölçülen mertebe 2.006 ve 2.035** — Q4 için beklenen
    O(h²) ile birebir.
- `scripts/durum.sh` — depo durum özeti (dal, sürüm, derleme, testler,
  altı referans sayı). Salt okunur.

### Değişti — v0.1 kapısı

- **Geri adımda eleman durumu da geri alınıyor.** `newton_solve` artık
  adım başında `element_t%serialise` ile elemanın kendi durumunu
  (yoğunlaştırılmış iç serbestlikler) kaydediyor ve geri adımda
  yüklüyor. Bugün `full`/`fbar` için sıfır uzunluk; v0.3'te karışık u-p
  geldiğinde dolacak. Yol şimdi kuruldu ki o gün Newton'a dokunulmasın.
- README durum başlığı güncellendi: program artık bir sınır değer
  problemi çözüyor.

### Eklendi (v0.1 yolunda) — program ilk kez bir sistem çözüyor

- `src/des_bc.f90` — Dirichlet, düğüm kuvveti, eksenel simetrik yüzey
  basıncı, parçalı doğrusal yük eğrileri, reaksiyon okuma. Dirichlet
  **ELEME** ile uygulanır (penaltı değil): penaltı köşegene büyük sayı
  ekleyip koşul sayısını bozar, kauçukta K/mu ~ 1e5 olduğu için sistem
  zaten kötü koşulludur. Eleme matrise uygulanır, ARTIĞA değil —
  reaksiyon böylece doğrudan okunur.
- `src/des_assemble.f90` — ağ + eleman listesi → global artık ve tanjant.
  Sembolik desen bir kez kurulur. `K_gu` saklanmaz, `transpose(K_ug)`
  kullanılır (ADR-0009).
- `src/des_linsolve.f90` — **Dondurulmuş Sözleşme 3**. Soyut arayüz
  (`analyse`/`factorize`/`solve`/`inertia`/`free`) simetrik indefinite
  taşır. Tek uygulama profil (skyline) LDL^T; **pivotlama yapmaz**, sıfır
  pivotta `DES_LIN_ZERO_PIVOT` döner. Pivotlu uygulama v0.3'te.
- `src/des_newton.f90` — tam Newton, artık yakınsama ölçütü (bağıl ve
  mutlak), sabit yük artımı + geri adım, `dt_factor` uyumu, J ≤ 0'da
  anında geri adım. Yakınsama geçmişi saklanabilir; çekirdek metin
  üretmez.
- **VER-033 yama testi** (`test/check_patch.f90`) — çarpık dört elemanlı
  yama, tek serbest iç düğüm. `full` ve `fbar` geçiyor: iç düğüm bağıl
  hatası 1.77e-16 / 1.45e-15, on altı Gauss noktasında max|ΔF| tam sıfır.

### Değişti (v0.1 yolunda)

- **F-bar yeniden formüle edildi: merkez J₀ yerine ORTALAMA GENLEŞME**
  (`J̄ = (1/V)∫J dV`). Merkez tabanlı varyasyonel F-bar **yama testini
  yapısal olarak geçemiyor**: homojen durumda artık
  `−(p/3)∫(g:δF_a)dV + (p/3)V(g0:δF0_a)` terimlerine iniyor ve bunlar
  ancak `∫δF_a dV = V·δF_a(merkez)` ise sadeleşiyor — çarpık elemanda
  bu eşitlik sağlanmıyor. Ölçülen: iç düğüm artığı (−185.8, +829.0).
  Ortalama genleşmede `δJ̄` tanım gereği `δF`'in eleman ortalamasını
  taşır ve terimler tam sadeleşir. Simetri korunuyor, `det F̄ = J̄`
  olduğu için kilitlenme çaresi de. Bu, Nagtegaal-Parks-Rice ve
  Simo-Taylor-Pister'in yöntemidir.
- Sonuç olarak **VER-032'nin `fbar` tanjant hatası değişti**:
  4.9578e-10 → **2.1123e-10**. Formülasyon değiştiği için bu kaçınılmaz
  ve beklenen bir değişikliktir; `full` (1.7762e-10) ve VER-001/002/031
  bit düzeyinde aynı kaldı.

### Düzeltildi (v0.1 yolunda)

- **Jacobian tersinde `j12` ile `j21` yer değiştirmişti.** Doğrusu
  `dN/dR = (j22·dN/dξ − j12·dN/dη)/det`. Dikdörtgen elemanda
  `j12 = j21 = 0` olduğu için hata GÖRÜNMÜYORDU: VER-032'nin bütün test
  elemanları dikdörtgendi ve tanjant-vs-sonlu-fark kontrolü aynı yanlış
  türevi iki tarafta da kullandığı için tutarlı çıkıyordu. Yalnızca
  çarpık ağdaki yama testi yakaladı — testin varlık sebebi tam budur.
- `kinematics` ve `centroid_state` varsayılan-şekilli argümana çevrildi;
  çalışma zamanı dizi kopyası uyarıları giderildi.
- VER-032'de "eksen" tanjant kontrolü `fbar` etiketi taşıyıp aslında
  `full` çalıştırıyordu; artık gerçekten `fbar` kuruluyor.

### Eklendi (v0.0.2 yolunda)

- **Eksenel simetrik Q4 elemanı** (`src/des_elem_axi_q4.f90`) — ADR-0009
  sözleşmesinin ilk gerçek uygulaması. Toplam Lagrange, bilineer şekil
  fonksiyonları, 2x2 Gauss. `DES_FORM_FULL` ve `DES_FORM_FBAR`;
  `mixed_up` / `bbar` / `srI` sözleşmede var ama gövdeleri v0.3'te
  (`DES_ELEM_UNSUPPORTED` döner).
  - **F-bar varyasyonel olarak tutarlıdır**: iç kuvvet
    `W(u) = ∫ Ψ(F_bar(u)) dV`'nin tam türevi, tanjant tam ikinci
    türevidir. Sonuç: tanjant **simetriktir** (ölçülen major simetri
    2.64e-16). de Souza Neto'nun klasik varyantı simetrik olmayan tanjant
    verir; simetri hem doğrusal çözücü sözleşmesini korur hem sınanabilir
    kılar.
  - Eksen üzerindeki düğümlerde `F_tt = 1 + u_r/R` L'Hôpital ile
    `F_tt → F_rr` olur. Bu dal 2x2 Gauss'ta hiç tetiklenmez (en yakın
    noktanın yarıçapı 0.2113h); dejenere elemanlar için güvencedir.
  - `gauss_state()` — sözleşme dışı tanı yordamı. **ADR-0009'da gerçek
    bir boşluk**: eleman sözleşmesinde gerilme çıktısı alacak yordam yok.
    Son işlem (post-processing) yazılırken ADR revizyonu gerekecek.
- **VER-032** — eleman doğrulaması (`test/check_elem_axi_q4.f90`), 49
  kontrol. Tanjant sonlu farka karşı 1.78e-10 (full) ve 4.96e-10 (fbar);
  homojen deformasyonda üç analitik referans 1e-14 bağıl içinde; eksenel
  öteleme tam sıfır iç kuvvet.

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
