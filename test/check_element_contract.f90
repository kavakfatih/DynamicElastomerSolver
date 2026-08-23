!> ---------------------------------------------------------------------------
!> check_element_contract -- eleman sözleşmesinin davranış testleri (ADR 0009)
!>
!> Gerçek bir eleman henüz yok; SAHTE (mock) bir eleman kullanılır. Test
!> edilen şey sayı değil SÖZLEŞMEdir: bu davranışlardan biri bozulursa,
!> üzerine yazılacak her eleman sessizce yanlış çalışır.
!>
!>   1. n_dof_per_node()  -- 2 ve 3 için doğru
!>   2. n_global_dof()    -- 0, 1, 2 için DOF haritası doğru boyutlanıyor
!>   3. GLOBAL DOF PAYLAŞIMI -- iki eleman aynı serbestliği istediğinde
!>      TEK bir serbestlik veriliyor, iki ayrı değil
!>   4. Gauss noktası başına state + serialise/restore gidiş-dönüşü
!>   5. node_temperature interpolasyonu ve referans sıcaklığa düşme
!>   6. recover_internal() -- iç serbestlik geri konuyor
!>   7. CSR montajı -- elle hesaplanmış küçük matrisle satır satır
!>   8. RCM -- bilinen bir grafta bant genişliği azalıyor
!>
!> 3. madde atlanamaz: sessizce yanlış model üreten hata tam oradadır.
!> ---------------------------------------------------------------------------
module mock_element_mod
   use des_kinds, only: dp, ip
   use des_material, only: material_t, mat_point_t, material_state_t, &
                           DES_MAT_OK
   use des_element, only: element_t, element_config_t, element_ctx_t, &
                          element_quality_t, &
                          DES_ELEM_OK, DES_ELEM_BAD_ARG, &
                          DES_FORM_MIXED_UP, DES_P_CONDENSED
   implicit none
   private

   public :: mock_element_t

   !> Dört düğümlü, dört Gauss noktalı sahte eleman.
   !>
   !> Fizik YOK: residual ve tangent belirlenimci, elle doğrulanabilir
   !> sayılar üretir. Amaç sözleşmenin mekaniğini sınamaktır.
   type, extends(element_t) :: mock_element_t
      real(dp) :: xy(2, 4) = 0.0_dp
      !> Yoğunlaştırılmış iç serbestlikler (en çok 2).
      real(dp) :: p_int(2) = 0.0_dp
      !> Her Gauss noktasının kaç kez değerlendirildiği -- nokta başına
      !> state ayrımının gerçekten korunduğunu göstermek için.
      integer(ip) :: n_eval = 0_ip
   contains
      procedure :: setup => mock_setup
      procedure :: n_node => mock_n_node
      procedure :: residual => mock_residual
      procedure :: tangent => mock_tangent
      procedure :: quality => mock_quality
      procedure :: serialise => mock_serialise
      procedure :: restore => mock_restore
      procedure :: recover_internal => mock_recover_internal
   end type mock_element_t

