!> ---------------------------------------------------------------------------
!> check_patch -- VER-033: yama testi (patch test)
!>
!> Programın GERÇEKTEN bir sınır değer problemi çözdüğünün ilk kanıtı.
!> Montaj, sınır koşulu, doğrusal çözücü ve Newton'un tamamı burada aynı
!> anda sınanır: dördünden biri yanlışsa bu test geçmez.
!>
!> KURULUM
!>
!> Dört elemanlı, bilinçli olarak ÇARPIK bir yama. Yalnızca 5 numaralı
!> düğüm İÇERİDEdir ve serbesttir; sekiz sınır düğümüne homojen
!> deformasyona karşılık gelen yer değiştirmeler dayatılır.
!>
!>       7-------8-------9        Z = 1
!>       |       |       |
!>       4-------5-------6        5 = IC DUGUM (serbest), carpik
!>       |       |       |
!>       1-------2-------3        Z = 0
!>      R=1             R=2
!>
!> Kenar orta düğümleri de kaydırılmıştır: yama testi düzgün OLMAYAN bir
!> ağda geçmelidir, aksi hâlde hiçbir şey kanıtlamaz.
!>
!> EKSENEL SİMETRİDE "SABİT GERİLME" NE DEMEK
!>
!> Düzlem problemlerde sabit gerilme durumu DOĞRUSAL bir yer değiştirme
!> alanına karşılık gelir. Eksenel simetride bu DOĞRU DEĞİLDİR, çünkü
!> F_tt = r/R = 1 + u_r/R kinematiği yer değiştirmenin kendisini içerir.
!>
!> Doğru seçim DÜZGÜN GENİŞLEMEdir:
!>
!>     u_r = (lam - 1) * R      u_z = (lam_z - 1) * Z
!>
!> Bu alanda du_r/dR = lam - 1 ve u_r/R = lam - 1 olur, yani
!> F_rr = F_tt = lam ve F her yerde SABİTtir.
!>
!> Ayrıca bu durum DENGE denklemini de sağlar: eksenel simetrik denge
!>
!>     dsigma_rr/dr + (sigma_rr - sigma_tt)/r + dsigma_rz/dz = 0
!>
!> ifadesinde F_rr = F_tt olduğu için sigma_rr = sigma_tt çıkar ve hoop
!> terimi kendiliğinden sıfırlanır. Yani düzgün genişleme gerçekten bir
!> denge çözümüdür -- yama testinin anlamlı olması bunu gerektirir.
!>
!> BEKLENEN
!>
!> İç düğüm TAM OLARAK doğrusal alanın verdiği yere gider ve on altı Gauss
!> noktasının HEPSİNDE gerilme aynı çıkar:
!>
!>     C10 = 0.6, K = 1e5, lam = 1.1  ->  J = 1.331
!>     sigma_rr = sigma_zz = sigma_tt = 33100.000000000
!>
!> Bu, VER-032 (a) ile birebir aynı malzeme durumudur.
!>
!> TOLERANS: 1e-12 bağıl. Yama testinde AYRIKLAŞTIRMA HATASI YOKTUR --
!> bilineer şekil fonksiyonları doğrusal alanı tam temsil eder. Sapma
!> varsa montaj, sınır koşulu, çözücü veya eleman yanlıştır. Tolerans
!> tartışmaya kapalıdır.
!> ---------------------------------------------------------------------------
program check_patch
   use des_kinds, only: dp, ip
   use des_mesh, only: mesh_t, DES_MESH_OK
   use des_sparse, only: sparse_csr_t
   use des_material, only: material_state_t
   use des_mat_neohookean, only: mat_neohookean_t, new_neohookean
   use des_element, only: element_config_t, element_ctx_t, &
                          DES_ELEM_OK, DES_ANA_AXISYM, &
                          DES_FORM_FULL, DES_FORM_FBAR
   use des_elem_axi_q4, only: elem_axi_q4_t, new_axi_q4
   use des_bc, only: bc_set_t, DES_BC_OK
   use des_linsolve, only: skyline_ldlt_t
   use des_assemble, only: element_ref_t, build_pattern, DES_ASM_OK
   use des_newton, only: newton_opts_t, newton_result_t, newton_solve, &
                         DES_NWT_OK
   use test_support, only: t_begin, t_check_le, t_check_true, t_check_int, &
                           t_info, t_finish
   implicit none

   real(dp), parameter :: C10 = 0.6_dp
   real(dp), parameter :: KBULK = 1.0e5_dp
   !> Düzgün genişleme oranı; VER-032 (a) ile aynı.
   real(dp), parameter :: LAM = 1.1_dp
   !> Beklenen gerilme: izokorik katkı sıfır, geriye K*(J-1) kalır.
   real(dp), parameter :: SIG_REF = 33100.0_dp

   !> Yama testinde ayrıklaştırma hatası YOKTUR. Kalan tek kaynak
   !> yuvarlama ve Newton'un yakınsama toleransıdır.
   real(dp), parameter :: TOL_PATCH = 1.0e-12_dp

   integer(ip), parameter :: NNODE = 9_ip
   integer(ip), parameter :: NELEM = 4_ip
   integer(ip), parameter :: NGP = 4_ip

   !> Çarpık yama düğümleri (R, Z). Kenar ortaları bilinçli kaydırılmış.
   real(dp), parameter :: XY(2, NNODE) = reshape([ &
                          1.00_dp, 0.00_dp, &
                          1.40_dp, 0.00_dp, &
                          2.00_dp, 0.00_dp, &
                          1.00_dp, 0.62_dp, &
                          1.57_dp, 0.43_dp, &
                          2.00_dp, 0.38_dp, &
                          1.00_dp, 1.00_dp, &
                          1.66_dp, 1.00_dp, &
                          2.00_dp, 1.00_dp], [2, NNODE])

   !> Saat yönünün tersine düğüm sırası.
   integer(ip), parameter :: CONN(4, NELEM) = reshape([ &
                             1_ip, 2_ip, 5_ip, 4_ip, &
                             2_ip, 3_ip, 6_ip, 5_ip, &
                             4_ip, 5_ip, 8_ip, 7_ip, &
                             5_ip, 6_ip, 9_ip, 8_ip], [4, NELEM])

   !> Sınır düğümleri: 5 dışındaki hepsi.
   integer(ip), parameter :: BND(8) = [1_ip, 2_ip, 3_ip, 4_ip, &
                                       6_ip, 7_ip, 8_ip, 9_ip]

   call t_begin('VER-033  Yama testi  (montaj + sinir kosulu + Newton)')

   call run_patch(DES_FORM_FULL, 'full')
   call run_patch(DES_FORM_FBAR, 'fbar')

   write (*, '(a)') ''
   call t_finish()

