!> ---------------------------------------------------------------------------
!> des_material -- malzeme arayüzü (DONDURULMUŞ SÖZLEŞME)
!>
!> Bu modüldeki arayüz, DES/26'nın dört dondurulmuş sözleşmesinden birincisidir.
!> ADR 0006 yazılmadan değiştirilemez. Tasarım ANSYS USERMAT, Marc HYPELA2 ve
!> Abaqus UMAT konvansiyonlarına göre yapılmıştır; oradan gelen bir mühendis
!> arayüzü tanır.
!>
!> ÜÇ TASARIM KURALI
!>
!>   1. Malzeme HER ZAMAN tam 3x3 sağ Cauchy-Green tensörü C alır. Analiz
!>      tipini (düzlem şekil değiştirme / eksenel simetrik / burulmalı /
!>      genelleştirilmiş düzlem şekil değiştirme) ASLA bilmez. Böylece tek
!>      bir malzeme kütüphanesi bütün 2B eleman ailesine hizmet eder ve
!>      yeni bir eleman formülasyonu hiçbir malzemeyi kırmaz.
!>
!>   2. Malzeme ASLA tahsis (allocate) etmez, dosya açmaz, yazdırmaz,
!>      durmaz (stop). Hata `stat` ile, adım küçültme talebi `dt_factor`
!>      ile bildirilir. Kullanıcıya görünecek metni üretmek üst katmanın
!>      işidir (bkz. messages/tr.toml).
!>
!>   3. state_n intent(in)'dir ve DEĞİŞTİRİLEMEZ. Çözücü; hat araması
!>      (line search), geri adım (cut-back) veya Newton yinelemesi sırasında
!>      aynı noktayı aynı state_n ile defalarca çağırabilir. Malzeme bu
!>      çağrıların kaçıncısı olduğunu bilemez, bilmemelidir.
!>
!> Katman: 4 -- Analiz çekirdeği
!> ---------------------------------------------------------------------------
module des_material
   use des_kinds, only: dp, ip
   use des_tensor, only: cauchy_from_pk2, det3
   implicit none
   private

   public :: DES_MAT_OK, DES_MAT_SINGULAR, DES_MAT_NONPHYSICAL, DES_MAT_NOTCONV
   public :: DES_STAB_OK, DES_STAB_UNSTABLE, DES_STAB_UNKNOWN
   public :: DES_MODE_UNIAXIAL, DES_MODE_EQUIBIAXIAL, DES_MODE_PLANAR
   public :: DES_N_MODE
   public :: mat_point_t, material_state_t, material_t
   public :: stability_range_t, stability_result_t

   ! --- Malzeme değerlendirme durum kodları ---------------------------------
   !> Artım sorunsuz tamamlandı.
   integer(ip), parameter :: DES_MAT_OK = 0_ip
   !> C tekil veya sayısal olarak tersinemez.
   integer(ip), parameter :: DES_MAT_SINGULAR = 1_ip
   !> Fiziksel olarak imkânsız durum: det C <= 0, yani eleman ters dönmüş.
   integer(ip), parameter :: DES_MAT_NONPHYSICAL = 2_ip
   !> Malzeme içi yerel yineleme yakınsamadı (viskoelastisite, hasar, plastisite).
   integer(ip), parameter :: DES_MAT_NOTCONV = 3_ip

   ! --- Kararlılık kontrolü durum kodları -----------------------------------
   !> Bütün istenen modlarda dP/dlambda > 0.
   integer(ip), parameter :: DES_STAB_OK = 0_ip
   !> En az bir modda nominal gerilme uzamayla azalıyor: kararsız.
   integer(ip), parameter :: DES_STAB_UNSTABLE = 1_ip
   !> Karar verilemedi (yanal uzama çözülemedi veya eval başarısız).
   integer(ip), parameter :: DES_STAB_UNKNOWN = 2_ip

   ! --- Deformasyon modu kimlikleri -----------------------------------------
   !> Tek eksenli: F = diag(lam, x, x), x -> sigma22 = 0
   integer(ip), parameter :: DES_MODE_UNIAXIAL = 1_ip
   !> Eşit iki eksenli: F = diag(lam, lam, x), x -> sigma33 = 0
   integer(ip), parameter :: DES_MODE_EQUIBIAXIAL = 2_ip
   !> Düzlemsel (saf kayma): F = diag(lam, 1, x), x -> sigma33 = 0
   integer(ip), parameter :: DES_MODE_PLANAR = 3_ip
   !> Mod sayısı.
   integer(ip), parameter :: DES_N_MODE = 3_ip

   !> ------------------------------------------------------------------------
   !> Malzeme noktası bağlamı
   !>
   !> GEREKÇE: sıcaklık ŞİMDİ konulmazsa, ısıl-mekanik kuplaj ve WLF zaman-
   !> sıcaklık kaydırması eklenirken HER malzemenin imzası kırılır. `pt` bir
   !> dolaylama katmanıdır: ileride alan eklemek hiçbir malzemeyi etkilemez,
   !> çünkü mevcut malzemeler yeni alanı okumaz.
   !> ------------------------------------------------------------------------
   type :: mat_point_t
      !> Mutlak sıcaklık [K]. WLF/Arrhenius için şart.
      real(dp) :: temperature = 293.15_dp
      !> Artımın BAŞINDAKİ toplam zaman [s].
      real(dp) :: time = 0.0_dp
      !> Zaman artımı [s].
      real(dp) :: dt = 0.0_dp
      !> Eksenel simetride mevcut yarıçap r; değilse 0.
      real(dp) :: radius = 0.0_dp
      !> Tanılama için eleman numarası ("eleman 2871").
      integer(ip) :: element = 0_ip
      !> Tanılama için integrasyon noktası numarası ("nokta 3").
      integer(ip) :: point = 0_ip
   end type mat_point_t

   !> ------------------------------------------------------------------------
   !> Malzeme durum değişkenleri
   !>
   !> serialise/restore yalnızca bir yedekleme kolaylığı değildir: geri adım
   !> (cut-back), yeniden başlatma (restart) ve yeniden ağ örme (remesh) aynı
   !> mekanizmadır. Üçü de "durumu bir tampona yaz, sonra geri oku"ya indirgenir.
   !> ------------------------------------------------------------------------
   type :: material_state_t
      !> Durum değişkenleri.
      real(dp), allocatable :: sv(:)
      !> Fiziksel alt sınırlar; sınırsız bileşenler için -huge.
      real(dp), allocatable :: sv_min(:)
      !> Fiziksel üst sınırlar; sınırsız bileşenler için +huge.
      real(dp), allocatable :: sv_max(:)
   contains
      procedure :: init => state_init
      procedure :: set_bounds => state_set_bounds
      procedure :: project => state_project
      procedure :: serialise => state_serialise
      procedure :: restore => state_restore
   end type material_state_t

   !> ------------------------------------------------------------------------
   !> Kararlılık taraması parametreleri
   !>
   !> Tarama aralığı ve mod listesi çağıran tarafından verilir. Varsayılan
   !> aralık, kauçuk kalibrasyonunda anlamlı olan 0.5 ... 4.0 uzama
   !> penceresidir; kalibrasyon modülü (v0.4) burayı deney verisinin
   !> kapsadığı aralıkla daraltacaktır.
   !> ------------------------------------------------------------------------
   type :: stability_range_t
      !> En küçük uzama oranı.
      real(dp) :: lam_min = 0.5_dp
      !> En büyük uzama oranı.
      real(dp) :: lam_max = 4.0_dp
      !> Aralıktaki örnek sayısı (uç noktalar dâhil).
      integer(ip) :: n_sample = 36_ip
      !> Hangi modlar taransın: [tek eksenli, eşit iki eksenli, düzlemsel]
      logical :: modes(DES_N_MODE) = .true.
   end type stability_range_t

   !> ------------------------------------------------------------------------
   !> Kararlılık taraması sonucu
   !>
   !> Yalnızca "kararlı/kararsız" değil, ilk kararsızlığın HANGİ MODDA ve
   !> HANGİ UZAMADA başladığı döndürülür. Kalibrasyonda kullanıcının
   !> ihtiyaç duyduğu bilgi budur: "Ogden katsayılarınız düzlemsel modda
   !> lambda = 2.7'den sonra kararsız" cümlesi kurulabilmelidir.
   !> ------------------------------------------------------------------------
   type :: stability_result_t
      !> Toplu karar: DES_STAB_*
      integer(ip) :: stat = DES_STAB_UNKNOWN
      !> İlk kararsızlığın modu (DES_MODE_*); kararlıysa 0.
      integer(ip) :: first_mode = 0_ip
      !> İlk kararsızlığın uzama oranı; kararlıysa 0.
      real(dp) :: first_lambda = 0.0_dp
      !> Bütün modlardaki en küçük dP/dlambda (ham).
      real(dp) :: min_slope = 0.0_dp
      !> Aynı değerin mu_ref ile normalize edilmiş hâli (boyutsuz).
      real(dp) :: min_slope_n = 0.0_dp
      !> Mod başına durum.
      integer(ip) :: mode_stat(DES_N_MODE) = DES_STAB_UNKNOWN
      !> Mod başına ilk kararsız uzama.
      real(dp) :: mode_lambda(DES_N_MODE) = 0.0_dp
      !> Mod başına en küçük eğim.
      real(dp) :: mode_min_slope(DES_N_MODE) = 0.0_dp
      !> Hacimsel kararlılık: kappa_ref > 0 mu.
      integer(ip) :: vol_stat = DES_STAB_UNKNOWN
   end type stability_result_t

   !> ------------------------------------------------------------------------
   !> Soyut malzeme temel tipi
   !>
   !> Türetilmiş malzemeler yalnızca `eval`i yazmak zorundadır. Kararlılık
   !> taramasını ve durum değişkeni adlandırmasını temel sınıftan bedava
   !> alırlar -- gelecekte eklenecek kullanıcı malzemeleri dahil.
   !> ------------------------------------------------------------------------
   type, abstract :: material_t
      !> Malzeme tür anahtarı. Kullanıcıya gösterilecek metin DEĞİL; üst
      !> katmandaki çeviri tablosunun anahtarıdır. ASCII ve İngilizce kalır.
      character(len=32) :: name = ''
      !> Durum değişkeni sayısı.
      integer(ip) :: n_sv = 0_ip
      !> Referans kayma modülü (küçük şekil değiştirme). Neo-Hookean için
      !> 2*C10. Kararlılık eğimlerini boyutsuzlaştırmak ve raporlamak için.
      real(dp) :: mu_ref = 0.0_dp
      !> Referans hacim modülü. Hacimsel kararlılık raporu (kappa_ref > 0)
      !> ve K/mu oranının raporlanması için.
      real(dp) :: kappa_ref = 0.0_dp
   contains
      procedure(material_eval_i), deferred :: eval
      procedure :: check_stability => check_mode_stability
      procedure :: mode_nominal => mode_nominal_stress
      procedure :: sv_name => default_sv_name
   end type material_t

   abstract interface
      !> --------------------------------------------------------------------
      !> Malzeme değerlendirmesi: C -> (S, CC)
      !>
      !> C          : sağ Cauchy-Green tensörü, tam 3x3, C = F^T F
      !> pt         : malzeme noktası bağlamı (sıcaklık, zaman, yarıçap)
      !> state_n    : artımın BAŞINDAKİ durum -- DEĞİŞTİRİLEMEZ
      !> S          : 2. Piola-Kirchhoff gerilmesi
      !> CC         : malzeme tanjantı, CC = 2 dS/dC
      !> state_np1  : artımın SONUNDAKİ durum -- çağıran tarafından önceden
      !>              tahsis edilmiş olmalıdır; malzeme tahsis etmez
      !> stat       : DES_MAT_* durum kodu
      !> dt_factor  : adım boyu talebi (UMAT'taki PNEWDT ile aynı rol)
      !>                1.0  = artım sorunsuzdu
      !>                <1.0 = çözücüden bu oranda küçültme iste
      !>                >1.0 = büyümeye izin ver
      !>              ZORUNLUDUR, opsiyonel değildir. Bu olmadan malzeme
      !>              "başarısız oldum" diyebilir ama "daha küçük adımla
      !>              olurdu" diyemez -- ki pratikte asıl vaka budur.
      !> --------------------------------------------------------------------
      subroutine material_eval_i(this, C, pt, state_n, S, CC, state_np1, &
                                 stat, dt_factor)
         import :: dp, ip, material_t, mat_point_t, material_state_t
         class(material_t), intent(in)          :: this
         real(dp), intent(in)                   :: C(3, 3)
         type(mat_point_t), intent(in)          :: pt
         type(material_state_t), intent(in)     :: state_n
         real(dp), intent(out)                  :: S(3, 3)
         real(dp), intent(out)                  :: CC(3, 3, 3, 3)
         type(material_state_t), intent(inout)  :: state_np1
         integer(ip), intent(out)               :: stat
         real(dp), intent(out)                  :: dt_factor
      end subroutine material_eval_i
   end interface

contains

   ! =========================================================================
   ! material_state_t
   ! =========================================================================

   !> Durumu n bileşenle sıfırlar ve sınırları sınırsıza açar.
   !>
   !> Tahsis BURADA yapılır, `eval` içinde değil: çözücü ağı kurarken her
   !> integrasyon noktası için bir kez çağırır, malzeme sıcak döngüde asla
   !> tahsis etmez.
   subroutine state_init(this, n)
      class(material_state_t), intent(inout) :: this
      integer(ip), intent(in) :: n

      if (allocated(this%sv)) deallocate (this%sv)
      if (allocated(this%sv_min)) deallocate (this%sv_min)
      if (allocated(this%sv_max)) deallocate (this%sv_max)

      allocate (this%sv(n))
      allocate (this%sv_min(n))
      allocate (this%sv_max(n))

      this%sv = 0.0_dp
      this%sv_min = -huge(1.0_dp)
      this%sv_max = huge(1.0_dp)
   end subroutine state_init

   !> i. durum değişkenine fiziksel aralık atar.
   subroutine state_set_bounds(this, i, lo, hi)
      class(material_state_t), intent(inout) :: this
      integer(ip), intent(in) :: i
      real(dp), intent(in) :: lo
      real(dp), intent(in) :: hi

      if (.not. allocated(this%sv_min)) return
      if (i < 1 .or. i > size(this%sv_min)) return

      this%sv_min(i) = lo
      this%sv_max(i) = hi
   end subroutine state_set_bounds

   !> Durum değişkenlerini fiziksel aralığa geri kırpar.
   !>
   !> Yeniden ağ örme (remesh) sonrası eski ağdan yeni ağa yapılan
   !> interpolasyon, hasar gibi [0,1] ile sınırlı değişkenleri aralığın
   !> dışına taşıyabilir -- interpolasyon bu sınırı bilmez. Sınırsız
   !> bırakılmış bileşenlere dokunulmaz.
   pure subroutine state_project(this)
      class(material_state_t), intent(inout) :: this
      integer(ip) :: i

      if (.not. allocated(this%sv)) return

      do i = 1, int(size(this%sv), ip)
         if (this%sv(i) < this%sv_min(i)) this%sv(i) = this%sv_min(i)
         if (this%sv(i) > this%sv_max(i)) this%sv(i) = this%sv_max(i)
      end do
   end subroutine state_project

   !> Durumu düz bir tampona yazar; yazılan eleman sayısını döndürür.
   !>
   !> Tampon küçükse -1 döner ve tampona DOKUNULMAZ. Yalnızca `sv`
   !> aktarılır: sınırlar malzeme yapılandırmasıdır, durum değil.
   function state_serialise(this, buffer) result(n)
      class(material_state_t), intent(in) :: this
      real(dp), intent(inout) :: buffer(:)
      integer(ip) :: n

      integer(ip) :: m

      m = 0_ip
      if (allocated(this%sv)) m = int(size(this%sv), ip)

      if (int(size(buffer), ip) < m) then
         n = -1_ip
         return
      end if

      if (m > 0) buffer(1:m) = this%sv
      n = m
   end function state_serialise

   !> Durumu düz bir tampondan geri okur; okunan eleman sayısını döndürür.
   !>
   !> Tampon beklenenden küçükse -1 döner ve durum DEĞİŞMEZ. Yarım
   !> yazılmış bir durum, hiç yazılmamış durumdan çok daha tehlikelidir.
   function state_restore(this, buffer) result(n)
      class(material_state_t), intent(inout) :: this
      real(dp), intent(in) :: buffer(:)
      integer(ip) :: n

      integer(ip) :: m

      m = 0_ip
      if (allocated(this%sv)) m = int(size(this%sv), ip)

      if (int(size(buffer), ip) < m) then
         n = -1_ip
         return
      end if

      if (m > 0) this%sv = buffer(1:m)
      n = m
   end function state_restore

   ! =========================================================================
   ! material_t -- ortak davranış
   ! =========================================================================

   !> MOD BAZLI MONOTONLUK KONTROLÜ
   !>
   !> Üç deformasyon modunda, nominal (1. Piola-Kirchhoff) gerilmenin uzama
   !> oranına göre türevi pozitif olmalıdır:
   !>
   !>    dP/dlambda > 0
   !>
   !>    1. Tek eksenli      : F = diag(lam, x, x),   x -> sigma22 = 0
   !>    2. Eşit iki eksenli : F = diag(lam, lam, x), x -> sigma33 = 0
   !>    3. Düzlemsel        : F = diag(lam, 1, x),   x -> sigma33 = 0
   !>
   !> Yanal uzamalar ikiye bölme (bisection) ile çözülür; sigma serbest
   !> bileşeni x'e göre monotondur, dolayısıyla kök bulma güvenlidir.
   !>
   !> NEDEN BU ÖLÇÜT, NEDEN TANJANT POZİTİF TANIMLILIĞI DEĞİL
   !>
   !> Tam 4. mertebe tanjantın pozitif tanımlılığı (Drucker koşulu) YANLIŞ
   !> ölçüttür: sağlıklı bir Neo-Hookean (C10 > 0) bunu sağlamaz. Serbest
   !> enerji C uzayında konveks değil, POLİKONVEKStir; konvekslik sonlu
   !> şekil değiştirmede zaten fiziksel olarak istenmeyen bir şarttır.
   !> Karşı örnek ve üç bağımsız doğrulaması ADR 0007'dedir.
   !>
   !> Mod bazlı kontrol, ANSYS ve Abaqus'ün hiperelastik kalibrasyonda
   !> yaptığı şeydir: kullanıcının anladığı, deney verisiyle doğrudan
   !> karşılaştırılabilen ve kalibrasyon için yeterli olan ölçüt budur.
   !>
   !> ÇAPRAZ DOĞRULAMA: lambda = 1.0'daki dP/dlambda doğrudan elastisite
   !> modülü E'dir. Bu, kararlılık kontrolünü VER-001 ile birbirine bağlar.
   !>
   !> Bu yordam `eval`den başka hiçbir şeye ihtiyaç duymaz; bütün malzemeler
   !> -- ileride yazılacak kullanıcı malzemeleri dahil -- bunu bedava alır.
   !>
   !> state_np1 çalışma alanı olarak istenir çünkü `eval` onu yazmak
   !> zorundadır ve malzeme tahsis edemez (kural 2).
   subroutine check_mode_stability(this, pt, state_n, state_np1, rng, res)
      class(material_t), intent(in)         :: this
      type(mat_point_t), intent(in)         :: pt
      type(material_state_t), intent(in)    :: state_n
      type(material_state_t), intent(inout) :: state_np1
      type(stability_range_t), intent(in)   :: rng
      type(stability_result_t), intent(out) :: res

      real(dp) :: lam, dlam, slope, scal
      integer(ip) :: mode, i, n
      logical :: ok, any_unknown, any_unstable, any_sampled

      res%stat = DES_STAB_UNKNOWN
      res%first_mode = 0_ip
      res%first_lambda = 0.0_dp
      res%min_slope = huge(1.0_dp)
      res%min_slope_n = 0.0_dp
      res%mode_stat = DES_STAB_UNKNOWN
      res%mode_lambda = 0.0_dp
      res%mode_min_slope = 0.0_dp

      !> Hacimsel kararlılık ayrıca ve trivial olarak raporlanır.
      if (this%kappa_ref > 0.0_dp) then
         res%vol_stat = DES_STAB_OK
      else
         res%vol_stat = DES_STAB_UNSTABLE
      end if

      n = rng%n_sample
      if (n < 2_ip) return
      if (.not. (rng%lam_max > rng%lam_min)) return
      if (rng%lam_min <= 0.0_dp) return

      dlam = (rng%lam_max - rng%lam_min)/real(n - 1_ip, dp)
      any_unknown = .false.
      any_unstable = .false.
      any_sampled = .false.

      do mode = 1_ip, DES_N_MODE
         if (.not. rng%modes(mode)) cycle

         res%mode_min_slope(mode) = huge(1.0_dp)
         res%mode_stat(mode) = DES_STAB_OK

         do i = 1_ip, n
            lam = rng%lam_min + real(i - 1_ip, dp)*dlam

            call nominal_slope(this, mode, lam, pt, state_n, state_np1, &
                               slope, ok)

            if (.not. ok) then
               res%mode_stat(mode) = DES_STAB_UNKNOWN
               any_unknown = .true.
               exit
            end if

            any_sampled = .true.
            if (slope < res%mode_min_slope(mode)) then
               res%mode_min_slope(mode) = slope
            end if
            if (slope < res%min_slope) res%min_slope = slope

            !> İlk kararsızlık: ilk kez eğimin pozitifliğini yitirdiği nokta.
            if (slope <= 0.0_dp .and. res%mode_stat(mode) == DES_STAB_OK) then
               res%mode_stat(mode) = DES_STAB_UNSTABLE
               res%mode_lambda(mode) = lam
               any_unstable = .true.

               if (res%first_mode == 0_ip .or. lam < res%first_lambda) then
                  res%first_mode = mode
                  res%first_lambda = lam
               end if
            end if
         end do
      end do

      !> Hiçbir örnek alınamadıysa karar verilemez.
      if (.not. any_sampled) then
         res%min_slope = 0.0_dp
         res%stat = DES_STAB_UNKNOWN
         return
      end if

      !> Eğim mu_ref ile boyutsuzlaştırılır. İşaret korunsun diye mutlak
      !> değerle bölünür: mu_ref negatif olan (fiziksel olmayan) bir
      !> malzemede oranın işareti anlamını yitirirdi.
      scal = abs(this%mu_ref)
      if (scal > tiny(1.0_dp)) res%min_slope_n = res%min_slope/scal

      if (any_unstable) then
         res%stat = DES_STAB_UNSTABLE
      else if (any_unknown) then
         res%stat = DES_STAB_UNKNOWN
      else
         res%stat = DES_STAB_OK
      end if
   end subroutine check_mode_stability

   !> Verilen modda ve uzama oranında nominal gerilme P11 = F11 * S11.
   !>
   !> Yanal uzama, modun serbest Cauchy gerilme bileşeni sıfır olacak
   !> şekilde ikiye bölmeyle çözülür. `lat` çözülen yanal uzamayı döndürür;
   !> çağıran bunu tanılama için kullanabilir.
   subroutine mode_nominal_stress(this, mode, lam, pt, state_n, state_np1, &
                                  p_nom, lat, ok)
      class(material_t), intent(in)         :: this
      integer(ip), intent(in)               :: mode
      real(dp), intent(in)                  :: lam
      type(mat_point_t), intent(in)         :: pt
      type(material_state_t), intent(in)    :: state_n
      type(material_state_t), intent(inout) :: state_np1
      real(dp), intent(out)                 :: p_nom
      real(dp), intent(out)                 :: lat
      logical, intent(out)                  :: ok

      !> UYARLANIR KUŞATMA
      !>
      !> Sabit geniş bir aralık ([1e-3, 50] gibi) iki yerde kırılır:
      !>
      !>   1. Büyük lambda'da alt sınır det C'yi malzemenin tekillik
      !>      eşiğinin altına indirir; eval DES_MAT_SINGULAR döner.
      !>   2. C10 < 0 olan (fiziksel olmayan ama sınanması gereken)
      !>      malzemelerde izokorik terim aşırı yanal basmada işaret
      !>      değiştirir; sigma serbest bileşeni artık monoton değildir ve
      !>      kuşatma testi başarısız olur.
      !>
      !> Bunun yerine sıkıştırılamaz kinematikten bir başlangıç tahmini
      !> alınır ve kök kuşatılana kadar bu tahminin ETRAFINDA genişletilir.
      !> Böylece bulunan kök her zaman fiziksel çözüme en yakın olandır.
      real(dp), parameter :: EXPAND = 1.5_dp
      integer(ip), parameter :: N_EXPAND = 40_ip
      integer(ip), parameter :: N_BISECT = 100_ip

      real(dp) :: lo, hi, mid, f_lo, f_hi, f_mid, f0, x0, s11
      integer(ip) :: it

      ok = .false.
      p_nom = 0.0_dp
      lat = 0.0_dp

      !> Sıkıştırılamaz kinematik başlangıç tahmini (J = 1 koşulundan).
      select case (mode)
      case (DES_MODE_UNIAXIAL)
         x0 = 1.0_dp/sqrt(lam)
      case (DES_MODE_EQUIBIAXIAL)
         x0 = 1.0_dp/(lam*lam)
      case (DES_MODE_PLANAR)
         x0 = 1.0_dp/lam
      case default
         return
      end select

      call mode_stress(this, mode, lam, x0, pt, state_n, state_np1, s11, f0, ok)
      if (.not. ok) return

      lo = x0
      hi = x0
      f_lo = f0
      f_hi = f0

      if (f0 < 0.0_dp) then
         !> Tahminde gerilme negatif: kök yukarıda.
         ok = .false.
         do it = 1_ip, N_EXPAND
            hi = hi*EXPAND
            call mode_stress(this, mode, lam, hi, pt, state_n, state_np1, &
                             s11, f_hi, ok)
            if (.not. ok) return
            if (f_hi >= 0.0_dp) exit
            lo = hi
            f_lo = f_hi
         end do
         if (f_hi < 0.0_dp) then
            ok = .false.
            return
         end if
      else
         !> Tahminde gerilme pozitif (veya sıfır): kök aşağıda.
         ok = .false.
         do it = 1_ip, N_EXPAND
            lo = lo/EXPAND
            call mode_stress(this, mode, lam, lo, pt, state_n, state_np1, &
                             s11, f_lo, ok)
            if (.not. ok) return
            if (f_lo < 0.0_dp) exit
            hi = lo
            f_hi = f_lo
         end do
         if (f_lo >= 0.0_dp) then
            ok = .false.
            return
         end if
      end if

      mid = 0.5_dp*(lo + hi)
      do it = 1_ip, N_BISECT
         mid = 0.5_dp*(lo + hi)
         call mode_stress(this, mode, lam, mid, pt, state_n, state_np1, &
                          s11, f_mid, ok)
         if (.not. ok) return

         if (f_mid < 0.0_dp) then
            lo = mid
         else
            hi = mid
         end if
      end do

      lat = mid
      p_nom = s11
      ok = .true.
   end subroutine mode_nominal_stress

   !> Bir mod-uzama-yanal uzama üçlüsü için nominal gerilme P11 ve modun
   !> serbest Cauchy bileşenini hesaplar.
   subroutine mode_stress(this, mode, lam, lat, pt, state_n, state_np1, &
                          p_nom, sig_free, ok)
      class(material_t), intent(in)         :: this
      integer(ip), intent(in)               :: mode
      real(dp), intent(in)                  :: lam
      real(dp), intent(in)                  :: lat
      type(mat_point_t), intent(in)         :: pt
      type(material_state_t), intent(in)    :: state_n
      type(material_state_t), intent(inout) :: state_np1
      real(dp), intent(out)                 :: p_nom
      real(dp), intent(out)                 :: sig_free
      logical, intent(out)                  :: ok

      real(dp) :: F(3, 3), C(3, 3), S(3, 3), CC(3, 3, 3, 3), sig(3, 3)
      real(dp) :: jac, dtf
      integer(ip) :: st

      p_nom = 0.0_dp
      sig_free = 0.0_dp
      ok = .false.

      F = 0.0_dp
      select case (mode)
      case (DES_MODE_UNIAXIAL)
         F(1, 1) = lam; F(2, 2) = lat; F(3, 3) = lat
      case (DES_MODE_EQUIBIAXIAL)
         F(1, 1) = lam; F(2, 2) = lam; F(3, 3) = lat
      case (DES_MODE_PLANAR)
         F(1, 1) = lam; F(2, 2) = 1.0_dp; F(3, 3) = lat
      case default
         return
      end select

      C = matmul(transpose(F), F)
      jac = det3(F)
      if (jac <= 0.0_dp) return

      call this%eval(C, pt, state_n, S, CC, state_np1, st, dtf)
      if (st /= DES_MAT_OK) return

      sig = cauchy_from_pk2(F, S, jac)

      !> Nominal (1. Piola-Kirchhoff) gerilme: P = F S, köşegen F için
      !> P11 = F11 * S11.
      p_nom = F(1, 1)*S(1, 1)

      !> Serbest yön: tek eksenlide 2, diğer ikisinde 3.
      if (mode == DES_MODE_UNIAXIAL) then
         sig_free = sig(2, 2)
      else
         sig_free = sig(3, 3)
      end if

      ok = .true.
   end subroutine mode_stress

   !> dP/dlambda, yanal uzama her adımda yeniden çözülerek merkezi farkla.
   subroutine nominal_slope(this, mode, lam, pt, state_n, state_np1, slope, ok)
      class(material_t), intent(in)         :: this
      integer(ip), intent(in)               :: mode
      real(dp), intent(in)                  :: lam
      type(mat_point_t), intent(in)         :: pt
      type(material_state_t), intent(in)    :: state_n
      type(material_state_t), intent(inout) :: state_np1
      real(dp), intent(out)                 :: slope
      logical, intent(out)                  :: ok

      !> Merkezi fark adımı. Kesme hatası O(h^2), yuvarlama O(eps/h);
      !> 1e-4 bu ikisinin dengelendiği bölgededir ve dP/dlambda'yı
      !> yaklaşık 1e-8 bağıl hatayla verir.
      real(dp), parameter :: H_STEP = 1.0e-4_dp

      real(dp) :: p_plus, p_minus, lat

      slope = 0.0_dp

      call this%mode_nominal(mode, lam + H_STEP, pt, state_n, state_np1, &
                             p_plus, lat, ok)
      if (.not. ok) return

      call this%mode_nominal(mode, lam - H_STEP, pt, state_n, state_np1, &
                             p_minus, lat, ok)
      if (.not. ok) return

      slope = (p_plus - p_minus)/(2.0_dp*H_STEP)
      ok = .true.
   end subroutine nominal_slope

   !> Durum değişkeni için varsayılan anahtar: SV1, SV2, ...
   !>
   !> Bu bir anahtardır, kullanıcıya gösterilecek metin DEĞİLDİR. Üst katman
   !> bunu messages dizinindeki tr.toml / en.toml üzerinden çevirir.
   !> Türetilmiş malzemeler anlamlı anahtarlarla (DAMAGE, VISC_1 gibi)
   !> ezebilir; anahtarlar İngilizce ve ASCII kalır.
   !>
   !> NOT: Yorumlarda "/" ve "*" karakterleri yan yana YAZILMAZ. Ninja
   !> üreticisi, modül bağımlılık grafiğini çıkarmak için Fortran
   !> kaynaklarını C ön işlemcisinden geçirir; ön işlemci böyle bir diziyi
   !> C blok yorumu başlangıcı sanır ve "unterminated comment" hatası verir.
   !> Bu, yalnızca Ninja ile ortaya çıkar -- Makefile üreticisinde sessizce
   !> çalışır, dolayısıyla Windows CI'da fark edilir.
   function default_sv_name(this, i) result(key)
      class(material_t), intent(in) :: this
      integer(ip), intent(in) :: i
      character(len=16) :: key

      key = ''
      if (i < 1 .or. i > this%n_sv) return

      write (key, '(a,i0)') 'SV', i
   end function default_sv_name

end module des_material