contains

   subroutine mock_setup(this, nodes, cfg, material, stat)
      class(mock_element_t), intent(inout) :: this
      real(dp), intent(in) :: nodes(:, :)
      type(element_config_t), intent(in) :: cfg
      class(material_t), intent(in), target :: material
      integer(ip), intent(out) :: stat

      stat = DES_ELEM_BAD_ARG
      if (size(nodes, 1) /= 2) return
      if (size(nodes, 2) /= 4) return

      this%name = 'mock_q4'
      this%xy = nodes
      this%cfg = cfg
      this%p_int = 0.0_dp
      this%n_eval = 0_ip
      this%is_setup = .true.
      stat = DES_ELEM_OK

      !> Sahte eleman malzemeyi kullanmıyor; sözleşme gereği imzada.
      associate (unused_mat => material%name)
      end associate
   end subroutine mock_setup

   pure function mock_n_node(this) result(n)
      class(mock_element_t), intent(in) :: this
      integer(ip) :: n
      n = 4_ip
      associate (unused => this%id)
      end associate
   end function mock_n_node

   !> Her Gauss noktasının state'ine NOKTAYA ÖZGÜ bir işaret yazar.
   !>
   !> Böylece "bütün noktalar aynı state'i paylaşıyor" hatası testte
   !> görünür hâle gelir: sv(1) = state_n%sv(1) + nokta numarası.
   subroutine mock_residual(this, u, u_global, ctx, state_n, &
                            f_int, f_global, state_np1, stat, dt_factor)
      class(mock_element_t), intent(inout) :: this
      real(dp), intent(in) :: u(:, :)
      real(dp), intent(in) :: u_global(:)
      type(element_ctx_t), intent(in) :: ctx
      type(material_state_t), intent(in) :: state_n(:)
      real(dp), intent(out) :: f_int(:, :)
      real(dp), intent(out) :: f_global(:)
      type(material_state_t), intent(inout) :: state_np1(:)
      integer(ip), intent(out) :: stat
      real(dp), intent(out) :: dt_factor

      integer(ip) :: g

      stat = DES_ELEM_BAD_ARG
      dt_factor = 1.0_dp
      f_int = 0.0_dp
      f_global = 0.0_dp

      if (size(state_n) /= size(state_np1)) return
      if (size(state_n) /= int(this%cfg%n_gauss)) return

      do g = 1_ip, int(size(state_n), ip)
         if (.not. allocated(state_n(g)%sv)) cycle
         if (.not. allocated(state_np1(g)%sv)) cycle
         if (size(state_np1(g)%sv) /= size(state_n(g)%sv)) cycle
         state_np1(g)%sv = state_n(g)%sv
         if (size(state_np1(g)%sv) >= 1) then
            state_np1(g)%sv(1) = state_n(g)%sv(1) + real(g, dp)
         end if
      end do

      f_int = sum(u)
      if (size(f_global) > 0) f_global = sum(u_global)

      this%n_eval = this%n_eval + 1_ip
      stat = DES_ELEM_OK

      associate (unused_t => ctx%time)
      end associate
   end subroutine mock_residual

   !> Elle doğrulanabilir tanjant: K_uu(a,b) = seed * (a + b).
   subroutine mock_tangent(this, u, u_global, ctx, state_n, &
                           K_uu, K_ug, K_gg, stat)
      class(mock_element_t), intent(inout) :: this
      real(dp), intent(in) :: u(:, :)
      real(dp), intent(in) :: u_global(:)
      type(element_ctx_t), intent(in) :: ctx
      type(material_state_t), intent(in) :: state_n(:)
      real(dp), intent(out) :: K_uu(:, :)
      real(dp), intent(out) :: K_ug(:, :)
      real(dp), intent(out) :: K_gg(:, :)
      integer(ip), intent(out) :: stat

      integer(ip) :: a, b

      K_uu = 0.0_dp
      K_ug = 0.0_dp
      K_gg = 0.0_dp

      do b = 1_ip, int(size(K_uu, 2), ip)
         do a = 1_ip, int(size(K_uu, 1), ip)
            K_uu(a, b) = real(a + b, dp)
         end do
      end do
      if (size(K_gg) > 0) K_gg = 1.0_dp
      if (size(K_ug) > 0) K_ug = 0.5_dp

      stat = DES_ELEM_OK

      associate (unused => u, unused2 => u_global, unused3 => ctx%dt, &
                 unused4 => size(state_n))
      end associate
   end subroutine mock_tangent

   subroutine mock_quality(this, u, q)
      class(mock_element_t), intent(in) :: this
      real(dp), intent(in) :: u(:, :)
      type(element_quality_t), intent(out) :: q

      !> Sahte eleman gerçek distorsiyon hesaplamıyor; sözleşme
      !> "uygulanmadı" durumunu taşıyabilmeli.
      q%implemented = .false.

      associate (unused => u, unused2 => this%id)
      end associate
   end subroutine mock_quality

   !> Eleman durumu = YALNIZCA iç serbestlikler (ADR 0009 e, sahiplik
   !> tablosu). Gauss durumlarının sahibi çözücüdür.
   function mock_serialise(this, buffer) result(n)
      class(mock_element_t), intent(in) :: this
      real(dp), intent(inout) :: buffer(:)
      integer(ip) :: n

      integer(ip) :: m

      m = this%n_internal_dof()
      if (int(size(buffer), ip) < m) then
         n = -1_ip
         return
      end if
      if (m > 0_ip) buffer(1:m) = this%p_int(1:m)
      n = m
   end function mock_serialise

   function mock_restore(this, buffer) result(n)
      class(mock_element_t), intent(inout) :: this
      real(dp), intent(in) :: buffer(:)
      integer(ip) :: n

      integer(ip) :: m

      m = this%n_internal_dof()
      if (int(size(buffer), ip) < m) then
         n = -1_ip
         return
      end if
      if (m > 0_ip) this%p_int(1:m) = buffer(1:m)
      n = m
   end function mock_restore

   !> Statik yoğunlaştırmanın GERİ ADIMI.
   !>
   !> Gerçek bir elemanda bu, küresel çözümden sonra basıncı geri
   !> hesaplar. Burada belirlenimci bir yerine koyma yapılıyor ki testin
   !> "geri konuldu mu" sorusu kesin bir sayıyla cevaplanabilsin.
   subroutine mock_recover_internal(this, du, du_global, stat)
      class(mock_element_t), intent(inout) :: this
      real(dp), intent(in) :: du(:, :)
      real(dp), intent(in) :: du_global(:)
      integer(ip), intent(out) :: stat

      integer(ip) :: m

      stat = DES_ELEM_OK
      m = this%n_internal_dof()
      if (m == 0_ip) return

      this%p_int(1) = sum(du) + sum(du_global)
      if (m >= 2_ip) this%p_int(2) = 2.0_dp*this%p_int(1)
   end subroutine mock_recover_internal

