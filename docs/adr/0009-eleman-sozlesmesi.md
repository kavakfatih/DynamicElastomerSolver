# ADR 0009 — Eleman sözleşmesi

**Durum:** KABUL EDİLDİ (üç düzeltmeyle)
**Dondurulmuş sözleşme:** 2/4

Uygulama: [`src/des_element.f90`](../../src/des_element.f90),
[`src/des_mesh.f90`](../../src/des_mesh.f90),
[`src/des_sparse.f90`](../../src/des_sparse.f90)
Doğrulama: [`test/check_element_contract.f90`](../../test/check_element_contract.f90)

> **Onay sırasında gelen düzeltme:** `ctx` sıcaklığı skaler değil **düğüm
> bazlı** olacak. Gerekçe aşağıda, "Sketch'ten farklar" bölümünde.

---

## Bağlam

Eleman arayüzü, DES/26'nın ikinci dondurulmuş sözleşmesidir. Üzerine
yazılacaklar: eksenel simetrik Q4 (v0.1), burulmalı Q4 (v0.2), Q8 ve
üçgenler (v0.3), yeniden ağ örme kancası (v0.5).

**ADR 0006'nın dersi:** eksik tanımlanmış bir sözleşme, üstüne yazılan her
şeyi çöpe atar. Malzemede bu ders, `pt` ve `dt_factor`ı ilk günden koymakla
öğrenildi; burada da aynısı yapılıyor. Aşağıdaki yeteneklerin **hiçbiri şu
an kullanılmıyor**; hepsi sonradan eklenirse pahalı.

Kod yazılmadan önce bu ADR onaylanır.

---

## Karar

### a) Düğüm başına değişken serbestlik derecesi

| Analiz tipi | DOF/düğüm | Bileşenler |
|---|---|---|
| Düzlem şekil değiştirme, düzlem gerilme | 2 | u_x, u_y |
| Eksenel simetrik | 2 | u_r, u_z |
| **Eksenel simetrik + burulma** | **3** | u_r, u_z, u_theta |

Eleman kendi DOF haritasını `n_dof_per_node()` ile bildirir. Çözücü sabit
bir sayı varsaymaz.

### b) Eleman-dışı global serbestlik dereceleri

Hiçbir düğüme ait olmayan, **modelin tamamına ait** serbestlikler:

| Analiz tipi | Global DOF | Anlam |
|---|---|---|
| Genelleştirilmiş düzlem şekil değiştirme (GPS) | 1 | eksenel uzama |
| GPS + burulma | 2 | eksenel uzama + birim boy başına dönme |
| Diğer | 0 | — |

**Kritik ayrıntı — kimlik.** Bu serbestlikler bütün elemanlar arasında
**paylaşılır**: A elemanının 1. global DOF'u ile B elemanınınki aynı
serbestliktir. Eleman yalnızca *kaç tane* kullandığını bilir; hangi model
düzeyi indisine karşılık geldiğini kurulum sırasında öğrenir
(`cfg%global_dof_ids`). Bu olmadan montaj kodu her elemana ayrı bir
serbestlik verir ve model sessizce yanlış çözülür.

Sonradan eklemek montajı, DOF haritasını ve çözücü arayüzünü **birlikte**
yeniden yazmak demektir.

### c) Formülasyon stratejisi — çalışma zamanı seçimi

`full | srI | bbar | fbar | mixed_up`, artı ayrı bir **basınç
interpolasyon mertebesi** parametresi.

**Derleme zamanı değil, çalışma zamanı.** Gerekçe: ANSYS ve Marc
formülasyonu eleman **opsiyonu** olarak sunar, ayrı eleman tipi olarak
değil. Kauçukta formülasyon, eleman şeklinden daha belirleyicidir —
aynı Q4 ağı `full` ile kilitlenir, `fbar` ile çözer. Ayrı eleman tipi
yapmak, kullanıcıyı ağı yeniden üretmeye zorlardı.

### d) `quality()` — yeniden ağ örme için distorsiyon metrikleri

