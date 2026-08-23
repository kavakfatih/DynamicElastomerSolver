!> ---------------------------------------------------------------------------
!> des_element -- eleman arayüzü (DONDURULMUŞ SÖZLEŞME 2/4)
!>
!> Karar ve gerekçe: ADR 0009. Bu dosya yalnızca SÖZLEŞMEYİ tanımlar;
!> gerçek bir eleman uygulaması (eksenel simetrik Q4) v0.1'de gelecek.
!>
!> DÖRT YETENEK -- hiçbiri şu an kullanılmıyor, hepsi sonradan pahalı
!>
!>   a) Düğüm başına DEĞİŞKEN serbestlik: 2 (u_r, u_z) veya 3 ile burulma.
!>   b) Eleman-dışı GLOBAL serbestlikler: genelleştirilmiş düzlem şekil
!>      değiştirmede eksenel uzama, burulmalı hâlinde ayrıca dönme.
!>      Bunlar bütün elemanlarca PAYLAŞILIR (des_mesh sorumluluğu).
!>   c) Formülasyon stratejisi ÇALIŞMA ZAMANI seçimi:
!>      full | srI | bbar | fbar | mixed_up, artı basınç mertebesi.
!>   d) quality() -- yeniden ağ örme için distorsiyon metrikleri.
!>
!> MALZEME SÖZLEŞMESİYLE İLİŞKİ (ADR 0006 Kural 1)
!>
!> Eleman analiz tipini bilir, malzeme BİLMEZ. Eleman kendi
!> kinematiğinden tam 3x3 C kurar ve malzemeye uzatır. Düzlem gerilme
!> bile malzemeye bildirilmez: kalınlık uzaması eleman tarafında yerel
!> bir Newton ile S_33 = 0 olacak şekilde çözülür.
!>
!> mat_point_t ELEMANIN İÇİNDE KURULUR
!>
!> Eksenel simetride pt%radius her Gauss noktasında farklıdır ve onu
!> yalnızca eleman hesaplayabilir. Aynı gerekçeyle SICAKLIK da eleman
!> içinde interpole edilir: ctx düğüm sıcaklıklarını taşır, eleman
!> bunları Gauss noktalarına taşır. Skaler bir sıcaklık taşınsaydı
!> ısıl-mekanik kuplaj geldiğinde her eleman imzası kırılırdı.
!>
!> Katman: 4 -- Analiz çekirdeği
!> ---------------------------------------------------------------------------
module des_element
   use des_kinds, only: dp, ip
   use des_material, only: material_t, mat_point_t, material_state_t
   implicit none
   private

   public :: DES_ELEM_OK, DES_ELEM_BAD_ARG, DES_ELEM_NOT_SETUP
   public :: DES_ELEM_NOTCONV, DES_ELEM_UNSUPPORTED
   public :: DES_ANA_PLANE_STRAIN, DES_ANA_PLANE_STRESS, DES_ANA_AXISYM
   public :: DES_ANA_AXISYM_TORSION, DES_ANA_GPS, DES_ANA_GPS_TORSION
   public :: DES_FORM_FULL, DES_FORM_SRI, DES_FORM_BBAR, DES_FORM_FBAR
   public :: DES_FORM_MIXED_UP
   public :: DES_P_CONDENSED, DES_P_NODAL
   public :: DES_T_REF, DES_MAX_GDOF_PER_ELEM
   public :: element_config_t, element_ctx_t, element_quality_t, element_t
   public :: ndof_of_analysis, n_global_dof_of_analysis, ctx_temperature_at

   ! --- Durum kodları -------------------------------------------------------
   !> İşlem başarılı.
   integer(ip), parameter :: DES_ELEM_OK = 0_ip
   !> Geçersiz argüman veya boyut uyuşmazlığı.
   integer(ip), parameter :: DES_ELEM_BAD_ARG = 1_ip
   !> `setup` çağrılmadan kullanılmaya çalışıldı.
   integer(ip), parameter :: DES_ELEM_NOT_SETUP = 2_ip
   !> Eleman içi yerel yineleme yakınsamadı (düzlem gerilme, yoğunlaştırma).
   integer(ip), parameter :: DES_ELEM_NOTCONV = 3_ip
   !> Bu eleman istenen analiz tipini veya formülasyonu desteklemiyor.
   integer(ip), parameter :: DES_ELEM_UNSUPPORTED = 4_ip

   ! --- Analiz tipi ---------------------------------------------------------
   integer(ip), parameter :: DES_ANA_PLANE_STRAIN = 1_ip
   integer(ip), parameter :: DES_ANA_PLANE_STRESS = 2_ip
   integer(ip), parameter :: DES_ANA_AXISYM = 3_ip
   integer(ip), parameter :: DES_ANA_AXISYM_TORSION = 4_ip
   integer(ip), parameter :: DES_ANA_GPS = 5_ip
   integer(ip), parameter :: DES_ANA_GPS_TORSION = 6_ip

   ! --- Formülasyon stratejisi ----------------------------------------------
   integer(ip), parameter :: DES_FORM_FULL = 1_ip
   integer(ip), parameter :: DES_FORM_SRI = 2_ip
   integer(ip), parameter :: DES_FORM_BBAR = 3_ip
   integer(ip), parameter :: DES_FORM_FBAR = 4_ip
   integer(ip), parameter :: DES_FORM_MIXED_UP = 5_ip

   ! --- Basınç serbestliğinin yerleşimi -------------------------------------
   !> Eleman içi, statik yoğunlaştırma (VARSAYILAN).
   integer(ip), parameter :: DES_P_CONDENSED = 1_ip
   !> Düğüm serbestliği.
   integer(ip), parameter :: DES_P_NODAL = 2_ip

   !> Referans sıcaklık [K]. Düğüm sıcaklığı verilmediğinde kullanılır.
   real(dp), parameter :: DES_T_REF = 293.15_dp

   !> Bir elemanın kullanabileceği en çok global serbestlik sayısı.
   integer(ip), parameter :: DES_MAX_GDOF_PER_ELEM = 2_ip

   !> ------------------------------------------------------------------------
   !> Eleman kurulum yapılandırması
   !> ------------------------------------------------------------------------
   type :: element_config_t
      integer(ip) :: analysis = DES_ANA_AXISYM
      integer(ip) :: formulation = DES_FORM_FULL
      integer(ip) :: n_gauss = 4_ip
      integer(ip) :: p_layout = DES_P_CONDENSED
      !> Basınç interpolasyon mertebesi (0 = sabit).
      integer(ip) :: p_order = 0_ip
      !> MODEL DÜZEYİ global serbestlik indisleri; kullanılmayanlar 0.
      !> des_mesh%register_global_dof'tan alınır. Aynı anahtarı isteyen
      !> her eleman AYNI indisi alır -- paylaşım budur (ADR 0009 b).
      integer(ip) :: global_dof_ids(DES_MAX_GDOF_PER_ELEM) = 0_ip
   end type element_config_t

   !> ------------------------------------------------------------------------
   !> Eleman bağlamı
   !>
   !> mat_point_t ile AYNI GEREKÇE (ADR 0006): bir dolaylama katmanı,
   !> ileride alan eklemek hiçbir elemanı kırmasın diye.
   !>
   !> SICAKLIK DÜĞÜM BAZLIDIR. Sebep radius ile birebir aynı: sıcaklık da
   !> eleman içinde değişir ve Gauss noktalarına interpole edilir. Skaler
   !> tutulsaydı ısıl-mekanik kuplajda (v0.3-v0.4) her imza kırılırdı.
   !> ------------------------------------------------------------------------
   type :: element_ctx_t
      !> Artımın BAŞINDAKİ toplam zaman [s].
      real(dp) :: time = 0.0_dp
      !> Zaman artımı [s].
      real(dp) :: dt = 0.0_dp
      !> Düğüm sıcaklıkları [K], boyut n_node. Ayrılmamışsa veya boşsa
      !> DES_T_REF kullanılır -- izotermal analizde çağıranın hiçbir şey
      !> vermesi gerekmez.
      real(dp), allocatable :: node_temperature(:)
   end type element_ctx_t

   !> ------------------------------------------------------------------------
   !> Distorsiyon metrikleri (yeniden ağ örme, v0.5)
   !> ------------------------------------------------------------------------
   type :: element_quality_t
      !> min|detJ| / max|detJ|; 1 = mükemmel.
      real(dp) :: jacobian_ratio = 1.0_dp
      !> En uzun kenar / en kısa kenar; 1 = mükemmel.
      real(dp) :: aspect_ratio = 1.0_dp
      real(dp) :: min_angle = 90.0_dp
      real(dp) :: max_angle = 90.0_dp
      !> 0..1 arası birleşik ölçü; 1 = mükemmel. Remesher eşiği bunun
      !> üzerinden kurulur.
      real(dp) :: worst = 1.0_dp
      !> Herhangi bir noktada detJ <= 0.
      logical :: inverted = .false.
      !> Bu eleman quality() uygulamıyor -- yukarıdaki alanlar anlamsız.
      logical :: implemented = .true.
   end type element_quality_t

   !> ------------------------------------------------------------------------
   !> Soyut eleman tipi
   !> ------------------------------------------------------------------------
   type, abstract :: element_t
      !> Eleman tür anahtarı. Kullanıcı metni DEĞİL, çeviri anahtarı.
      character(len=32) :: name = ''
      !> Tanılama için eleman numarası.
      integer(ip) :: id = 0_ip
      type(element_config_t) :: cfg
      logical :: is_setup = .false.
   contains
      procedure(el_setup_i), deferred :: setup
      procedure(el_count_i), deferred :: n_node
      procedure(el_resid_i), deferred :: residual
      procedure(el_tan_i), deferred :: tangent
      procedure(el_qual_i), deferred :: quality
      procedure(el_ser_i), deferred :: serialise
      procedure(el_rst_i), deferred :: restore
      !> Varsayılanları temel sınıftan gelir; override edilebilir.
      procedure :: n_dof_per_node => default_n_dof_per_node
      procedure :: n_global_dof => default_n_global_dof
      procedure :: n_internal_dof => default_n_internal_dof
      procedure :: recover_internal => default_recover_internal
      procedure :: n_gauss => default_n_gauss
      procedure :: point_context => default_point_context
   end type element_t

   abstract interface

      !> Elemanı kurar. Tahsis BURADA yapılır, residual/tangent içinde asla.
      subroutine el_setup_i(this, nodes, cfg, material, stat)
         import :: dp, ip, element_t, element_config_t, material_t
         class(element_t), intent(inout) :: this
         !> Düğüm koordinatları (2, n_node).
         real(dp), intent(in) :: nodes(:, :)
         type(element_config_t), intent(in) :: cfg
         class(material_t), intent(in), target :: material
         integer(ip), intent(out) :: stat
      end subroutine el_setup_i

      pure function el_count_i(this) result(n)
         import :: ip, element_t
         class(element_t), intent(in) :: this
         integer(ip) :: n
      end function el_count_i

      !> İç kuvvet vektörü ve durum güncellemesi.
      !>
      !> state_n / state_np1 GAUSS NOKTASI BAŞINA dizidir (n_gauss).
      !> Tekil bir durum geçirmek, viskoelastisite ve hasar geldiğinde
      !> imzayı kırardı.
      subroutine el_resid_i(this, u, u_global, ctx, state_n, &
                            f_int, f_global, state_np1, stat, dt_factor)
         import :: dp, ip, element_t, element_ctx_t, material_state_t
         class(element_t), intent(inout) :: this
         !> Düğüm yer değiştirmeleri (n_dof_per_node, n_node).
         real(dp), intent(in) :: u(:, :)
         !> Eleman-dışı global serbestlik değerleri (n_global_dof).
         real(dp), intent(in) :: u_global(:)
         type(element_ctx_t), intent(in) :: ctx
         type(material_state_t), intent(in) :: state_n(:)
         real(dp), intent(out) :: f_int(:, :)
         real(dp), intent(out) :: f_global(:)
         type(material_state_t), intent(inout) :: state_np1(:)
         integer(ip), intent(out) :: stat
         real(dp), intent(out) :: dt_factor
      end subroutine el_resid_i

      !> Tanjant blokları.
      !>
      !> K_gu SAKLANMAZ: hiperelastisitede tanjant simetriktir,
      !> K_gu = transpose(K_ug). Montaj bunu kullanır.
      !>
      !> Formülasyon mixed_up ve p_layout condensed ise statik
      !> yoğunlaştırma BURADA, kendiliğinden yapılır -- ayrı bir çağrı
      !> olsaydı çağıran unutabilirdi.
      subroutine el_tan_i(this, u, u_global, ctx, state_n, &
                          K_uu, K_ug, K_gg, stat)
         import :: dp, ip, element_t, element_ctx_t, material_state_t
         class(element_t), intent(inout) :: this
         real(dp), intent(in) :: u(:, :)
         real(dp), intent(in) :: u_global(:)
         type(element_ctx_t), intent(in) :: ctx
         type(material_state_t), intent(in) :: state_n(:)
         real(dp), intent(out) :: K_uu(:, :)
         real(dp), intent(out) :: K_ug(:, :)
         real(dp), intent(out) :: K_gg(:, :)
         integer(ip), intent(out) :: stat
      end subroutine el_tan_i

      subroutine el_qual_i(this, u, q)
         import :: dp, element_t, element_quality_t
         class(element_t), intent(in) :: this
         real(dp), intent(in) :: u(:, :)
         type(element_quality_t), intent(out) :: q
      end subroutine el_qual_i

      !> Eleman durumunu düz bir tampona yazar; -1 = tampon küçük.
      !>
      !> Durum = bütün Gauss noktalarının malzeme durumları ARTI
      !> yoğunlaştırılmış iç serbestlikler. İkincisi unutulursa geri adım
      !> ve yeniden başlatma sessizce yanlış çalışır.
      function el_ser_i(this, buffer) result(n)
         import :: dp, ip, element_t
         class(element_t), intent(in) :: this
         real(dp), intent(inout) :: buffer(:)
         integer(ip) :: n
      end function el_ser_i

      function el_rst_i(this, buffer) result(n)
         import :: dp, ip, element_t
         class(element_t), intent(inout) :: this
         real(dp), intent(in) :: buffer(:)
         integer(ip) :: n
      end function el_rst_i

   end interface

