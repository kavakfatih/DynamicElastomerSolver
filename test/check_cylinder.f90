!> ---------------------------------------------------------------------------
!> check_cylinder -- VER-034: kalın cidarlı silindir, iç basınç
!>
!> Programın gerçek bir mühendislik problemini analitik çözümle uyumlu
!> çözdüğünün ilk kanıtı. v0.1'in çıkış kapısı.
!>
!> GEOMETRİ VE YÜKLEME
!>
!>   iç yarıçap A = 1, dış yarıçap B = 2
!>   C10 = 0.6, K = 1e5  (K/C10 = 1.67e5, neredeyse sıkıştırılamaz)
!>   iki uçta u_z = 0  ->  düzlem şekil değiştirme, lambda_z = 1
!>
!> NEDEN YER DEĞİŞTİRME KONTROLÜ, YÜK KONTROLÜ DEĞİL
!>
!> Bu problemde iç basınç, şişme arttıkça bir üst değere DOYAR (~0.83).
!> Yük kontrollü bir çözüm doyma bölgesinde kötü koşullanır ve v0.1'de
!> yay uzunluğu (arc-length) yöntemi yoktur. u_r(A) dayatılıp basınç
!> REAKSİYONDAN okunduğunda bu sorun tamamen ortadan kalkar.
!>
!> BASINCIN REAKSİYONDAN OKUNMASI
!>
!> `des_bc` elemeyi MATRİSE uygular, ARTIĞA değil; yakınsamış durumda
!> dayatılmış serbestlikteki artık doğrudan mesnet tepkisidir.
!>
!> İç yüzeye P basıncı uygulansaydı eşdeğer düğüm kuvveti (radyan başına)
!> P * a * L olurdu; a DEFORME iç yarıçap, L eksenel boy. Dengede
!> f_int = f_ext olduğundan:
!>
!>     P = (iç düğümlerdeki toplam radyal artık) / (a * L)
!>
!> ÖLÇEK: radyan başına (des_bc konvansiyonu). Spesifikasyondaki
!> P = R / (2*pi*a*L) formülü tam çevre ölçeğine aittir; 2*pi hem
!> reaksiyonda hem alanda bulunduğu için P AYNI çıkar.
!>
!> u_r(B) NEDEN AYRICA ÖNEMLİ
!>
!> Dış yarıçapın yer değiştirmesi sıkıştırılamazlığın doğrudan sonucudur
!> (b^2 - a^2 = B^2 - A^2) ve HİÇ GERİLME İÇERMEZ. Eleman kilitlenirse
!> u_r(B) de yanlış çıkar. Bu yüzden basınçtan AYRI kontrol edilir.
!> ---------------------------------------------------------------------------
program check_cylinder
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
   real(dp), parameter :: RA = 1.0_dp
   real(dp), parameter :: RB = 2.0_dp
   real(dp), parameter :: ZL = 1.0_dp

   !> Dayatılan iç yarıçap yer değiştirmeleri ve BAĞIMSIZ analitik referans
   !> (sıkıştırılamaz neo-Hookean, düzlem şekil değiştirme).
   integer(ip), parameter :: NCASE = 3_ip
   real(dp), parameter :: UA(NCASE) = [0.100000_dp, 0.250000_dp, 0.500000_dp]
   real(dp), parameter :: P_REF(NCASE) = [0.157874734_dp, 0.330853844_dp, &
                                          0.513874091_dp]
   real(dp), parameter :: UB_REF(NCASE) = [0.051828453_dp, 0.136000936_dp, &
                                           0.291287847_dp]

   !> TOLERANSLAR -- İKİ AYRI BÜYÜKLÜK, İKİ AYRI GEREKÇE
   !>
   !> Spesifikasyon 1e-3 ile başlamayı ve ölçülen çok daha iyiyse
   !> daraltmayı istiyordu. Ölçüldü ve daraltıldı; gerekçeler:
   !>
   !> BASINÇ -- 5e-4 bağıl.
   !>   Baskın pay AYRIKLAŞTIRMAdır. Q4 ikinci mertebe yakınsar ve bu
   !>   testte ölçülen mertebe 2.006 / 2.035'tir; radyal 16 elemanda hata
   !>   1.19e-04 ... 1.98e-04 çıkıyor. Tolerans bunun ~2.5 katı: platform
   !>   yuvarlamasına pay bırakır ama bir mertebe kaybını yakalar.
   !>   Sıkıştırılabilirlik payı da vardır (K sonlu) ama burada
   !>   ayrıklaştırmanın altında kalır.
   !>
   !> DIŞ YARIÇAP -- 5e-5 bağıl.
   !>   u_r(B) sıkıştırılamazlığın doğrudan sonucudur (b^2-a^2 = B^2-A^2)
   !>   ve HİÇ GERİLME İÇERMEZ; ayrıklaştırma hatası bu büyüklüğe neredeyse
   !>   hiç girmez. Ölçülen 7.65e-06 ... 8.71e-06, yani tam olarak sonlu
   !>   sıkıştırılabilirlik tabanında (mu/K = 1.2e-05). Tolerans bunun ~6
   !>   katı.
   !>
   !> Yama testinden (VER-033, 1e-12) farkı: orada ayrıklaştırma hatası
   !> YOKTU, burada VAR.
   real(dp), parameter :: TOL_P = 5.0e-4_dp
   real(dp), parameter :: TOL_UB = 5.0e-5_dp

   call t_begin('VER-034  Kalin cidarli silindir  (v0.1 kapisi)')

   call run_cases()
   call locking_study()
   call mesh_convergence()

   write (*, '(a)') ''
   call t_finish()