v0.5'e kadar kimse çağırmayacak. Yine de şimdi konuyor: **distorsiyonu
yalnızca eleman hesaplayabilir** — Jacobian'ı, şekil fonksiyonlarını ve
integrasyon noktalarını yalnızca o bilir. Remesher'a bunu dışarıdan
hesaplatmak, şekil fonksiyonu bilgisini ikinci bir yere kopyalamak olurdu.

### e) `serialise` / `restore` — Sözleşme 4

**Sahiplik ayrımı.** Gauss noktası malzeme durumlarının sahibi ÇÖZÜCÜdür,
eleman değil: `residual` ve `tangent` onları dışarıdan dizi olarak alır.
Sebep, yeniden ağ örmedir — remesher bütün modelin durum alanını tek
seferde taşımak zorundadır ve durumlar eleman nesnelerinin içine
dağılmışsa bu iş elemanları tek tek yoklamaya döner.

Dolayısıyla Sözleşme 4 iki parçadan oluşur:

| Ne | Sahibi | Nasıl aktarılır |
|---|---|---|
| Gauss noktası malzeme durumları | Çözücü | `material_state_t%serialise` (ADR 0006) |
| Yoğunlaştırılmış iç serbestlikler | **Eleman** | `element_t%serialise` |

`element_t%serialise` yalnızca elemanın KENDİ sahip olduğu durumu, yani
iç serbestlikleri taşır. Bu unutulursa geri adım ve yeniden başlatma
sessizce yanlış çalışır: Gauss durumları geri yüklenir ama basınç
yüklenmez, tekrarlanan artım farklı bir noktadan başlar.

---

## Önerilen arayüz

```fortran
! --- Analiz tipi -----------------------------------------------------------
integer(ip), parameter :: DES_ANA_PLANE_STRAIN   = 1_ip
integer(ip), parameter :: DES_ANA_PLANE_STRESS   = 2_ip
integer(ip), parameter :: DES_ANA_AXISYM         = 3_ip
integer(ip), parameter :: DES_ANA_AXISYM_TORSION = 4_ip
integer(ip), parameter :: DES_ANA_GPS            = 5_ip
integer(ip), parameter :: DES_ANA_GPS_TORSION    = 6_ip

! --- Formülasyon -----------------------------------------------------------
integer(ip), parameter :: DES_FORM_FULL     = 1_ip
integer(ip), parameter :: DES_FORM_SRI      = 2_ip
integer(ip), parameter :: DES_FORM_BBAR     = 3_ip
integer(ip), parameter :: DES_FORM_FBAR     = 4_ip
integer(ip), parameter :: DES_FORM_MIXED_UP = 5_ip

! --- Basınç serbestliğinin yerleşimi ---------------------------------------
integer(ip), parameter :: DES_P_CONDENSED = 1_ip   ! eleman içi (VARSAYILAN)
integer(ip), parameter :: DES_P_NODAL     = 2_ip   ! düğüm serbestliği

!> Eleman kurulum yapılandırması.
type :: element_config_t
   integer(ip) :: analysis    = DES_ANA_AXISYM
   integer(ip) :: formulation = DES_FORM_FULL
   integer(ip) :: n_gauss     = 4_ip
   integer(ip) :: p_layout    = DES_P_CONDENSED
   integer(ip) :: p_order     = 0_ip
   !> Model düzeyi global DOF indisleri; kullanılmayanlar 0.
   integer(ip) :: global_dof_ids(2) = 0_ip
end type

!> Eleman bağlamı -- mat_point_t ile AYNI GEREKÇE (ADR 0006): ileride
!> alan eklemek hiçbir elemanı kırmasın diye bir dolaylama katmanı.
type :: element_ctx_t
   real(dp) :: time = 0.0_dp
   real(dp) :: dt   = 0.0_dp
   !> DÜĞÜM sıcaklıkları (n_node). Eleman bunları radius gibi Gauss
   !> noktalarına interpole eder ve pt%temperature'a yazar.
   !> Ayrılmamışsa veya boşsa referans sıcaklığa düşülür.
   real(dp), allocatable :: node_temperature(:)
end type

!> İzotermal analizde çağıranın hiçbir şey vermesi gerekmez.
real(dp), parameter :: DES_T_REF = 293.15_dp

!> Distorsiyon metrikleri. `worst` 0..1 arasında, 1 = mükemmel;
!> remesher eşiği bunun üzerinden kurulur.
type :: element_quality_t
   real(dp) :: jacobian_ratio = 1.0_dp
   real(dp) :: aspect_ratio   = 1.0_dp
   real(dp) :: min_angle      = 90.0_dp
   real(dp) :: max_angle      = 90.0_dp
   real(dp) :: worst          = 1.0_dp
   logical  :: inverted       = .false.
end type

type, abstract :: element_t
   character(len=32)      :: name = ''
   integer(ip)            :: id   = 0_ip
   type(element_config_t) :: cfg
contains
   procedure(el_setup_i),   deferred :: setup
   procedure(el_int_i),     deferred :: n_node
   procedure(el_int_i),     deferred :: n_dof_per_node
   procedure(el_resid_i),   deferred :: residual
   procedure(el_tan_i),     deferred :: tangent
   procedure(el_qual_i),    deferred :: quality
   procedure(el_ser_i),     deferred :: serialise
   procedure(el_rst_i),     deferred :: restore
   !> Varsayılanları temel sınıftan gelir:
   procedure :: n_global_dof     => default_n_global_dof
   procedure :: recover_internal => default_recover_internal
   procedure :: n_internal_dof   => default_n_internal_dof
end type
```