contains

   ! =========================================================================
   ! Analiz tipinden turetilen varsayilanlar
   ! =========================================================================

   !> Analiz tipinin gerektirdiği düğüm başına serbestlik sayısı.
   pure function ndof_of_analysis(analysis) result(nd)
      integer(ip), intent(in) :: analysis
      integer(ip) :: nd

      select case (analysis)
      case (DES_ANA_AXISYM_TORSION, DES_ANA_GPS_TORSION)
         nd = 3_ip
      case (DES_ANA_PLANE_STRAIN, DES_ANA_PLANE_STRESS, &
            DES_ANA_AXISYM, DES_ANA_GPS)
         nd = 2_ip
      case default
         nd = 0_ip
      end select
   end function ndof_of_analysis

   !> Analiz tipinin gerektirdiği eleman-dışı global serbestlik sayısı.
   pure function n_global_dof_of_analysis(analysis) result(ng)
      integer(ip), intent(in) :: analysis
      integer(ip) :: ng

      select case (analysis)
      case (DES_ANA_GPS)
         ng = 1_ip
      case (DES_ANA_GPS_TORSION)
         ng = 2_ip
      case default
         ng = 0_ip
      end select
   end function n_global_dof_of_analysis

   pure function default_n_dof_per_node(this) result(nd)
      class(element_t), intent(in) :: this
      integer(ip) :: nd

      nd = ndof_of_analysis(this%cfg%analysis)
   end function default_n_dof_per_node

   pure function default_n_global_dof(this) result(ng)
      class(element_t), intent(in) :: this
      integer(ip) :: ng

      ng = n_global_dof_of_analysis(this%cfg%analysis)
   end function default_n_global_dof

   pure function default_n_gauss(this) result(ng)
      class(element_t), intent(in) :: this
      integer(ip) :: ng

      ng = this%cfg%n_gauss
   end function default_n_gauss

   !> Yoğunlaştırılmış iç serbestlik sayısı.
   !>
   !> Yalnızca karışık formülasyonda ve basınç eleman içinde tutuluyorsa
   !> sıfırdan farklıdır. Basınç mertebesi p_order ise iç serbestlik
   !> sayısı (p_order + 1) alınır: 0 -> 1 (sabit basınç), 1 -> 2, ...
   pure function default_n_internal_dof(this) result(ni)
      class(element_t), intent(in) :: this
      integer(ip) :: ni

      ni = 0_ip
      if (this%cfg%formulation /= DES_FORM_MIXED_UP) return
      if (this%cfg%p_layout /= DES_P_CONDENSED) return
      ni = this%cfg%p_order + 1_ip
   end function default_n_internal_dof

   !> Küresel çözümden sonra iç serbestlikleri geri yerine koyar.
   !>
   !> Statik yoğunlaştırma TEK YÖNLÜ BİR İŞLEM DEĞİLDİR: küresel sistem
   !> çözüldükten sonra iç serbestlikler geri hesaplanmalıdır
   !> (back-substitution). Bu adım atlanırsa basınç alanı hiç güncellenmez
   !> ve gerilmeler sessizce yanlış çıkar.
   !>
   !> Varsayılan: iç serbestliği olmayan elemanlar için işlem yok.
   subroutine default_recover_internal(this, du, du_global, stat)
      class(element_t), intent(inout) :: this
      real(dp), intent(in) :: du(:, :)
      real(dp), intent(in) :: du_global(:)
      integer(ip), intent(out) :: stat

      stat = DES_ELEM_OK
      if (this%n_internal_dof() == 0_ip) return

      !> İç serbestliği olan bir eleman bunu EZMEK ZORUNDADIR.
      stat = DES_ELEM_UNSUPPORTED

      associate (unused_du => du, unused_dg => du_global)
      end associate
   end subroutine default_recover_internal

   ! =========================================================================
   ! Malzeme noktasi baglami
   ! =========================================================================

   !> Şekil fonksiyonu değerlerinden Gauss noktası sıcaklığını interpole eder.
   !>
   !> `ctx%node_temperature` ayrılmamış, boş veya boyutu şekil fonksiyonu
   !> dizisiyle uyuşmuyorsa DES_T_REF döner. İzotermal analizde çağıranın
   !> hiçbir şey vermesi gerekmemesi bilinçli bir kolaylıktır.
   pure function ctx_temperature_at(ctx, shape_fn) result(temp)
      type(element_ctx_t), intent(in) :: ctx
      real(dp), intent(in) :: shape_fn(:)
      real(dp) :: temp

      temp = DES_T_REF
      if (.not. allocated(ctx%node_temperature)) return
      if (size(ctx%node_temperature) == 0) return
      if (size(ctx%node_temperature) /= size(shape_fn)) return

      temp = dot_product(shape_fn, ctx%node_temperature)
   end function ctx_temperature_at

   !> Bir Gauss noktası için mat_point_t kurar.
   !>
   !> Yarıçap ve sıcaklık burada, ELEMANIN İÇİNDE hesaplanır: ikisi de
   !> şekil fonksiyonlarıyla interpole edilir ve şekil fonksiyonlarını
   !> yalnızca eleman bilir. Eksenel simetrik olmayan analizlerde yarıçap
   !> sıfır kalır.
   pure subroutine default_point_context(this, ctx, shape_fn, node_r, &
                                         ipoint, pt)
      class(element_t), intent(in) :: this
      type(element_ctx_t), intent(in) :: ctx
      real(dp), intent(in) :: shape_fn(:)
      !> Düğümlerin r koordinatları (eksenel simetri için).
      real(dp), intent(in) :: node_r(:)
      integer(ip), intent(in) :: ipoint
      type(mat_point_t), intent(out) :: pt

      pt%time = ctx%time
      pt%dt = ctx%dt
      pt%element = this%id
      pt%point = ipoint
      pt%temperature = ctx_temperature_at(ctx, shape_fn)

      pt%radius = 0.0_dp
      select case (this%cfg%analysis)
      case (DES_ANA_AXISYM, DES_ANA_AXISYM_TORSION)
         if (size(node_r) == size(shape_fn)) then
            pt%radius = dot_product(shape_fn, node_r)
         end if
      end select
   end subroutine default_point_context

end module des_element
