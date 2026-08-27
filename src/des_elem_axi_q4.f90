!> ---------------------------------------------------------------------------
!> des_elem_axi_q4 -- eksenel simetrik 4 düğümlü dörtgen eleman
!>
!> ADR 0009'daki eleman sözleşmesinin İLK GERÇEK UYGULAMASI.
!> Toplam Lagrange formülasyonu, bilineer şekil fonksiyonları, 2x2 Gauss.
!>
!> KİNEMATİK  (bileşen sırası r, z, theta)
!>
!>    F_rr = dr/dR = 1 + du_r/dR      F_rz = dr/dZ = du_r/dZ
!>    F_zr = dz/dR = du_z/dR          F_zz = dz/dZ = 1 + du_z/dZ
!>    F_tt = r/R   = 1 + u_r/R
!>    diğer bileşenler sıfır  (burulma YOK; u_theta v0.2'de gelecek)
!>
!> EKSEN ÜZERİNDEKİ DÜĞÜMLER (R -> 0)
!>
!> F_tt = 1 + u_r/R ifadesi eksende 0/0 belirsizidir. Eksenel simetri
!> u_r(0) = 0 gerektirdiği için L'Hôpital kuralı uygulanır:
!>
!>    lim_{R->0} u_r/R = du_r/dR    =>    F_tt -> F_rr
!>
!> yani eksende çevresel (hoop) uzama radyal uzamaya eşittir.
!>
!> PRATİKTE BU DAL NEREDEYSE HİÇ ÇALIŞMAZ ve bir güvence olarak durur:
!> 2x2 Gauss kuralında integrasyon noktaları elemanın İÇİNDEDİR, dolayısıyla
!> ekseni kenarıyla kesen bir elemanda bile en yakın noktanın yarıçapı
!> 0.2113*h'dir. Dal ancak dejenere bir elemanda tetiklenir ve orada NaN
!> yerine sonlu bir değer üretir.
!>
!> Artık (residual) ifadesinde 1/R zaten sadeleşir: hoop katkısı
!> (N_a/R) * R = N_a olur. Tanjantta sadeleşmez ve gerçek bir 1/R kalır;
!> yukarıdaki gerekçeyle Gauss noktalarında sonludur.
!>
!> F-BAR -- ORTALAMA GENLESME (mean dilatation) BICIMI
!>
!>    F_bar = theta * F,   theta = (J_bar/J)^(1/3)
!>    J_bar = (1/V) * integral J dV0        (ELEMAN ORTALAMASI)
!>
!> Buradan det F_bar = J_bar çıkar: hacim cevabı eleman ortalamasından,
!> şekil cevabı Gauss noktasından gelir -- kilitlenme (locking) çaresi
!> tam olarak budur.
!>
!> NEDEN MERKEZ DEĞİL, ORTALAMA
!>
!> J_bar yerine merkezdeki J_0 alınırsa ve formülasyon varyasyonel
!> tutulursa (yani iç kuvvet W = integral Psi(F_bar(u)) dV'nin tam türevi
!> olursa) YAMA TESTİ GEÇİLEMEZ. Homojen bir durumda artık şuna iner:
!>
!>    f_a = 0 - (p/3) integral (g:dF_a) dV + (p/3) V (g0 : dF0_a)
!>
!> Son iki terim ancak  integral dF_a dV = V * dF_a(merkez)  ise
!> sadeleşir; bu eşitlik ÇARPIK bir elemanda sağlanmaz. Ölçüldü: çarpık
!> dört elemanlı yamada iç düğüm artığı (-185.8, +829.0) çıkıyor.
!>
!> J_bar eleman ortalaması alındığında dJ_bar tanım gereği dF'in eleman
!> ortalamasını içerir ve iki terim TAM sadeleşir. Bu, Nagtegaal-Parks-
!> Rice ve Simo-Taylor-Pister'in ortalama genleşme yöntemidir.
!>
!> BU UYGULAMA VARYASYONEL OLARAK TUTARLIDIR. İç kuvvet, enerjinin
!> W(u) = integral Psi(F_bar(u)) dV fonksiyonelinin TAM türevidir;
!> tanjant da tam ikinci türevidir. Sonuç: tanjant SİMETRİKTİR.
!>
!> de Souza Neto'nun klasik F-bar'ı gerilmeyi F_bar'dan alıp artığı F ile
!> kurar; o varyant yama testini geçer ama simetrik OLMAYAN bir tanjant
!> üretir ve simetrik doğrusal çözücü sözleşmesini kırar. Ortalama
!> genleşme her ikisini birden verir: yama testi VE simetri.
!>
!> Bu oturumda YALNIZCA DES_FORM_FULL ve DES_FORM_FBAR uygulanmıştır.
!> mixed_up, bbar ve srI sözleşmede vardır ama gövdeleri v0.3'tedir;
!> istendiğinde DES_ELEM_UNSUPPORTED döner.
!>
!> Katman: 4 -- Analiz çekirdeği
!> ---------------------------------------------------------------------------
module des_elem_axi_q4
   use des_kinds, only: dp, ip
   use des_tensor, only: det3, inv3, cauchy_from_pk2
   use des_material, only: material_t, mat_point_t, material_state_t, &
                           DES_MAT_OK
   use des_element, only: element_t, element_config_t, element_ctx_t, &
                          element_quality_t, ctx_temperature_at, &
                          DES_ELEM_OK, DES_ELEM_BAD_ARG, DES_ELEM_NOT_SETUP, &
                          DES_ELEM_UNSUPPORTED, &
                          DES_ANA_AXISYM, DES_FORM_FULL, DES_FORM_FBAR
   implicit none
   private

   public :: elem_axi_q4_t, new_axi_q4

   !> Düğüm sayısı ve serbestlik sayısı (u_r, u_z).
   integer(ip), parameter :: NNOD = 4_ip
   integer(ip), parameter :: NDOF = 2_ip
   integer(ip), parameter :: NGP = 4_ip

   !> Eksen eşiği: bir Gauss noktasının yarıçapı, elemanın ortalama
   !> yarıçap ölçeğinin bu katından küçükse L'Hôpital dalına geçilir.
   real(dp), parameter :: AXIS_REL_TOL = 1.0e-12_dp

   type, extends(element_t) :: elem_axi_q4_t
      !> Referans düğüm koordinatları.
      real(dp) :: XR(NNOD) = 0.0_dp
      real(dp) :: XZ(NNOD) = 0.0_dp
      !> Yarıçap ölçeği (eksen eşiği için).
      real(dp) :: r_scale = 1.0_dp
      !> Malzeme. Çağıran, elemanın ömrü boyunca malzemeyi canlı tutmalıdır.
      class(material_t), pointer :: mat => null()
      !> `tangent` içinde eval'in yazacağı çalışma alanı. Malzeme tahsis
      !> edemez, eleman da sıcak döngüde edemez -- burada, setup'ta ayrılır.
      type(material_state_t), allocatable :: scratch(:)
   contains
      procedure :: setup => q4_setup
      procedure :: n_node => q4_n_node
      procedure :: residual => q4_residual
      procedure :: tangent => q4_tangent
      procedure :: quality => q4_quality
      procedure :: serialise => q4_serialise
      procedure :: restore => q4_restore
      !> Sozlesme disi TANI yordami -- bkz. asagidaki not.
      procedure :: gauss_state => q4_gauss_state
   end type elem_axi_q4_t

contains

   !> Kurucu kolaylığı; setup yine de çağrılmalıdır.
   pure function new_axi_q4(id) result(e)
      integer(ip), intent(in) :: id
      type(elem_axi_q4_t) :: e

      e%name = 'axi_q4'
      e%id = id
   end function new_axi_q4

   ! =========================================================================
   ! Sekil fonksiyonlari
   ! =========================================================================

   !> Bilineer Q4 şekil fonksiyonları ve dogal koordinat türevleri.
   pure subroutine shape_q4(xi, eta, N, dNdxi, dNdeta)
      real(dp), intent(in) :: xi, eta
      real(dp), intent(out) :: N(NNOD), dNdxi(NNOD), dNdeta(NNOD)

      N(1) = 0.25_dp*(1.0_dp - xi)*(1.0_dp - eta)
      N(2) = 0.25_dp*(1.0_dp + xi)*(1.0_dp - eta)
      N(3) = 0.25_dp*(1.0_dp + xi)*(1.0_dp + eta)
      N(4) = 0.25_dp*(1.0_dp - xi)*(1.0_dp + eta)

      dNdxi(1) = -0.25_dp*(1.0_dp - eta)
      dNdxi(2) = 0.25_dp*(1.0_dp - eta)
      dNdxi(3) = 0.25_dp*(1.0_dp + eta)
      dNdxi(4) = -0.25_dp*(1.0_dp + eta)

      dNdeta(1) = -0.25_dp*(1.0_dp - xi)
      dNdeta(2) = -0.25_dp*(1.0_dp + xi)
      dNdeta(3) = 0.25_dp*(1.0_dp + xi)
      dNdeta(4) = 0.25_dp*(1.0_dp - xi)
   end subroutine shape_q4

   !> 2x2 Gauss noktaları ve ağırlıkları.
   pure subroutine gauss_2x2(g, xi, eta, w)
      integer(ip), intent(in) :: g
      real(dp), intent(out) :: xi, eta, w

      real(dp), parameter :: A = 0.577350269189625764509148780502_dp
      real(dp), parameter :: PX(4) = [-A, A, A, -A]
      real(dp), parameter :: PY(4) = [-A, -A, A, A]

      xi = PX(g)
      eta = PY(g)
      w = 1.0_dp
   end subroutine gauss_2x2

   !> Verilen doğal koordinatta kartezyen türevler ve Jacobian determinantı.
   pure subroutine cart_derivs(XR, XZ, xi, eta, N, dNdR, dNdZ, detj, ok)
      real(dp), intent(in) :: XR(NNOD), XZ(NNOD)
      real(dp), intent(in) :: xi, eta
      real(dp), intent(out) :: N(NNOD), dNdR(NNOD), dNdZ(NNOD)
      real(dp), intent(out) :: detj
      logical, intent(out) :: ok

      real(dp) :: dNdxi(NNOD), dNdeta(NNOD)
      real(dp) :: j11, j12, j21, j22, inv

      call shape_q4(xi, eta, N, dNdxi, dNdeta)

      j11 = dot_product(dNdxi, XR)
      j12 = dot_product(dNdxi, XZ)
      j21 = dot_product(dNdeta, XR)
      j22 = dot_product(dNdeta, XZ)

      detj = j11*j22 - j12*j21

      if (abs(detj) <= tiny(1.0_dp)) then
         ok = .false.
         dNdR = 0.0_dp
         dNdZ = 0.0_dp
         return
      end if

      ok = .true.
      inv = 1.0_dp/detj

      !> Jacobian tersi. J = [[dR/dxi, dZ/dxi], [dR/deta, dZ/deta]] ve
      !>
      !>   [dN/dxi ]   [ j11  j12 ] [dN/dR]
      !>   [dN/deta] = [ j21  j22 ] [dN/dZ]
      !>
      !> olduğundan tersi
      !>
      !>   dN/dR = ( j22*dN/dxi - j12*dN/deta) / det
      !>   dN/dZ = (-j21*dN/dxi + j11*dN/deta) / det
      !>
      !> DİKKAT: j12 ile j21 yer değiştirirse DİKDÖRTGEN elemanda hiçbir
      !> şey olmaz (ikisi de sıfırdır) ama ÇARPIK elemanda kinematik
      !> sessizce yanlış çıkar. Bu hata bir kez yapıldı ve yalnızca
      !> VER-033 yama testi (çarpık ağ) yakaladı.
      dNdR = (j22*dNdxi - j12*dNdeta)*inv
      dNdZ = (-j21*dNdxi + j11*dNdeta)*inv
   end subroutine cart_derivs

   ! =========================================================================
   ! Kinematik
   ! =========================================================================

   !> Bir noktada deformasyon gradyanı ve hoop türev katsayıları.
   !>
   !> `hoop(a)` = dF_tt/du_ra. Eksen dışında N_a/R, eksende L'Hôpital ile
   !> dN_a/dR olur.
   !> `u` bilincli olarak varsayilan-sekilli (assumed shape): cagiranlar
   !> daha buyuk bir tampondan dilim geciriyor; acik sekilli bir kukla
   !> argüman her cagrida gecici bir kopya urettirirdi.
   pure subroutine kinematics(u, N, dNdR, dNdZ, Rg, r_scale, F, hoop, on_axis)
      real(dp), intent(in) :: u(:, :)
      real(dp), intent(in) :: N(NNOD), dNdR(NNOD), dNdZ(NNOD)
      real(dp), intent(in) :: Rg, r_scale
      real(dp), intent(out) :: F(3, 3)
      real(dp), intent(out) :: hoop(NNOD)
      logical, intent(out) :: on_axis

      real(dp) :: ur

      F = 0.0_dp
      F(1, 1) = 1.0_dp + dot_product(u(1, :), dNdR)
      F(1, 2) = dot_product(u(1, :), dNdZ)
      F(2, 1) = dot_product(u(2, :), dNdR)
      F(2, 2) = 1.0_dp + dot_product(u(2, :), dNdZ)

      on_axis = (Rg <= AXIS_REL_TOL*r_scale)

      if (on_axis) then
         !> L'Hôpital: F_tt -> 1 + du_r/dR = F_rr
         F(3, 3) = F(1, 1)
         hoop = dNdR
      else
         ur = dot_product(u(1, :), N)
         F(3, 3) = 1.0_dp + ur/Rg
         hoop = N/Rg
      end if
   end subroutine kinematics

   !> (düğüm a, serbestlik i) için sanal deformasyon gradyanı.
   pure subroutine virtual_F(a, i, dNdR, dNdZ, hoop, dF)
      integer(ip), intent(in) :: a, i
      real(dp), intent(in) :: dNdR(NNOD), dNdZ(NNOD), hoop(NNOD)
      real(dp), intent(out) :: dF(3, 3)

      dF = 0.0_dp
      if (i == 1_ip) then
         dF(1, 1) = dNdR(a)
         dF(1, 2) = dNdZ(a)
         dF(3, 3) = hoop(a)
      else
         dF(2, 1) = dNdR(a)
         dF(2, 2) = dNdZ(a)
      end if
   end subroutine virtual_F

   ! =========================================================================
   ! Sozlesme yordamlari
   ! =========================================================================

   subroutine q4_setup(this, nodes, cfg, material, stat)
      class(elem_axi_q4_t), intent(inout) :: this
      real(dp), intent(in) :: nodes(:, :)
      type(element_config_t), intent(in) :: cfg
      class(material_t), intent(in), target :: material
      integer(ip), intent(out) :: stat

      real(dp) :: N(NNOD), dNdR(NNOD), dNdZ(NNOD), detj, xi, eta, w
      integer(ip) :: g
      logical :: ok

      stat = DES_ELEM_BAD_ARG
      this%is_setup = .false.

      if (size(nodes, 1) /= 2) return
      if (size(nodes, 2) /= NNOD) return

      !> Bu eleman yalnızca eksenel simetrik analiz içindir.
      if (cfg%analysis /= DES_ANA_AXISYM) then
         stat = DES_ELEM_UNSUPPORTED
         return
      end if

      !> Bu oturumda uygulanmış formülasyonlar.
      if (cfg%formulation /= DES_FORM_FULL .and. &
          cfg%formulation /= DES_FORM_FBAR) then
         stat = DES_ELEM_UNSUPPORTED
         return
      end if

      if (cfg%n_gauss /= NGP) return

      this%XR = nodes(1, :)
      this%XZ = nodes(2, :)
      this%cfg = cfg
      this%name = 'axi_q4'
      this%mat => material

      !> Yarıçap ölçeği: eksen eşiği bunun göreli katı olarak alınır.
      this%r_scale = maxval(abs(this%XR))
      if (this%r_scale <= 0.0_dp) this%r_scale = 1.0_dp

      !> REFERANS konfigürasyonda ters dönmüş eleman bir AĞ HATASIDIR ve
      !> burada reddedilir; sonraki her hesap anlamsız olurdu.
      do g = 1_ip, NGP
         call gauss_2x2(g, xi, eta, w)
         call cart_derivs(this%XR, this%XZ, xi, eta, N, dNdR, dNdZ, detj, ok)
         if (.not. ok .or. detj <= 0.0_dp) then
            stat = DES_ELEM_BAD_ARG
            return
         end if
      end do

      if (allocated(this%scratch)) deallocate (this%scratch)
      allocate (this%scratch(NGP))
      do g = 1_ip, NGP
         call this%scratch(g)%init(material%n_sv)
      end do

      this%is_setup = .true.
      stat = DES_ELEM_OK
   end subroutine q4_setup

   pure function q4_n_node(this) result(n)
      class(elem_axi_q4_t), intent(in) :: this
      integer(ip) :: n

      n = int(size(this%XR), ip)
   end function q4_n_node

   !> ------------------------------------------------------------------------
   !> BİRİNCİ GEÇİŞ: bütün Gauss noktalarının kinematiği ve J_bar
   !>
   !> theta her noktada J_bar'a bağlıdır, J_bar ise bütün noktalara --
   !> bu yüzden iki geçiş zorunludur. Merkez tabanlı biçimde tek geçiş
   !> yeterdi; ortalama genleşmenin bedeli budur.
   !> ------------------------------------------------------------------------
   subroutine element_kinematics(this, u, Fs, gs, Js, ws, dRs, dZs, hps, &
                                 vtot, jbar, ok)
      class(elem_axi_q4_t), intent(in) :: this
      real(dp), intent(in) :: u(:, :)
      real(dp), intent(out) :: Fs(3, 3, NGP), gs(3, 3, NGP)
      real(dp), intent(out) :: Js(NGP), ws(NGP)
      real(dp), intent(out) :: dRs(NNOD, NGP), dZs(NNOD, NGP), hps(NNOD, NGP)
      real(dp), intent(out) :: vtot, jbar
      logical, intent(out) :: ok

      real(dp) :: N(NNOD), detj, xi, eta, w, Rg, Finv(3, 3), jv
      integer(ip) :: g
      logical :: on_axis

      Fs = 0.0_dp; gs = 0.0_dp; Js = 0.0_dp; ws = 0.0_dp
      dRs = 0.0_dp; dZs = 0.0_dp; hps = 0.0_dp
      vtot = 0.0_dp; jbar = 0.0_dp; jv = 0.0_dp
      ok = .false.

      do g = 1_ip, NGP
         call gauss_2x2(g, xi, eta, w)
         call cart_derivs(this%XR, this%XZ, xi, eta, N, dRs(:, g), dZs(:, g), &
                          detj, ok)
         if (.not. ok) return

         Rg = dot_product(N, this%XR)
         call kinematics(u, N, dRs(:, g), dZs(:, g), Rg, this%r_scale, &
                         Fs(:, :, g), hps(:, g), on_axis)

         Js(g) = det3(Fs(:, :, g))
         if (Js(g) <= 0.0_dp) then
            ok = .false.
            return
         end if

         call inv3(Fs(:, :, g), Js(g), Finv, ok)
         if (.not. ok) return
         gs(:, :, g) = transpose(Finv)

         ws(g) = Rg*detj*w
         vtot = vtot + ws(g)
         jv = jv + ws(g)*Js(g)
      end do

      if (vtot <= 0.0_dp) then
         ok = .false.
         return
      end if
      jbar = jv/vtot
      ok = (jbar > 0.0_dp)
   end subroutine element_kinematics

   !> dJ_bar / du -- her (düğüm, serbestlik) için.
   !>
   !>    dJ_bar_a = (1/V) * sum_g w_g J_g (g_g : dF_a,g)
   !>
   !> Yama testinin geçmesini sağlayan terim budur: J_bar eleman
   !> ortalaması olduğu için bu ifade dF'in ortalamasını taşır.
   pure subroutine jbar_gradient(gs, Js, ws, dRs, dZs, hps, vtot, qj)
      real(dp), intent(in) :: gs(3, 3, NGP), Js(NGP), ws(NGP)
      real(dp), intent(in) :: dRs(NNOD, NGP), dZs(NNOD, NGP), hps(NNOD, NGP)
      real(dp), intent(in) :: vtot
      real(dp), intent(out) :: qj(NDOF, NNOD)

      real(dp) :: dF(3, 3)
      integer(ip) :: g, a, i

      qj = 0.0_dp
      do g = 1_ip, NGP
         do a = 1_ip, NNOD
            do i = 1_ip, NDOF
               call virtual_F(a, i, dRs(:, g), dZs(:, g), hps(:, g), dF)
               qj(i, a) = qj(i, a) + ws(g)*Js(g)*sum(gs(:, :, g)*dF)
            end do
         end do
      end do
      qj = qj/vtot
   end subroutine jbar_gradient

   subroutine q4_residual(this, u, u_global, ctx, state_n, &
                          f_int, f_global, state_np1, stat, dt_factor)
      class(elem_axi_q4_t), intent(inout) :: this
      real(dp), intent(in) :: u(:, :)
      real(dp), intent(in) :: u_global(:)
      type(element_ctx_t), intent(in) :: ctx
      type(material_state_t), intent(in) :: state_n(:)
      real(dp), intent(out) :: f_int(:, :)
      real(dp), intent(out) :: f_global(:)
      type(material_state_t), intent(inout) :: state_np1(:)
      integer(ip), intent(out) :: stat
      real(dp), intent(out) :: dt_factor

      real(dp) :: Fs(3, 3, NGP), gs(3, 3, NGP), Js(NGP), ws(NGP)
      real(dp) :: dRs(NNOD, NGP), dZs(NNOD, NGP), hps(NNOD, NGP)
      real(dp) :: qj(NDOF, NNOD)
      real(dp) :: N(NNOD), Fb(3, 3), Cb(3, 3), S(3, 3), CC(3, 3, 3, 3)
      real(dp) :: P(3, 3), Aeff(3, 3), dF(3, 3)
      real(dp) :: vtot, jbar, th, pp, bacc, dtf, xi, eta, w, detj, Rg
      real(dp) :: dum1(NNOD), dum2(NNOD)
      type(mat_point_t) :: pt
      integer(ip) :: g, a, i, mstat
      logical :: ok, fbar

      f_int = 0.0_dp
      f_global = 0.0_dp
      dt_factor = 1.0_dp
      stat = DES_ELEM_BAD_ARG

      if (.not. this%is_setup) then
         stat = DES_ELEM_NOT_SETUP
         return
      end if
      if (size(u, 1) /= NDOF .or. size(u, 2) /= NNOD) return
      if (size(f_int, 1) /= NDOF .or. size(f_int, 2) /= NNOD) return
      if (size(state_n) /= NGP .or. size(state_np1) /= NGP) return

      fbar = (this%cfg%formulation == DES_FORM_FBAR)

      call element_kinematics(this, u, Fs, gs, Js, ws, dRs, dZs, hps, &
                              vtot, jbar, ok)
      if (.not. ok) then
         call nonphysical(stat, dt_factor)
         return
      end if

      qj = 0.0_dp
      if (fbar) call jbar_gradient(gs, Js, ws, dRs, dZs, hps, vtot, qj)

      bacc = 0.0_dp

      do g = 1_ip, NGP
         call gauss_2x2(g, xi, eta, w)
         call cart_derivs(this%XR, this%XZ, xi, eta, N, dum1, dum2, detj, ok)
         if (.not. ok) return
         Rg = dot_product(N, this%XR)

         pt%time = ctx%time
         pt%dt = ctx%dt
         pt%element = this%id
         pt%point = g
         pt%radius = Rg
         pt%temperature = ctx_temperature_at(ctx, N)

         if (fbar) then
            th = (jbar/Js(g))**(1.0_dp/3.0_dp)
         else
            th = 1.0_dp
         end if
         Fb = th*Fs(:, :, g)

         Cb = matmul(transpose(Fb), Fb)
         call this%mat%eval(Cb, pt, state_n(g), S, CC, state_np1(g), &
                            mstat, dtf)
         if (mstat /= DES_MAT_OK) then
            call nonphysical(stat, dt_factor)
            dt_factor = dtf
            return
         end if

         P = matmul(Fb, S)

         if (fbar) then
            pp = sum(P*Fs(:, :, g))
            Aeff = th*P - (pp*th/3.0_dp)*gs(:, :, g)
            bacc = bacc + ws(g)*pp*th/(3.0_dp*jbar)
         else
            Aeff = P
         end if

         do a = 1_ip, NNOD
            do i = 1_ip, NDOF
               call virtual_F(a, i, dRs(:, g), dZs(:, g), hps(:, g), dF)
               f_int(i, a) = f_int(i, a) + ws(g)*sum(Aeff*dF)
            end do
         end do
      end do

      !> J_bar bağlaşım terimi.
      if (fbar) f_int = f_int + bacc*qj

      stat = DES_ELEM_OK

      associate (unused => u_global)
      end associate
   end subroutine q4_residual

   !> Fiziksel olmayan durum: çözücüden adım küçültme iste.
   pure subroutine nonphysical(stat, dt_factor)
      integer(ip), intent(out) :: stat
      real(dp), intent(out) :: dt_factor

      stat = DES_ELEM_OK
      dt_factor = 0.25_dp
   end subroutine nonphysical

   subroutine q4_tangent(this, u, u_global, ctx, state_n, &
                         K_uu, K_ug, K_gg, stat)
      class(elem_axi_q4_t), intent(inout) :: this
      real(dp), intent(in) :: u(:, :)
      real(dp), intent(in) :: u_global(:)
      type(element_ctx_t), intent(in) :: ctx
      type(material_state_t), intent(in) :: state_n(:)
      real(dp), intent(out) :: K_uu(:, :)
      real(dp), intent(out) :: K_ug(:, :)
      real(dp), intent(out) :: K_gg(:, :)
      integer(ip), intent(out) :: stat

      real(dp) :: Fs(3, 3, NGP), gs(3, 3, NGP), Js(NGP), ws(NGP)
      real(dp) :: dRs(NNOD, NGP), dZs(NNOD, NGP), hps(NNOD, NGP)
      real(dp) :: qj(NDOF, NNOD)
      real(dp) :: Ss(3, 3, NGP), Ps(3, 3, NGP), CCs(3, 3, 3, 3, NGP)
      real(dp) :: ths(NGP), pps(NGP)
      real(dp) :: N(NNOD), Fb(3, 3), Cb(3, 3), dum1(NNOD), dum2(NNOD)
      real(dp) :: dF(3, 3), DFg(3, 3), DFb(3, 3), DCb(3, 3), DS(3, 3)
      real(dp) :: DPbar(3, 3), Dgg(3, 3), DAeff(3, 3), Finv(3, 3)
      real(dp) :: vtot, jbar, bacc, dtf, xi, eta, w, detj, Rg
      real(dp) :: DJbar, Dth, Dpp, DJg, Dbacc, DdJbar, kadd
      type(mat_point_t) :: pt
      integer(ip) :: g, a, i, b, j, row, col, mstat
      logical :: ok, fbar

      K_uu = 0.0_dp
      K_ug = 0.0_dp
      K_gg = 0.0_dp
      stat = DES_ELEM_BAD_ARG

      if (.not. this%is_setup) then
         stat = DES_ELEM_NOT_SETUP
         return
      end if
      if (size(u, 1) /= NDOF .or. size(u, 2) /= NNOD) return
      if (size(K_uu, 1) /= NDOF*NNOD .or. size(K_uu, 2) /= NDOF*NNOD) return
      if (size(state_n) /= NGP) return

      fbar = (this%cfg%formulation == DES_FORM_FBAR)

      call element_kinematics(this, u, Fs, gs, Js, ws, dRs, dZs, hps, &
                              vtot, jbar, ok)
      if (.not. ok) return

      qj = 0.0_dp
      if (fbar) call jbar_gradient(gs, Js, ws, dRs, dZs, hps, vtot, qj)

      !> Birinci geçiş: malzeme değerlendirmeleri saklanır ki sütun
      !> döngüsünde sekiz kez tekrarlanmasın.
      bacc = 0.0_dp
      do g = 1_ip, NGP
         call gauss_2x2(g, xi, eta, w)
         call cart_derivs(this%XR, this%XZ, xi, eta, N, dum1, dum2, detj, ok)
         if (.not. ok) return
         Rg = dot_product(N, this%XR)

         pt%time = ctx%time
         pt%dt = ctx%dt
         pt%element = this%id
         pt%point = g
         pt%radius = Rg
         pt%temperature = ctx_temperature_at(ctx, N)

         if (fbar) then
            ths(g) = (jbar/Js(g))**(1.0_dp/3.0_dp)
         else
            ths(g) = 1.0_dp
         end if
         Fb = ths(g)*Fs(:, :, g)

         Cb = matmul(transpose(Fb), Fb)
         call this%mat%eval(Cb, pt, state_n(g), Ss(:, :, g), CCs(:, :, :, :, g), &
                            this%scratch(g), mstat, dtf)
         if (mstat /= DES_MAT_OK) return

         Ps(:, :, g) = matmul(Fb, Ss(:, :, g))
         pps(g) = sum(Ps(:, :, g)*Fs(:, :, g))
         if (fbar) bacc = bacc + ws(g)*pps(g)*ths(g)/(3.0_dp*jbar)
      end do

      !> Sütun sütun tam artım.
      do b = 1_ip, NNOD
         do j = 1_ip, NDOF
            col = (b - 1_ip)*NDOF + j

            DJbar = 0.0_dp
            if (fbar) DJbar = qj(j, b)
            Dbacc = 0.0_dp

            do g = 1_ip, NGP
               call virtual_F(b, j, dRs(:, g), dZs(:, g), hps(:, g), DFg)

               if (fbar) then
                  DJg = Js(g)*sum(gs(:, :, g)*DFg)
                  Dth = (ths(g)/3.0_dp) &
                        *(DJbar/jbar - sum(gs(:, :, g)*DFg))
                  DFb = ths(g)*DFg + Dth*Fs(:, :, g)
               else
                  DJg = 0.0_dp
                  Dth = 0.0_dp
                  DFb = DFg
               end if

               Fb = ths(g)*Fs(:, :, g)
               DCb = matmul(transpose(DFb), Fb) + matmul(transpose(Fb), DFb)
               call contract_cc(CCs(:, :, :, :, g), DCb, DS)
               DPbar = matmul(DFb, Ss(:, :, g)) + matmul(Fb, DS)

               if (fbar) then
                  Dpp = sum(DPbar*Fs(:, :, g)) + sum(Ps(:, :, g)*DFg)
                  call inv3(Fs(:, :, g), Js(g), Finv, ok)
                  if (.not. ok) return
                  call inv_derivative(Finv, DFg, Dgg)
                  DAeff = Dth*Ps(:, :, g) + ths(g)*DPbar &
                          - ((Dpp*ths(g) + pps(g)*Dth)/3.0_dp)*gs(:, :, g) &
                          - (pps(g)*ths(g)/3.0_dp)*Dgg
                  Dbacc = Dbacc + ws(g)*((Dpp*ths(g) + pps(g)*Dth) &
                                         /(3.0_dp*jbar) &
                                         - pps(g)*ths(g)*DJbar &
                                         /(3.0_dp*jbar*jbar))
               else
                  Dgg = 0.0_dp
                  DAeff = DPbar
               end if

               do a = 1_ip, NNOD
                  do i = 1_ip, NDOF
                     row = (a - 1_ip)*NDOF + i
                     call virtual_F(a, i, dRs(:, g), dZs(:, g), hps(:, g), dF)
                     kadd = ws(g)*sum(DAeff*dF)

                     !> d(dJ_bar_a) bağlaşımı: J_bar hem satırın hem
                     !> sütunun fonksiyonu olduğu için bu terim çift
                     !> yönlüdür ve tanjantın simetrik kalmasını sağlar.
                     if (fbar) then
                        DdJbar = ws(g)*(DJg*sum(gs(:, :, g)*dF) &
                                        + Js(g)*sum(Dgg*dF))/vtot
                        kadd = kadd + bacc*DdJbar
                     end if

                     K_uu(row, col) = K_uu(row, col) + kadd
                  end do
               end do
            end do

            if (fbar) then
               do a = 1_ip, NNOD
                  do i = 1_ip, NDOF
                     row = (a - 1_ip)*NDOF + i
                     K_uu(row, col) = K_uu(row, col) + Dbacc*qj(i, a)
                  end do
               end do
            end if
         end do
      end do

      stat = DES_ELEM_OK

      associate (unused => u_global)
      end associate
   end subroutine q4_tangent

   !> dS = (1/2) CC : dC
   pure subroutine contract_cc(CC, dC, dS)
      real(dp), intent(in) :: CC(3, 3, 3, 3)
      real(dp), intent(in) :: dC(3, 3)
      real(dp), intent(out) :: dS(3, 3)

      integer(ip) :: ii, jj, kk, ll
      real(dp) :: acc

      do jj = 1_ip, 3_ip
         do ii = 1_ip, 3_ip
            acc = 0.0_dp
            do ll = 1_ip, 3_ip
               do kk = 1_ip, 3_ip
                  acc = acc + CC(ii, jj, kk, ll)*dC(kk, ll)
               end do
            end do
            dS(ii, jj) = 0.5_dp*acc
         end do
      end do
   end subroutine contract_cc

   !> g = F^-T iken Dg. Ainv = F^-1 verilir.
   !>
   !> d(F^-1)_Ji = -(F^-1)_Jk dF_kL (F^-1)_Li   ve   g_iJ = (F^-1)_Ji
   pure subroutine inv_derivative(Ainv, dA, dg)
      real(dp), intent(in) :: Ainv(3, 3)
      real(dp), intent(in) :: dA(3, 3)
      real(dp), intent(out) :: dg(3, 3)

      real(dp) :: tmp(3, 3)

      !> tmp = -F^-1 dF F^-1  (bu, d(F^-1)'dir)
      tmp = -matmul(Ainv, matmul(dA, Ainv))
      dg = transpose(tmp)
   end subroutine inv_derivative

   !> Distorsiyon metrikleri, MEVCUT (deforme) konfigürasyonda.
   !>
   !> Remesher'ın ilgilendiği şey referans ağ değil, bozulmuş olan ağdır.
   subroutine q4_quality(this, u, q)
      class(elem_axi_q4_t), intent(in) :: this
      real(dp), intent(in) :: u(:, :)
      type(element_quality_t), intent(out) :: q

      real(dp) :: xr(NNOD), xz(NNOD), N(NNOD), dNdR(NNOD), dNdZ(NNOD)
      real(dp) :: detj, xi, eta, w, dmin, dmax
      real(dp) :: elen(NNOD), ang(NNOD)
      real(dp) :: v1r, v1z, v2r, v2z, l1, l2, cosang
      integer(ip) :: g, a, ap, am
      logical :: ok
      real(dp), parameter :: RAD2DEG = 57.29577951308232_dp

      q%implemented = .true.
      q%inverted = .false.
      q%jacobian_ratio = 0.0_dp
      q%aspect_ratio = 0.0_dp
      q%min_angle = 0.0_dp
      q%max_angle = 180.0_dp
      q%worst = 0.0_dp

      if (.not. this%is_setup) return
      if (size(u, 1) /= NDOF .or. size(u, 2) /= NNOD) return

      xr = this%XR + u(1, :)
      xz = this%XZ + u(2, :)

      !> Jacobian oranı ve ters dönme.
      dmin = huge(1.0_dp)
      dmax = 0.0_dp
      do g = 1_ip, NGP
         call gauss_2x2(g, xi, eta, w)
         call cart_derivs(xr, xz, xi, eta, N, dNdR, dNdZ, detj, ok)
         if (.not. ok .or. detj <= 0.0_dp) then
            q%inverted = .true.
            q%jacobian_ratio = 0.0_dp
            q%worst = 0.0_dp
            dmin = 0.0_dp
            exit
         end if
         dmin = min(dmin, detj)
         dmax = max(dmax, detj)
      end do

      if (.not. q%inverted .and. dmax > 0.0_dp) then
         q%jacobian_ratio = dmin/dmax
      end if

      !> Kenar uzunlukları ve köşe açıları.
      do a = 1_ip, NNOD
         ap = a + 1_ip
         if (ap > NNOD) ap = 1_ip
         elen(a) = hypot(xr(ap) - xr(a), xz(ap) - xz(a))
      end do

      if (minval(elen) <= 0.0_dp) then
         q%inverted = .true.
         return
      end if
      q%aspect_ratio = maxval(elen)/minval(elen)

      do a = 1_ip, NNOD
         ap = a + 1_ip
         if (ap > NNOD) ap = 1_ip
         am = a - 1_ip
         if (am < 1_ip) am = NNOD

         v1r = xr(ap) - xr(a); v1z = xz(ap) - xz(a)
         v2r = xr(am) - xr(a); v2z = xz(am) - xz(a)
         l1 = hypot(v1r, v1z)
         l2 = hypot(v2r, v2z)
         if (l1 <= 0.0_dp .or. l2 <= 0.0_dp) then
            ang(a) = 0.0_dp
            cycle
         end if
         cosang = (v1r*v2r + v1z*v2z)/(l1*l2)
         cosang = max(-1.0_dp, min(1.0_dp, cosang))
         ang(a) = acos(cosang)*RAD2DEG
      end do

      q%min_angle = minval(ang)
      q%max_angle = maxval(ang)

      if (q%inverted) then
         q%worst = 0.0_dp
      else
         q%worst = min(q%jacobian_ratio, &
                       1.0_dp/max(q%aspect_ratio, 1.0_dp), &
                       q%min_angle/90.0_dp, &
                       (180.0_dp - q%max_angle)/90.0_dp)
         q%worst = max(0.0_dp, min(1.0_dp, q%worst))
      end if
   end subroutine q4_quality

   !> Bir Gauss noktasındaki deformasyon gradyanını ve Cauchy gerilmesini
   !> döndürür.
   !>
   !> SÖZLEŞME DIŞIDIR. ADR 0009'daki eleman sözleşmesinde gerilme çıktısı
   !> alacak bir yordam YOKTUR; bu, sözleşmede gerçek bir boşluktur ve son
   !> işlem (post-processing) yazılırken bir ADR revizyonu gerektirecektir.
   !> Şimdilik bu somut elemana ait bir tanı yordamı olarak duruyor ve
   !> VER-032'nin elemanın kinematiğini gerçekten sınamasını sağlıyor:
   !> bu olmadan test yalnızca malzemeyi doğrular, elemanı değil.
   !>
   !> `F_out` F-bar uygulanmamış HAM deformasyon gradyanıdır; `sig_out`
   !> ise malzemenin gördüğü tensörden (yani F-bar açıksa F_bar'dan)
   !> hesaplanır.
   subroutine q4_gauss_state(this, u, g, F_out, sig_out, stat)
      class(elem_axi_q4_t), intent(inout) :: this
      real(dp), intent(in) :: u(:, :)
      integer(ip), intent(in) :: g
      real(dp), intent(out) :: F_out(3, 3)
      real(dp), intent(out) :: sig_out(3, 3)
      integer(ip), intent(out) :: stat

      real(dp) :: N(NNOD), dNdR(NNOD), dNdZ(NNOD), hoop(NNOD)
      real(dp) :: Fs(3, 3, NGP), gs(3, 3, NGP), Js(NGP), ws(NGP)
      real(dp) :: dRs(NNOD, NGP), dZs(NNOD, NGP), hps(NNOD, NGP)
      real(dp) :: Fb(3, 3), Cb(3, 3), S(3, 3), CC(3, 3, 3, 3)
      real(dp) :: xi, eta, w, detj, Rg, jac, vtot, jbar, th, dtf
      type(mat_point_t) :: pt
      integer(ip) :: mstat
      logical :: ok, on_axis

      F_out = 0.0_dp
      sig_out = 0.0_dp
      stat = DES_ELEM_BAD_ARG

      if (.not. this%is_setup) then
         stat = DES_ELEM_NOT_SETUP
         return
      end if
      if (g < 1_ip .or. g > NGP) return
      if (size(u, 1) /= NDOF .or. size(u, 2) /= NNOD) return

      call gauss_2x2(g, xi, eta, w)
      call cart_derivs(this%XR, this%XZ, xi, eta, N, dNdR, dNdZ, detj, ok)
      if (.not. ok) return

      Rg = dot_product(N, this%XR)
      call kinematics(u, N, dNdR, dNdZ, Rg, this%r_scale, F_out, hoop, on_axis)

      jac = det3(F_out)
      if (jac <= 0.0_dp) return

      if (this%cfg%formulation == DES_FORM_FBAR) then
         !> theta eleman ortalamasi J_bar'a baglidir; butun Gauss
         !> noktalari gerekir.
         call element_kinematics(this, u, Fs, gs, Js, ws, dRs, dZs, hps, &
                                 vtot, jbar, ok)
         if (.not. ok) return
         th = (jbar/jac)**(1.0_dp/3.0_dp)
      else
         th = 1.0_dp
      end if
      Fb = th*F_out

      pt%element = this%id
      pt%point = g
      pt%radius = Rg

      Cb = matmul(transpose(Fb), Fb)
      call this%mat%eval(Cb, pt, this%scratch(g), S, CC, this%scratch(g), &
                         mstat, dtf)
      if (mstat /= DES_MAT_OK) return

      sig_out = cauchy_from_pk2(Fb, S, det3(Fb))
      stat = DES_ELEM_OK
   end subroutine q4_gauss_state

   !> Bu eleman yoğunlaştırılmış iç serbestlik taşımaz (full ve fbar).
   !> Sözleşme gereği yordamlar yine de var: v0.3'te mixed_up eklendiğinde
   !> gövdeleri dolacak.
   function q4_serialise(this, buffer) result(n)
      class(elem_axi_q4_t), intent(in) :: this
      real(dp), intent(inout) :: buffer(:)
      integer(ip) :: n

      integer(ip) :: m

      m = this%n_internal_dof()
      if (int(size(buffer), ip) < m) then
         n = -1_ip
         return
      end if
      n = m
   end function q4_serialise

   function q4_restore(this, buffer) result(n)
      class(elem_axi_q4_t), intent(inout) :: this
      real(dp), intent(in) :: buffer(:)
      integer(ip) :: n

      integer(ip) :: m

      m = this%n_internal_dof()
      if (int(size(buffer), ip) < m) then
         n = -1_ip
         return
      end if
      n = m
   end function q4_restore

end module des_elem_axi_q4