Ana yordamlar:

```fortran
subroutine setup(this, nodes, cfg, material, stat)
   real(dp), intent(in)          :: nodes(:, :)   ! (2, n_node)
   type(element_config_t), intent(in) :: cfg
   class(material_t), target, intent(in) :: material
   integer(ip), intent(out)      :: stat

subroutine residual(this, u, u_global, ctx, state_n, &
                    f_int, f_global, state_np1, stat, dt_factor)
   real(dp), intent(in)  :: u(:, :)          ! (n_dof_per_node, n_node)
   real(dp), intent(in)  :: u_global(:)      ! (n_global_dof)
   type(element_ctx_t), intent(in) :: ctx
   type(material_state_t), intent(in)    :: state_n(:)    ! (n_gauss)
   real(dp), intent(out) :: f_int(:, :)
   real(dp), intent(out) :: f_global(:)
   type(material_state_t), intent(inout) :: state_np1(:)
   integer(ip), intent(out) :: stat
   real(dp), intent(out)    :: dt_factor

subroutine tangent(this, u, u_global, ctx, state_n, K_uu, K_ug, K_gg, stat)
   real(dp), intent(out) :: K_uu(:, :)   ! (n_dof_total, n_dof_total)
   real(dp), intent(out) :: K_ug(:, :)   ! (n_dof_total, n_global_dof)
   real(dp), intent(out) :: K_gg(:, :)   ! (n_global_dof, n_global_dof)

subroutine recover_internal(this, du, du_global, stat)
subroutine quality(this, u, q)
function  serialise(this, buffer) result(n)   ! -1 = tampon küçük
function  restore(this, buffer)  result(n)    ! -1 = tampon küçük
```

`K_gu` **saklanmaz**: hiperelastisitede tanjant simetriktir, dolayısıyla
`K_gu = transpose(K_ug)`. Montaj bunu kullanır.

### Sketch'ten farklar ve gerekçeleri

Spesifikasyondaki taslağa dört ekleme yapıldı:

**1. Durum, integrasyon noktası başına dizidir** (`state_n(:)`), tek bir
`state_n` değil. Bir Q4'ün dört Gauss noktası vardır ve her birinin kendi
hasar/viskoelastik geçmişi olur. Tekil geçirmek, v0.4'te imzayı kırardı.

**2. `pt` (mat_point_t) elemanın İÇİNDE kurulur, dışarıdan gelmez.**
Eksenel simetride `pt%radius` her Gauss noktasında farklıdır ve onu
yalnızca eleman hesaplayabilir (şekil fonksiyonlarıyla). `pt%element` ve
`pt%point` de öyle. Dışarıdan `pt` almak, çağıranı elemanın iç
integrasyon düzenini bilmeye zorlardı. Bunun yerine eleman düzeyi bir
`ctx` alınır ve eleman her Gauss noktası için `pt`yi kendisi doldurur.