end module mock_element_mod

program check_element_contract
   use des_kinds, only: dp, ip
   use des_material, only: material_state_t
   use des_mat_neohookean, only: mat_neohookean_t, new_neohookean
   use des_mesh, only: mesh_t, DES_MESH_OK, &
                       DES_GDOF_AXIAL_STRETCH, DES_GDOF_TWIST
   use des_sparse, only: sparse_csr_t, rcm_order, DES_SPM_OK
   use des_element, only: element_config_t, element_ctx_t, &
                          element_quality_t, &
                          DES_ELEM_OK, DES_T_REF, &
                          DES_ANA_AXISYM, DES_ANA_AXISYM_TORSION, &
                          DES_ANA_GPS, DES_ANA_GPS_TORSION, &
                          DES_FORM_FULL, DES_FORM_MIXED_UP, &
                          DES_P_CONDENSED, ctx_temperature_at
   use mock_element_mod, only: mock_element_t
   use test_support, only: t_begin, t_check_le, t_check_true, t_check_int, &
                           t_info, t_finish
   implicit none

   type(mock_element_t)     :: el, el2
   type(mat_neohookean_t)   :: mat
   type(element_config_t)   :: cfg
   type(element_ctx_t)      :: ctx
   type(element_quality_t)  :: q
   type(mesh_t)             :: msh
   type(sparse_csr_t)       :: A
   type(material_state_t)   :: sn(4), snp1(4)

   real(dp) :: nodes(2, 4), u(3, 4), ug(2), f_int(3, 4), fg(2)
   real(dp) :: K_uu(12, 12), K_ug(12, 2), K_gg(2, 2)
   real(dp) :: buf(2), tsmall(1)
   real(dp) :: shp(4), temp
   real(dp) :: dt_factor
   integer(ip) :: stat, g, idx1, idx2, idx3, n
   integer(ip) :: dofs(16), nd

   call t_begin('Eleman sozlesmesi  (ADR 0009, sahte eleman)')

   nodes = reshape([0.0_dp, 0.0_dp, 1.0_dp, 0.0_dp, &
                    1.0_dp, 1.0_dp, 0.0_dp, 1.0_dp], [2, 4])
   mat = new_neohookean(0.6_dp, 1.0e5_dp)

   ! =========================================================================
   ! 1 -- n_dof_per_node()
   ! =========================================================================
   call t_info('')
   call t_info(' 1. Dugum basina degisken DOF')

   cfg%analysis = DES_ANA_AXISYM
   cfg%n_gauss = 4_ip
   call el%setup(nodes, cfg, mat, stat)
   call t_check_int('eksenel simetrik : setup OK', stat, DES_ELEM_OK)
   call t_check_int('eksenel simetrik : DOF/dugum', el%n_dof_per_node(), 2_ip)

   cfg%analysis = DES_ANA_AXISYM_TORSION
   call el%setup(nodes, cfg, mat, stat)
   call t_check_int('burulmali        : DOF/dugum', el%n_dof_per_node(), 3_ip)

   ! =========================================================================
   ! 2 -- n_global_dof() ve DOF haritasi boyutu
   ! =========================================================================
   call t_info('')
   call t_info(' 2. Eleman-disi global DOF sayisi')

   cfg%analysis = DES_ANA_AXISYM
   call el%setup(nodes, cfg, mat, stat)
   call t_check_int('eksenel simetrik : global DOF', el%n_global_dof(), 0_ip)

   cfg%analysis = DES_ANA_GPS
   call el%setup(nodes, cfg, mat, stat)
   call t_check_int('GPS              : global DOF', el%n_global_dof(), 1_ip)

   cfg%analysis = DES_ANA_GPS_TORSION
   call el%setup(nodes, cfg, mat, stat)
   call t_check_int('GPS + burulma    : global DOF', el%n_global_dof(), 2_ip)

   !> DOF haritasi: 4 dugum x 3 DOF + 2 global = 14
   call msh%init(4_ip, 1_ip, 4_ip, 3_ip, stat)
   call t_check_int('mesh init', stat, DES_MESH_OK)
   call msh%register_global_dof(DES_GDOF_AXIAL_STRETCH, idx1, stat)
   call msh%register_global_dof(DES_GDOF_TWIST, idx2, stat)
   call msh%build_dof_map(stat)
   call t_check_int('4 dugum x 3 DOF + 2 global = 14', msh%n_dof, 14_ip)
   call t_check_int('dugum DOF toplami = 12', msh%n_node_dof, 12_ip)
   call t_check_int('global DOF sayisi = 2', msh%n_gdof, 2_ip)
   call t_check_int('1. global DOF global no = 13', msh%global_dof(1_ip), 13_ip)
   call t_check_int('2. global DOF global no = 14', msh%global_dof(2_ip), 14_ip)

   ! =========================================================================
   ! 3 -- GLOBAL DOF PAYLASIMI  (bu testi atlamak sessizce yanlis model verir)
   ! =========================================================================
   call t_info('')
   call t_info(' 3. Global DOF PAYLASIMI  -- iki eleman, tek serbestlik')

   call msh%init(6_ip, 2_ip, 4_ip, 2_ip, stat)

   !> Iki ayri eleman AYNI anahtari istiyor.
   call msh%register_global_dof(DES_GDOF_AXIAL_STRETCH, idx1, stat)
   call t_check_int('1. eleman kayit OK', stat, DES_MESH_OK)
   call msh%register_global_dof(DES_GDOF_AXIAL_STRETCH, idx2, stat)
   call t_check_int('2. eleman kayit OK', stat, DES_MESH_OK)

   call t_check_int('ayni anahtar -> AYNI indis', idx2, idx1)
   call t_check_int('toplam global DOF hala 1', msh%n_gdof, 1_ip)

   !> Farkli anahtar ise yeni serbestlik acmali.
   call msh%register_global_dof(DES_GDOF_TWIST, idx3, stat)
   call t_check_true('farkli anahtar -> FARKLI indis', idx3 /= idx1)
   call t_check_int('toplam global DOF simdi 2', msh%n_gdof, 2_ip)

   call msh%build_dof_map(stat)
   call t_check_int('6 dugum x 2 + 2 global = 14', msh%n_dof, 14_ip)

   !> Iki elemanin DOF listesi ayni global numarayi gostermeli.
   msh%conn(1:4, 1) = [1_ip, 2_ip, 3_ip, 4_ip]
   msh%conn(1:4, 2) = [3_ip, 4_ip, 5_ip, 6_ip]
   msh%n_node_of = 4_ip

   call msh%element_dofs(1_ip, [idx1, 0_ip], dofs, nd, stat)
   call t_check_int('eleman 1 DOF sayisi = 8+1', nd, 9_ip)
   n = dofs(nd)
   call msh%element_dofs(2_ip, [idx2, 0_ip], dofs, nd, stat)
   call t_check_int('eleman 2 DOF sayisi = 8+1', nd, 9_ip)
   call t_check_int('iki eleman AYNI global DOF numarasini goruyor', &
                    dofs(nd), n)

   ! =========================================================================
   ! 4 -- Gauss noktasi basina state + serialise/restore
   ! =========================================================================
   call t_info('')
   call t_info(' 4. Gauss noktasi basina state')

   cfg%analysis = DES_ANA_AXISYM_TORSION
   cfg%formulation = DES_FORM_MIXED_UP
   cfg%p_layout = DES_P_CONDENSED
   cfg%p_order = 1_ip
   cfg%n_gauss = 4_ip
   call el%setup(nodes, cfg, mat, stat)

   do g = 1_ip, 4_ip
      call sn(g)%init(2_ip)
      call snp1(g)%init(2_ip)
      sn(g)%sv = [10.0_dp*real(g, dp), 0.0_dp]
   end do

   u = 0.0_dp
   ug = 0.0_dp
   call el%residual(u, ug, ctx, sn, f_int, fg, snp1, stat, dt_factor)
   call t_check_int('residual OK', stat, DES_ELEM_OK)

   !> Her nokta kendi state'ini korumali: sv(1) = 10*g + g
   do g = 1_ip, 4_ip
      call t_check_le('nokta basina state ayri', &
                      abs(snp1(g)%sv(1) - (10.0_dp*real(g, dp) + real(g, dp))), &
                      0.0_dp)
   end do

   !> Eleman kendi durumunu (ic serbestlikler) tasiyor.
   call t_check_int('p_order=1 -> ic serbestlik 2', el%n_internal_dof(), 2_ip)
   el%p_int = [3.5_dp, -1.25_dp]
   buf = 0.0_dp
   n = el%serialise(buf)
   call t_check_int('serialise -> 2 eleman', n, 2_ip)
   el%p_int = 0.0_dp
   n = el%restore(buf)
   call t_check_int('restore -> 2 eleman', n, 2_ip)
   call t_check_le('gidis-donus farki', &
                   maxval(abs(el%p_int - [3.5_dp, -1.25_dp])), 0.0_dp)

   n = el%serialise(tsmall)
   call t_check_int('kucuk tampon -> -1', n, -1_ip)

   ! =========================================================================
   ! 4b -- tangent: uc blok  (K_uu, K_ug, K_gg)
   ! =========================================================================
   call t_info('')
   call t_info(' 4b. Tanjant bloklari  -- K_gu SAKLANMAZ, transpose(K_ug)')

   K_uu = 0.0_dp
   K_ug = 0.0_dp
   K_gg = 0.0_dp
   call el%tangent(u, ug, ctx, sn, K_uu, K_ug, K_gg, stat)
   call t_check_int('tangent OK', stat, DES_ELEM_OK)
   call t_check_le('K_uu(1,1) = 2', abs(K_uu(1, 1) - 2.0_dp), 0.0_dp)
   call t_check_le('K_uu(3,5) = 8', abs(K_uu(3, 5) - 8.0_dp), 0.0_dp)
   call t_check_le('K_uu simetrik', &
                   maxval(abs(K_uu - transpose(K_uu))), 0.0_dp)
   call t_check_le('K_ug dolduruldu', abs(K_ug(1, 1) - 0.5_dp), 0.0_dp)
   call t_check_le('K_gg dolduruldu', abs(K_gg(1, 1) - 1.0_dp), 0.0_dp)

   !> K_uu boyutu = n_dof_per_node * n_node = 3 * 4 = 12
   call t_check_int('K_uu boyutu = 3 DOF x 4 dugum', &
                    el%n_dof_per_node()*el%n_node(), 12_ip)

   ! =========================================================================
   ! 5 -- node_temperature interpolasyonu
   ! =========================================================================
   call t_info('')
   call t_info(' 5. Dugum sicakligi interpolasyonu')

   shp = [0.25_dp, 0.25_dp, 0.25_dp, 0.25_dp]

   !> Ayrilmamis -> referans sicaklik
   temp = ctx_temperature_at(ctx, shp)
   call t_check_le('ayrilmamis -> 293.15', abs(temp - DES_T_REF), 0.0_dp)

   !> Kosede farkli sicakliklar; merkezde ortalama
   allocate (ctx%node_temperature(4))
   ctx%node_temperature = [300.0_dp, 400.0_dp, 500.0_dp, 600.0_dp]
   temp = ctx_temperature_at(ctx, shp)
   call t_check_le('merkez: (300+400+500+600)/4 = 450', &
                   abs(temp - 450.0_dp), 1.0e-13_dp)

   !> Bir kosede yogunlasan sekil fonksiyonu -> o dugumun sicakligi
   shp = [1.0_dp, 0.0_dp, 0.0_dp, 0.0_dp]
   temp = ctx_temperature_at(ctx, shp)
   call t_check_le('kose 1: 300', abs(temp - 300.0_dp), 0.0_dp)

   !> Boyut uyusmazligi -> referans sicaklik (sessizce yanlis interpolasyon yok)
   deallocate (ctx%node_temperature)
   allocate (ctx%node_temperature(3))
   ctx%node_temperature = 350.0_dp
   temp = ctx_temperature_at(ctx, shp)
   call t_check_le('boyut uyusmazligi -> 293.15', abs(temp - DES_T_REF), 0.0_dp)

   ! =========================================================================
   ! 6 -- recover_internal()
   ! =========================================================================
   call t_info('')
   call t_info(' 6. recover_internal  (yogunlastirmanin geri adimi)')

   el%p_int = 0.0_dp
   u = 0.0_dp
   u(1, 1) = 2.0_dp
   u(2, 3) = 5.0_dp
   ug = [1.0_dp, 0.0_dp]
   call el%recover_internal(u, ug, stat)
   call t_check_int('recover_internal OK', stat, DES_ELEM_OK)
   call t_check_le('ic serbestlik geri konuldu (2+5+1 = 8)', &
                   abs(el%p_int(1) - 8.0_dp), 1.0e-13_dp)
   call t_check_le('ikinci ic serbestlik = 16', &
                   abs(el%p_int(2) - 16.0_dp), 1.0e-13_dp)

   !> Ic serbestligi olmayan eleman icin islem yok, hata da yok.
   cfg%formulation = DES_FORM_FULL
   call el2%setup(nodes, cfg, mat, stat)
   call t_check_int('full formulasyon -> ic serbestlik 0', &
                    el2%n_internal_dof(), 0_ip)
   call el2%recover_internal(u, ug, stat)
   call t_check_int('ic serbestlik yok -> OK', stat, DES_ELEM_OK)

   call el2%quality(u, q)
   call t_check_true('quality: uygulanmadi bildiriliyor', .not. q%implemented)

   ! =========================================================================
   ! 7 -- CSR montaji  (elle hesaplanmis matris)
   ! =========================================================================
   call t_info('')
   call t_info(' 7. CSR montaji  -- 3 dugum, 2 eleman, elle dogrulanmis')
   call t_info('    ke1 = [[2,-1],[-1,2]] dof(1,2)   ke2 = [[3,-2],[-2,3]] dof(2,3)')

   call assemble_small(A)

   call t_check_int('A(1,1) = 2', nint(A%get(1_ip, 1_ip)), 2_ip)
   call t_check_int('A(1,2) = -1', nint(A%get(1_ip, 2_ip)), -1_ip)
   call t_check_int('A(2,1) = -1', nint(A%get(2_ip, 1_ip)), -1_ip)
   call t_check_int('A(2,2) = 2+3 = 5', nint(A%get(2_ip, 2_ip)), 5_ip)
   call t_check_int('A(2,3) = -2', nint(A%get(2_ip, 3_ip)), -2_ip)
   call t_check_int('A(3,2) = -2', nint(A%get(3_ip, 2_ip)), -2_ip)
   call t_check_int('A(3,3) = 3', nint(A%get(3_ip, 3_ip)), 3_ip)
   call t_check_int('A(1,3) = 0 (desende yok)', nint(A%get(1_ip, 3_ip)), 0_ip)
   call t_check_int('nnz = 7', A%nnz, 7_ip)

   !> zero() deseni korumali, degerleri silmeli.
   call A%zero()
   call t_check_int('zero sonrasi nnz degismedi', A%nnz, 7_ip)
   call t_check_int('zero sonrasi A(2,2) = 0', nint(A%get(2_ip, 2_ip)), 0_ip)

   ! =========================================================================
   ! 8 -- RCM siralamasi
   ! =========================================================================
   call t_info('')
   call t_info(' 8. RCM  -- yol grafi 1-4-2-5-3-6, bant 3 -> 1 olmali')

   call check_rcm()

   write (*, '(a)') ''
   call t_finish()