contains

   subroutine run_patch(form, tag)
      integer(ip), intent(in) :: form
      character(len=*), intent(in) :: tag

      type(mesh_t) :: msh
      type(sparse_csr_t) :: A
      type(skyline_ldlt_t) :: lin
      type(bc_set_t) :: bc
      type(element_ctx_t) :: ctx
      type(element_config_t) :: cfg
      type(mat_neohookean_t) :: mat
      type(element_ref_t) :: elems(NELEM)
      type(material_state_t) :: sn(NGP, NELEM), snp1(NGP, NELEM)
      type(newton_opts_t) :: opts
      type(newton_result_t) :: res

      real(dp) :: u(2*NNODE), ug(1), resid(2*NNODE)
      real(dp) :: nodes(2, 4), Fg(3, 3), sg(3, 3)
      real(dp) :: err_u, err_s, dmax, ur_ex, uz_ex
      character(len=34) :: label
      !> `ia`: tek harfli `a`, ayni kapsamdaki A seyrek matrisini
      !> maskelerdi (Fortran harf duyarsizdir).
      integer(ip) :: st, ie, ia, gp, k, idof
      logical :: ok

      mat = new_neohookean(C10, KBULK)

      ! --- Ag -------------------------------------------------------------
      call msh%init(NNODE, NELEM, 4_ip, 2_ip, st)
      call t_check_int(tag//' : mesh init', st, DES_MESH_OK)
      msh%coord = XY
      msh%conn = CONN
      msh%n_node_of = 4_ip
      call msh%build_dof_map(st)
      call t_check_int(tag//' : DOF haritasi', st, DES_MESH_OK)
      call t_check_int(tag//' : n_dof = 18', msh%n_dof, 18_ip)

      ! --- Elemanlar ------------------------------------------------------
      cfg%analysis = DES_ANA_AXISYM
      cfg%formulation = form
      cfg%n_gauss = NGP

      do ie = 1_ip, NELEM
         allocate (elem_axi_q4_t :: elems(ie)%e)
         do ia = 1_ip, 4_ip
            nodes(:, ia) = XY(:, CONN(ia, ie))
         end do
         select type (p => elems(ie)%e)
         type is (elem_axi_q4_t)
            p = new_axi_q4(ie)
            call p%setup(nodes, cfg, mat, st)
         end select
         if (st /= DES_ELEM_OK) then
            write (*, '(a,i0,a,i0)') '   eleman ', ie, ' setup basarisiz: ', st
            error stop 2
         end if
      end do
      call t_check_int(tag//' : eleman kurulumu', st, DES_ELEM_OK)

      ! --- Seyrek desen: BIR KEZ -----------------------------------------
      call build_pattern(msh, elems, A, .true., st)
      call t_check_int(tag//' : seyrek desen', st, DES_ASM_OK)

      ! --- Sinir kosullari: dis dugumlere tam cozum dayatiliyor -----------
      call bc%init(20_ip, 1_ip, 1_ip, st)
      do k = 1_ip, int(size(BND), ip)
         ur_ex = (LAM - 1.0_dp)*XY(1, BND(k))
         uz_ex = (LAM - 1.0_dp)*XY(2, BND(k))
         call bc%add_dirichlet(BND(k), 1_ip, ur_ex, 0_ip, st)
         call bc%add_dirichlet(BND(k), 2_ip, uz_ex, 0_ip, st)
      end do
      call bc%build(msh, st)
      call t_check_int(tag//' : sinir kosulu', st, DES_BC_OK)
      call t_check_int(tag//' : dayatilmis DOF = 16', &
                       count(bc%fixed), 16_ip)

      ! --- Durum ----------------------------------------------------------
      do ie = 1_ip, NELEM
         do gp = 1_ip, NGP
            call sn(gp, ie)%init(0_ip)
            call snp1(gp, ie)%init(0_ip)
         end do
      end do

      ! --- Coz -------------------------------------------------------------
      u = 0.0_dp
      ug = 0.0_dp
      opts%n_step = 4_ip
      opts%max_iter = 40_ip
      !> Yama testi toleransi 1e-12'dir ve DEGISMEZ. Newton'un durma
      !> olcutu ondan BELIRGIN OLCUDE siki olmali, yoksa olculen sapma
      !> elemanin degil cozucunun erken durmasinin sonucu olur.
      !> Artik olcegi ~4e4; tol_rel = 1e-14 mutlak ~4e-10 demektir ve
      !> yer degistirme hatasina ~1e-14 olarak yansir.
      opts%tol_rel = 1.0e-14_dp
      opts%tol_abs = 1.0e-11_dp

      call newton_solve(msh, elems, bc, lin, A, ctx, sn, snp1, u, ug, &
                        resid, opts, res)

      call t_check_int(tag//' : Newton yakinsadi', res%stat, DES_NWT_OK)
      write (*, '(a,a,a,i0,a,i0,a,i0,a,es11.4)') &
         '   ', tag, ' : adim ', res%n_step, '  yineleme ', res%n_iter, &
         '  geri adim ', res%n_cutback, '  son artik ', res%resid_final
      call t_check_le(tag//' : t_final = 1', abs(res%t_final - 1.0_dp), 1.0e-14_dp)

      ! --- 1) IC DUGUM tam yerine gitti mi --------------------------------
      ur_ex = (LAM - 1.0_dp)*XY(1, 5_ip)
      uz_ex = (LAM - 1.0_dp)*XY(2, 5_ip)
      idof = msh%node_dof(5_ip, 1_ip)
      err_u = abs(u(idof) - ur_ex)/abs(ur_ex)
      idof = msh%node_dof(5_ip, 2_ip)
      err_u = max(err_u, abs(u(idof) - uz_ex)/abs(uz_ex))

      write (*, '(a,2(2x,f18.12))') '   ic dugum u_r, u_z beklenen = ', &
         ur_ex, uz_ex
      idof = msh%node_dof(5_ip, 1_ip)
      write (*, '(a,2(2x,f18.12))') '   ic dugum u_r, u_z hesap    = ', &
         u(idof), u(msh%node_dof(5_ip, 2_ip))

      label = tag//' : ic dugum bagil hata'
      call t_check_le(label, err_u, TOL_PATCH)

      ! --- 2) HER Gauss noktasinda ayni gerilme ---------------------------
      err_s = 0.0_dp
      dmax = 0.0_dp
      do ie = 1_ip, NELEM
         select type (p => elems(ie)%e)
         type is (elem_axi_q4_t)
            do ia = 1_ip, 4_ip
               nodes(:, ia) = XY(:, CONN(ia, ie))
            end do
            do gp = 1_ip, NGP
               call gauss_from_global(msh, p, ie, u, gp, Fg, sg, ok)
               if (.not. ok) then
                  write (*, '(a)') '   gauss_state basarisiz'
                  error stop 3
               end if
               err_s = max(err_s, abs(sg(1, 1) - SIG_REF)/SIG_REF)
               err_s = max(err_s, abs(sg(2, 2) - SIG_REF)/SIG_REF)
               err_s = max(err_s, abs(sg(3, 3) - SIG_REF)/SIG_REF)
               dmax = max(dmax, abs(Fg(1, 1) - LAM))
               dmax = max(dmax, abs(Fg(2, 2) - LAM))
               dmax = max(dmax, abs(Fg(3, 3) - LAM))
            end do
         end select
      end do

      write (*, '(a,es12.5,a,es12.5)') &
         '   16 Gauss noktasi: max|dF| = ', dmax, '   max sigma bagil = ', err_s
      label = tag//' : 16 Gauss noktasi F sabit'
      call t_check_le(label, dmax, TOL_PATCH)
      label = tag//' : 16 Gauss noktasi sigma = 33100'
      call t_check_le(label, err_s, TOL_PATCH)

      call lin%free()
      call A%free()
   end subroutine run_patch

   !> Global u vektöründen bir elemanın Gauss noktası durumunu okur.
   subroutine gauss_from_global(msh, el, ie, u, gp, Fg, sg, ok)
      type(mesh_t), intent(in) :: msh
      type(elem_axi_q4_t), intent(inout) :: el
      integer(ip), intent(in) :: ie, gp
      real(dp), intent(in) :: u(:)
      real(dp), intent(out) :: Fg(3, 3), sg(3, 3)
      logical, intent(out) :: ok

      real(dp) :: ue(2, 4)
      integer(ip) :: a, i, idof, st

      ok = .false.
      do a = 1_ip, 4_ip
         do i = 1_ip, 2_ip
            idof = msh%node_dof(msh%conn(a, ie), i)
            if (idof < 1_ip) return
            ue(i, a) = u(idof)
         end do
      end do

      call el%gauss_state(ue, gp, Fg, sg, st)
      ok = (st == DES_ELEM_OK)
   end subroutine gauss_from_global

end program check_patch