**Sıcaklık `ctx`te DÜĞÜM BAZLIDIR, skaler değil.** Sebep `radius` ile
birebir aynıdır: sıcaklık da eleman içinde değişir ve düğüm
sıcaklıklarından Gauss noktalarına interpole edilir. Tek bir skaler
taşınsaydı, ısıl-mekanik kuplaj geldiğinde (v0.3–v0.4) **her eleman
imzası kırılırdı** — ki bu, ADR 0006'da `mat_point_t` ile kapattığımız
hatanın tam olarak bir seviye yukarıda tekrarı olurdu.

Şimdi eklemek bir alan; sonra eklemek her imzayı kırmak.

| Alan | Biçim | Neden |
|---|---|---|
| `ctx%time`, `ctx%dt` | skaler | eleman içinde değişmez |
| `ctx%node_temperature(:)` | düğüm dizisi | eleman içinde değişir, interpole edilir |

Varsayılan davranış: `node_temperature` ayrılmamışsa veya boşsa
`pt%temperature` referans sıcaklığa (`DES_T_REF = 293.15 K`) düşer.
İzotermal analizde çağıranın hiçbir şey vermesi gerekmez.

**3. `condense_pressure()` yerine `recover_internal()`.** Statik
yoğunlaştırma tek yönlü bir işlem değildir: küresel çözümden sonra iç
serbestlikler **geri yerine konmalıdır** (back-substitution). Yalnızca
yoğunlaştırma sunan bir arayüzle basınç alanı hiç güncellenmez ve
gerilmeler sessizce yanlış çıkar. Yoğunlaştırmanın kendisi `tangent`
içinde, formülasyon `mixed_up` ise kendiliğinden yapılır — ayrı bir
çağrı olması, çağıranın unutabileceği bir adım demektir.

**4. Global DOF kimliği** (`cfg%global_dof_ids`) — yukarıda (b)'de
anlatıldı.

---

## Karara bağlanan iki soru

### 1. Basınç serbestliği nerede durur?

**Karar: varsayılan ELEMAN İÇİ statik yoğunlaştırma** (`DES_P_CONDENSED`).
Düğüm-basıncı (`DES_P_NODAL`) bir seçenek olarak kalır.

**Gerekçe.** Marc basıncı düğüm serbestliği olarak taşır. Bu, karışık
elemanlarla sıradan elemanların komşu olduğu her arayüzde **DOF
uyuşmazlığı** yaratır: bir tarafta düğümde basınç var, öbür tarafta yok.
Çözüm bağlama (tying) kısıtları eklemektir — kullanıcının kurması gereken,
unutulduğunda sessizce yanlış sonuç veren bir şey.

Yoğunlaştırma bu sorunu **tamamen ortadan kaldırır**: eleman dışarıya
yalnızca yer değiştirme serbestlikleri gösterir, hangi formülasyonu
kullandığı komşusunu ilgilendirmez. Yan faydaları: küresel sistem küçülür
ve eyer noktası (saddle point) yapısı hafifler — indefinite blok eleman
içinde kalır, küresel matrise taşınmaz.

Maliyeti: iç serbestlikler eleman durumunun parçası olur ve
`element_t%serialise` ile taşınmak **zorundadır** (yukarıda (e)'deki
sahiplik tablosu). Geri adımda (cut-back) yalnızca Gauss durumları geri
yüklenir de basınç yüklenmezse, tekrarlanan artım farklı bir noktadan
başlar. Sözleşmede `n_internal_dof()` bu yüzden var.

Düğüm-basıncı seçeneği neden korunuyor: LBB (inf-sup) çalışmalarında ve
Marc sonuçlarıyla karşılaştırmada gerekebilir; ayrıca bazı eleman
çiftleri için yoğunlaştırma mümkün değildir.

### 2. Düzlem gerilme nasıl ele alınacak?

**Karar: malzemeye "düzlem gerilmedesin" DENMEZ.** ADR 0006 Kural 1
duruyor: malzeme analiz tipini bilmez, her zaman tam 3x3 C alır.

Bunun yerine **eleman tarafında bir sarmalayıcı**, kalınlık uzamasını
(`F_33`) bilinmeyen olarak alır ve `S_33 = 0` olacak şekilde **yerel bir
Newton** yürütür. Malzeme, kendisine sıradan bir 3x3 C geldiğini sanmaya
devam eder.

