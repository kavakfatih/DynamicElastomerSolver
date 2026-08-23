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
   use des_tensor, only: cc_to_mandel, cholesky_margin
   implicit none
   private

   public :: DES_MAT_OK, DES_MAT_SINGULAR, DES_MAT_NONPHYSICAL, DES_MAT_NOTCONV
   public :: DES_STAB_OK, DES_STAB_UNSTABLE, DES_STAB_UNKNOWN
   public :: mat_point_t, material_state_t, material_t

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
   !> Drucker kararlılığı sağlanıyor.
   integer(ip), parameter :: DES_STAB_OK = 0_ip
   !> Malzeme tanjantı pozitif tanımlı değil: kararsız.
   integer(ip), parameter :: DES_STAB_UNSTABLE = 1_ip
   !> Karar verilemedi (tanjant hesaplanamadı).
   integer(ip), parameter :: DES_STAB_UNKNOWN = 2_ip

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
   !> Soyut malzeme temel tipi
   !>
   !> Türetilmiş malzemeler yalnızca `eval`i yazmak zorundadır. Kararlılık
   !> kontrolünü ve durum değişkeni adlandırmasını temel sınıftan bedava
   !> alırlar -- gelecekte eklenecek kullanıcı malzemeleri dahil.
   !> ------------------------------------------------------------------------
   type, abstract :: material_t
      !> Malzeme tür anahtarı. Kullanıcıya gösterilecek metin DEĞİL; üst
      !> katmandaki çeviri tablosunun anahtarıdır. ASCII ve İngilizce kalır.
      character(len=32) :: name = ''
      !> Durum değişkeni sayısı.
      integer(ip) :: n_sv = 0_ip
   contains
      procedure(material_eval_i), deferred :: eval
      procedure :: check_stability => check_drucker
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

   !> GENEL DRUCKER KARARLILIK KONTROLÜ
   !>
   !> Drucker kararlılığı dS:dE > 0 ister. dE = dC/2 ve dS = (1/2) CC:dC
   !> kullanılarak bu koşul, CC'nin simetrik ikinci mertebe tensörler
   !> uzayında pozitif tanımlı olmasına indirgenir.
   !>
   !> Uygulama: CC ortonormal Mandel/Kelvin bazında 6x6 matrise indirgenir,
   !> sonra Cholesky denenir. Cholesky'nin başarısı TAM OLARAK pozitif
   !> tanımlılıktır; özdeğer çözücüsü gerekmez -- bu, çekirdeğin LAPACK'e
   !> bağımlı olmadan kararlılık kontrolü yapabilmesi demektir.
   !>
   !> Bu yordam `eval`den başka hiçbir şeye ihtiyaç duymaz. Bu yüzden BÜTÜN
   !> malzemeler kararlılık kontrolünü bedava alır: Ogden, viskoelastisite,
   !> Mullins ve ileride yazılacak kullanıcı malzemeleri dahil.
   !>
   !> state_np1 çalışma alanı olarak istenir çünkü `eval` onu yazmak
   !> zorundadır ve malzeme tahsis edemez (kural 2).
   subroutine check_drucker(this, C, pt, state_n, state_np1, stat, margin)
      class(material_t), intent(in)         :: this
      real(dp), intent(in)                  :: C(3, 3)
      type(mat_point_t), intent(in)         :: pt
      type(material_state_t), intent(in)    :: state_n
      type(material_state_t), intent(inout) :: state_np1
      integer(ip), intent(out)              :: stat
      real(dp), intent(out)                 :: margin

      real(dp) :: S(3, 3), CC(3, 3, 3, 3), M(6, 6)
      real(dp) :: dt_factor
      integer(ip) :: estat
      logical :: pd

      margin = 0.0_dp

      call this%eval(C, pt, state_n, S, CC, state_np1, estat, dt_factor)

      !> Tanjant hesaplanamadıysa kararlılık hakkında konuşulamaz.
      !> "Kararsız" demek yanlış olur: bilinmiyor.
      if (estat /= DES_MAT_OK) then
         stat = DES_STAB_UNKNOWN
         return
      end if

      call cc_to_mandel(CC, M)
      call cholesky_margin(M, pd, margin)

      if (pd) then
         stat = DES_STAB_OK
      else
         stat = DES_STAB_UNSTABLE
      end if
   end subroutine check_drucker

   !> Durum değişkeni için varsayılan anahtar: SV1, SV2, ...
   !>
   !> Bu bir anahtardır, kullanıcıya gösterilecek metin DEĞİLDİR. Üst katman
   !> bunu messages/*.toml üzerinden çevirir. Türetilmiş malzemeler anlamlı
   !> anahtarlarla (DAMAGE, VISC_1 gibi) ezebilir; anahtarlar İngilizce ve
   !> ASCII kalır.
   function default_sv_name(this, i) result(key)
      class(material_t), intent(in) :: this
      integer(ip), intent(in) :: i
      character(len=16) :: key

      key = ''
      if (i < 1 .or. i > this%n_sv) return

      write (key, '(a,i0)') 'SV', i
   end function default_sv_name

end module des_material