contains

   !> 3 dugum, 2 eleman, dugum basina 1 DOF. Elle hesaplanmis global matris.
   subroutine assemble_small(Aout)
      type(sparse_csr_t), intent(out) :: Aout

      integer(ip) :: ed(2, 2), nof(2), st
      real(dp) :: ke1(2, 2), ke2(2, 2)

      ed(:, 1) = [1_ip, 2_ip]
      ed(:, 2) = [2_ip, 3_ip]
      nof = 2_ip

      call Aout%analyse(3_ip, ed, nof, .false., stat=st)
      if (st /= DES_SPM_OK) then
         write (*, '(a,i0)') '   analyse basarisiz, stat = ', st
         error stop 2
      end if
      call Aout%zero()

      ke1 = reshape([2.0_dp, -1.0_dp, -1.0_dp, 2.0_dp], [2, 2])
      ke2 = reshape([3.0_dp, -2.0_dp, -2.0_dp, 3.0_dp], [2, 2])

      call Aout%add_block(ed(:, 1), 2_ip, ke1, st)
      if (st /= DES_SPM_OK) error stop 3
      call Aout%add_block(ed(:, 2), 2_ip, ke2, st)
      if (st /= DES_SPM_OK) error stop 4
   end subroutine assemble_small

   subroutine check_rcm()
      integer(ip) :: adj(2, 6), adj_n(6), perm(6), st
      !> `ia` adi bilincli: tek harfli `a`, host kapsamindaki A seyrek
      !> matrisini maskelerdi (bkz. AGENTS.md, host maskeleme kurali).
      integer(ip) :: bw_before, bw_after, ia, k, w

      adj = 0_ip
      adj(1, 1) = 4_ip;               adj_n(1) = 1_ip
      adj(1, 2) = 4_ip; adj(2, 2) = 5_ip; adj_n(2) = 2_ip
      adj(1, 3) = 5_ip; adj(2, 3) = 6_ip; adj_n(3) = 2_ip
      adj(1, 4) = 1_ip; adj(2, 4) = 2_ip; adj_n(4) = 2_ip
      adj(1, 5) = 2_ip; adj(2, 5) = 3_ip; adj_n(5) = 2_ip
      adj(1, 6) = 3_ip;               adj_n(6) = 1_ip

      bw_before = 0_ip
      do ia = 1_ip, 6_ip
         do k = 1_ip, adj_n(ia)
            bw_before = max(bw_before, abs(ia - adj(k, ia)))
         end do
      end do

      call rcm_order(adj, adj_n, perm, st)
      call t_check_int('rcm_order OK', st, DES_SPM_OK)

      bw_after = 0_ip
      do ia = 1_ip, 6_ip
         do k = 1_ip, adj_n(ia)
            w = adj(k, ia)
            bw_after = max(bw_after, abs(perm(ia) - perm(w)))
         end do
      end do

      write (*, '(a,i0,a,i0)') '   bant genisligi: ', bw_before, ' -> ', bw_after
      call t_check_int('RCM oncesi bant = 3', bw_before, 3_ip)
      call t_check_true('RCM sonrasi bant azaldi', bw_after < bw_before)
      call t_check_int('yol grafinda bant = 1', bw_after, 1_ip)

      !> perm bir PERMUTASYON olmali: 1..6'nin her biri tam bir kez.
      block
         logical :: hit(6)
         hit = .false.
         do ia = 1_ip, 6_ip
            if (perm(ia) >= 1_ip .and. perm(ia) <= 6_ip) hit(perm(ia)) = .true.
         end do
         call t_check_true('perm gecerli permutasyon', all(hit))
      end block
   end subroutine check_rcm

end program check_element_contract