contains

   !> Eksenel simetrik dikdörtgen ağ: radyal yönde nr eleman, eksenel
   !> yönde bir eleman.
   !>
   !> İki uçta da u_z = 0 dayatıldığı için bu tam olarak düzlem şekil
   !> değiştirmedir (lambda_z = 1); eksenel yönde tek eleman yeter.
   subroutine build_mesh(nr, msh, stat)
      integer(ip), intent(in) :: nr
      type(mesh_t), intent(inout) :: msh
      integer(ip), intent(out) :: stat

      integer(ip) :: i, nn
      real(dp) :: dr

      nn = 2_ip*(nr + 1_ip)
      call msh%init(nn, nr, 4_ip, 2_ip, stat)
      if (stat /= DES_MESH_OK) return

      dr = (RB - RA)/real(nr, dp)
      do i = 1_ip, nr + 1_ip
         msh%coord(1, i) = RA + real(i - 1_ip, dp)*dr
         msh%coord(2, i) = 0.0_dp
         msh%coord(1, i + nr + 1_ip) = RA + real(i - 1_ip, dp)*dr
         msh%coord(2, i + nr + 1_ip) = ZL
      end do

      !> Saat yönünün tersine: (r_i,0) (r_i+1,0) (r_i+1,L) (r_i,L)
      do i = 1_ip, nr
         msh%conn(1, i) = i
         msh%conn(2, i) = i + 1_ip
         msh%conn(3, i) = i + 1_ip + nr + 1_ip
         msh%conn(4, i) = i + nr + 1_ip
      end do
      msh%n_node_of = 4_ip

      call msh%build_dof_map(stat)
   end subroutine build_mesh

   !> Bir vakayı çöz; basıncı ve dış yarıçap yer değiştirmesini döndür.
   subroutine solve_case(nr, form, ua_target, p_out, ub_out, res, ok)
      integer(ip), intent(in) :: nr, form
      real(dp), intent(in) :: ua_target
      real(dp), intent(out) :: p_out, ub_out
      type(newton_result_t), intent(out) :: res
      logical, intent(out) :: ok

      type(mesh_t) :: msh
      type(sparse_csr_t) :: A
      type(skyline_ldlt_t) :: lin
      type(bc_set_t) :: bc
      type(element_ctx_t) :: ctx
      type(element_config_t) :: cfg
      type(mat_neohookean_t) :: mat
      type(element_ref_t), allocatable :: elems(:)
      type(material_state_t), allocatable :: sn(:, :), snp1(:, :)
      type(newton_opts_t) :: opts

      real(dp), allocatable :: u(:), resid(:)
      real(dp) :: ug(1), nodes(2, 4), rtot, a_def
      integer(ip) :: st, ie, ia, gp, nn, inner(2), i

      ok = .false.
      p_out = 0.0_dp
      ub_out = 0.0_dp

      mat = new_neohookean(C10, KBULK)
      call build_mesh(nr, msh, st)
      if (st /= DES_MESH_OK) return

      nn = msh%n_node()
      allocate (elems(nr), sn(4_ip, nr), snp1(4_ip, nr))
      allocate (u(msh%n_dof), resid(msh%n_dof))

      cfg%analysis = DES_ANA_AXISYM
      cfg%formulation = form
      cfg%n_gauss = 4_ip

      do ie = 1_ip, nr
         allocate (elem_axi_q4_t :: elems(ie)%e)
         do ia = 1_ip, 4_ip
            nodes(:, ia) = msh%coord(:, msh%conn(ia, ie))
         end do
         select type (p => elems(ie)%e)
         type is (elem_axi_q4_t)
            p = new_axi_q4(ie)
            call p%setup(nodes, cfg, mat, st)
         end select
         if (st /= DES_ELEM_OK) return
         do gp = 1_ip, 4_ip
            call sn(gp, ie)%init(0_ip)
            call snp1(gp, ie)%init(0_ip)
         end do
      end do

      call build_pattern(msh, elems, A, .true., st)
      if (st /= DES_ASM_OK) return

      !> Sinir kosullari:
      !>   butun dugumlerde u_z = 0   (duzlem sekil degistirme)
      !>   ic yarıçapta u_r dayatilmis
      call bc%init(2_ip*nn + 4_ip, 1_ip, 1_ip, st)
      do i = 1_ip, nn
         call bc%add_dirichlet(i, 2_ip, 0.0_dp, 0_ip, st)
      end do
      inner = [1_ip, nr + 2_ip]
      call bc%add_dirichlet(inner(1), 1_ip, ua_target, 0_ip, st)
      call bc%add_dirichlet(inner(2), 1_ip, ua_target, 0_ip, st)
      call bc%build(msh, st)
      if (st /= DES_BC_OK) return

      u = 0.0_dp
      ug = 0.0_dp
      opts%n_step = 8_ip
      opts%max_iter = 40_ip
      opts%tol_rel = 1.0e-12_dp
      opts%tol_abs = 1.0e-12_dp

      call newton_solve(msh, elems, bc, lin, A, ctx, sn, snp1, u, ug, &
                        resid, opts, res)
      if (res%stat /= DES_NWT_OK) return

      !> Basinc: ic dugumlerdeki toplam radyal artik / (a * L)
      call bc%reaction_sum(msh, inner, 1_ip, resid, rtot, st)
      if (st /= DES_BC_OK) return
      a_def = RA + ua_target
      p_out = rtot/(a_def*ZL)

      !> Dis yariçap yer degistirmesi.
      ub_out = u(msh%node_dof(nr + 1_ip, 1_ip))

      call lin%free()
      call A%free()
      ok = .true.
   end subroutine solve_case

   !> Üç referans vakası, F-bar ile.
   subroutine run_cases()
      real(dp) :: p_out, ub_out, ep, eb
      type(newton_result_t) :: res
      character(len=34) :: label
      integer(ip) :: k
      logical :: ok

      call t_info('')
      call t_info(' 1. Uc referans vakasi  (fbar, radyal 16 eleman)')
      write (*, '(a)') '   u_r(A)    P (hesap)      P (ref)      bagil  ' // &
         '   u_r(B) hesap   u_r(B) ref     bagil'
      write (*, '(a)') '   -------------------------------------------' // &
         '-----------------------------------------------'

      do k = 1_ip, NCASE
         call solve_case(16_ip, DES_FORM_FBAR, UA(k), p_out, ub_out, res, ok)
         if (.not. ok) then
            write (*, '(a,f6.3,a,i0)') '   cozulemedi, u_r(A) = ', UA(k), &
               '  newton stat = ', res%stat
            error stop 2
         end if

         ep = abs(p_out - P_REF(k))/P_REF(k)
         eb = abs(ub_out - UB_REF(k))/UB_REF(k)

         write (*, '(a,f6.3,2x,f13.9,2x,f12.9,2x,es10.3,2x,f13.9,2x,f12.9,2x,es10.3)') &
            '  ', UA(k), p_out, P_REF(k), ep, ub_out, UB_REF(k), eb

         write (label, '(a,f5.3,a)') 'u_r(A)=', UA(k), ' : P bagil hata'
         call t_check_le(label, ep, TOL_P)
         write (label, '(a,f5.3,a)') 'u_r(A)=', UA(k), ' : u_r(B) hata'
         call t_check_le(label, eb, TOL_UB)
      end do
   end subroutine run_cases

   !> D2 -- KİLİTLENME ÇALIŞMASI.
   !>
   !> Aynı ağda iki formülasyon. K/C10 = 1.67e5'te tam integrasyonun
   !> hacimsel kilitlenmesi bekleniyor: çözüm aşırı rijit çıkar ve
   !> basınç analitikten BÜYÜK olur.
   !>
   !> FULL için TOLERANS KONMAZ -- kilitlenmesi beklenen davranıştır.
   !> Testin geçme koşulu FBAR üzerindendir. Bu, ADR-0009 (c)'deki
   !> "formülasyon çalışma zamanı seçimidir" kararının doğrulanmasıdır.
   subroutine locking_study()
      real(dp) :: p_full, ub_full, p_fbar, ub_fbar, e_full, e_fbar
      type(newton_result_t) :: r1, r2
      integer(ip) :: k
      logical :: ok

      call t_info('')
      call t_info(' 2. KILITLENME CALISMASI  -- ayni agda full vs fbar')
      call t_info('    (full icin tolerans YOK; kilitlenmesi beklenen davranis)')
      write (*, '(a)') '   u_r(A)    P full        bagil hata    P fbar    ' // &
         '    bagil hata    full/fbar'
      write (*, '(a)') '   --------------------------------------------' // &
         '---------------------------------'

      do k = 1_ip, NCASE
         call solve_case(16_ip, DES_FORM_FULL, UA(k), p_full, ub_full, r1, ok)
         if (.not. ok) then
            write (*, '(a,f6.3)') '   full cozulemedi, u_r(A) = ', UA(k)
            cycle
         end if
         call solve_case(16_ip, DES_FORM_FBAR, UA(k), p_fbar, ub_fbar, r2, ok)
         if (.not. ok) cycle

         e_full = abs(p_full - P_REF(k))/P_REF(k)
         e_fbar = abs(p_fbar - P_REF(k))/P_REF(k)

         write (*, '(a,f6.3,2x,f13.9,2x,es11.4,2x,f13.9,2x,es11.4,2x,f9.4)') &
            '  ', UA(k), p_full, e_full, p_fbar, e_fbar, p_full/p_fbar
      end do

      !> Tek IDDIA: fbar full'den belirgin olcude iyi olmali.
      call solve_case(16_ip, DES_FORM_FULL, UA(3_ip), p_full, ub_full, r1, ok)
      call solve_case(16_ip, DES_FORM_FBAR, UA(3_ip), p_fbar, ub_fbar, r2, ok)
      e_full = abs(p_full - P_REF(3_ip))/P_REF(3_ip)
      e_fbar = abs(p_fbar - P_REF(3_ip))/P_REF(3_ip)
      call t_check_true('fbar, full''den daha dogru', e_fbar < e_full)
   end subroutine locking_study

   !> D3 -- AĞ YAKINSAMASI. Radyal 4, 8, 16 eleman; mertebe O(h^2)'ye
   !> yakın olmalı.
   subroutine mesh_convergence()
      integer(ip), parameter :: NR(3) = [4_ip, 8_ip, 16_ip]
      real(dp) :: p_out, ub_out, err(3), rate1, rate2
      type(newton_result_t) :: res
      integer(ip) :: k
      logical :: ok

      call t_info('')
      call t_info(' 3. AG YAKINSAMASI  (fbar, u_r(A) = 0.25)')
      write (*, '(a)') '   radyal eleman    P (hesap)       bagil hata'
      write (*, '(a)') '   ------------------------------------------'

      do k = 1_ip, 3_ip
         call solve_case(NR(k), DES_FORM_FBAR, UA(2_ip), p_out, ub_out, res, ok)
         if (.not. ok) then
            write (*, '(a,i0)') '   cozulemedi, nr = ', NR(k)
            error stop 3
         end if
         err(k) = abs(p_out - P_REF(2_ip))/P_REF(2_ip)
         write (*, '(a,i8,7x,f13.9,3x,es11.4)') '  ', NR(k), p_out, err(k)
      end do

      rate1 = 0.0_dp
      rate2 = 0.0_dp
      if (err(2) > 0.0_dp) rate1 = log(err(1)/err(2))/log(2.0_dp)
      if (err(3) > 0.0_dp) rate2 = log(err(2)/err(3))/log(2.0_dp)
      write (*, '(a,f8.3,a,f8.3)') '   olculen mertebe: 4->8 = ', rate1, &
         '   8->16 = ', rate2

      call t_check_true('hata ag inceltmeyle azaliyor', &
                        err(3) < err(2) .and. err(2) < err(1))
   end subroutine mesh_convergence

end program check_cylinder