Newton burada uygundur (doğrulama testlerindeki ikiye bölmenin aksine),
çünkü tanjant zaten elde: `dS_33/dF_33` doğrudan `CC_3333`ten türer,
dolayısıyla kuadratik yakınsar ve her Gauss noktasında yeniden
çalıştırılacağı için hız önemlidir.

**Ortak altyapı fırsatı.** ADR 0007'deki mod bazlı kararlılık kontrolü de
"bir serbest uzamayı, bir gerilme bileşenini sıfırlayacak şekilde çöz"
işini yapıyor (`mode_nominal_stress`, ikiye bölmeyle). Düzlem gerilme
sarmalayıcısı aynı problemin Newton'lu hâlidir. İkisini ortak bir
yardımcıya çıkarmak değerlendirilmelidir:

```fortran
!> Serbest bir uzamayı, hedef gerilme bileşeni sıfır olacak şekilde çözer.
subroutine solve_free_stretch(mat, C_template, free_idx, target_idx, &
                              method, x, stat)
```

Bu, v0.1'de eleman yazılırken karara bağlanır; **şimdi zorunlu değildir**
ve bu ADR'yi bekletmez.

---

## Sonuçlar

**Olumlu**

- v0.2'de burulma eklemek montaj kodunu kırmaz (DOF/düğüm zaten değişken)
- GPS ve GPS+burulma, montaj yeniden yazılmadan gelir
- Formülasyon değiştirmek ağı yeniden üretmeyi gerektirmez
- Karışık elemanlar sıradan elemanlarla komşu olabilir (yoğunlaştırma)
- Remesher (v0.5) elemandan hazır metrik alır
- Malzeme sözleşmesi (ADR 0006) hiç dokunulmadan geçerli kalır

**Olumsuz**

- Arayüz geniş: dokuz yordam. Üçünün temel sınıfta varsayılanı var,
  ama yine de bir Q4 yazmak ADR 0006'daki bir malzeme yazmaktan zor.
- `K_uu`, `K_ug`, `K_gg` üçlüsü, global DOF olmayan durumda (çoğu analiz)
  gereksiz iki boş dizi taşır. Boyutları 0 olur; maliyet ihmal edilebilir
  ama imza kalabalıklaşır.
- Statik yoğunlaştırma, iç serbestlikleri durum aktarımına sokar. Bu
  gerçek bir karmaşıklık artışıdır ve unutulması kolay bir hata kaynağıdır.
- Düzlem gerilme sarmalayıcısı her Gauss noktasında bir yerel Newton
  demektir. Doğru yer burası, ama ucuz değil.

## Değerlendirilen alternatifler

**Her analiz tipi için ayrı eleman tipi** (`Q4_axisym`, `Q4_axisym_torsion`,
`Q4_gps`, ...). Reddedildi: kombinatoryal patlama. Üç analiz tipi × beş
formülasyon × üç eleman şekli = 45 tip. Formülasyonu çalışma zamanı
seçeneği yapmak bunu 3'e indiriyor.

**Sabit DOF/düğüm = 3, kullanılmayanı kısıtla.** Basit görünüyor.
Reddedildi: düzlem şekil değiştirmede her düğüme sahte bir serbestlik ve
ona bir kısıt eklemek, sistemi %50 büyütür ve çözücüye anlamsız iş yükler.

**Global DOF'u bir "süper eleman" olarak modellemek.** Reddedildi: montaj
kodunda özel bir durum yaratır ve her eleman tipinin ondan haberdar
olmasını gerektirir. `n_global_dof()` + `global_dof_ids` daha az yer
kaplar.

**Basıncı her zaman düğümde tutmak** (Marc yolu). Reddedildi: yukarıda
(1) numaralı kararda anlatıldı.

**Düzlem gerilmeyi malzemeye bildirmek.** Reddedildi: ADR 0006 Kural 1'i
çiğner ve her malzemeye bir dal ekler. Bir kullanıcı malzemesi yazan
mühendis düzlem gerilmeyi düşünmek zorunda kalmamalıdır.
