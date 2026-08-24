!> ---------------------------------------------------------------------------
!> check_stability -- VER-031: mod bazlı kararlılık ölçütü doğrulaması
!>
!> ÖLÇÜT
!>
!> Üç deformasyon modunda nominal (1. Piola-Kirchhoff) gerilmenin uzama
!> oranına göre türevi pozitif olmalıdır: dP/dlambda > 0.
!>
!>   1. Tek eksenli      : F = diag(lam, x, x),   x -> sigma22 = 0
!>   2. Eşit iki eksenli : F = diag(lam, lam, x), x -> sigma33 = 0
!>   3. Düzlemsel        : F = diag(lam, 1, x),   x -> sigma33 = 0
!>
!> Bu, ANSYS ve Abaqus'ün hiperelastik kalibrasyonda kullandığı ölçüttür.
!> Tam tanjant pozitif tanımlılığı (Drucker) DEĞİLDİR; sağlıklı bir
!> Neo-Hookean onu sağlamaz. Gerekçe ve karşı örnek: ADR 0007.
!>
!> ÇAPRAZ DOĞRULAMA
!>
!> lambda = 1.0'daki dP/dlambda doğrudan elastisite modülü E'dir. Bu test
!> onu VER-001'in bağımsız olarak ölçtüğü 9*K*mu/(3*K+mu) değerine karşı
!> denetler; böylece kararlılık kontrolü ile tek eksenli doğrulama
!> birbirine bağlanmış olur. İkisinden biri bozulursa ikisi birden kırmızıya
!> döner.
!> ---------------------------------------------------------------------------
program check_stability
   use des_kinds, only: dp, ip
   use des_material, only: mat_point_t, material_state_t, &
                           stability_range_t, stability_result_t, &
                           DES_STAB_OK, DES_STAB_UNSTABLE, &
                           DES_MODE_UNIAXIAL, DES_MODE_EQUIBIAXIAL, &
                           DES_MODE_PLANAR
   use des_mat_neohookean, only: mat_neohookean_t, new_neohookean
   use test_support, only: t_begin, t_check_le, t_check_true, t_check_int, &
                           t_info, t_finish
   implicit none

   real(dp), parameter :: C10 = 0.6_dp
   real(dp), parameter :: KBULK = 1.0e5_dp

   !> Merkezi fark adımı; des_material içindeki değerle aynı.
   real(dp), parameter :: H_STEP = 1.0e-4_dp

   !> Doğrulama noktaları ve BAĞIMSIZ referans değerleri.
   real(dp), parameter :: LAM(7) = &
      [0.50_dp, 0.70_dp, 1.00_dp, 1.50_dp, 2.00_dp, 3.00_dp, 4.00_dp]

   real(dp), parameter :: P_REF(7) = &
      [-4.19999_dp, -1.60897_dp, 0.00000_dp, &
       1.26666_dp, 2.09998_dp, 3.46658_dp, 4.72480_dp]

   real(dp), parameter :: DP_REF(7) = &
      [20.39992_dp, 8.19706_dp, 3.59999_dp, &
       1.91109_dp, 1.49996_dp, 1.28880_dp, 1.23735_dp]

   !> C10 = -0.6 için aynı noktalardan üçü.
   real(dp), parameter :: LAM_BAD(3) = [1.00_dp, 1.50_dp, 2.00_dp]
   real(dp), parameter :: DP_BAD(3) = [-3.60001_dp, -1.91113_dp, -1.50004_dp]

   !> Referans değerler beş ondalık haneye yuvarlanmış olarak verilmiştir;
   !> yalnızca bu yuvarlama bile +-5e-6 belirsizlik taşır. Tolerans bunun
   !> dört katıdır. Bu bir SAYISAL hata payı değil, referansın gösterim
   !> hassasiyetidir; ölçülen sapmalar 4.3e-06 mertebesindedir.
   real(dp), parameter :: TOL_REF = 2.0e-5_dp

   !> E çapraz doğrulaması: burada referans yuvarlama taşımıyor, analitik.
   real(dp), parameter :: TOL_E = 1.0e-6_dp

   type(mat_neohookean_t)   :: mat, mat_bad
   type(mat_point_t)        :: pt
   type(material_state_t)   :: sn, snp1
   type(stability_range_t)  :: rng
   type(stability_result_t) :: res

   real(dp) :: p_nom, lat, slope, e_comp, mu
   character(len=34) :: label
   integer(ip) :: i
   logical :: ok

   call t_begin('VER-031  Mod bazli kararlilik  (dP/dlambda > 0)')

   mat = new_neohookean(C10, KBULK)
   mat_bad = new_neohookean(-C10, KBULK)
   call sn%init(0_ip)
   call snp1%init(0_ip)

   mu = 2.0_dp*C10
   e_comp = 9.0_dp*KBULK*mu/(3.0_dp*KBULK + mu)

   write (*, '(a,f6.3,a,es9.2,a,f6.3,a,es9.2)') &
      ' C10 = ', C10, '   K = ', KBULK, '   mu_ref = ', mat%mu_ref, &
      '   kappa_ref = ', mat%kappa_ref

   ! =========================================================================
   ! 1 -- Tek eksenli referans tablosu
   ! =========================================================================
   call t_info('')
   call t_info(' 1. Tek eksenli referans tablosu  (C10 = +0.6)')
   write (*, '(a)') '   lambda   lam_yanal      P (nominal)    P (ref)      dP/dlam      dP/dlam (ref)'
   write (*, '(a)') '   ---------------------------------------------------------------------------'

   do i = 1, size(LAM)
      call mat%mode_nominal(DES_MODE_UNIAXIAL, LAM(i), pt, sn, snp1, &
                            p_nom, lat, ok)
      if (.not. ok) then
         write (*, '(a,f6.3)') '   yanal uzama cozulemedi, lambda = ', LAM(i)
         error stop 2
      end if

      call slope_of(mat, DES_MODE_UNIAXIAL, LAM(i), slope, ok)
      if (.not. ok) then
         write (*, '(a,f6.3)') '   egim hesaplanamadi, lambda = ', LAM(i)
         error stop 3
      end if

      write (*, '(a,f7.3,3x,f10.7,3x,f13.6,2x,f11.5,3x,f12.6,3x,f10.5)') &
         '  ', LAM(i), lat, p_nom, P_REF(i), slope, DP_REF(i)
   end do

   write (*, '(a)') ''
   do i = 1, size(LAM)
      call mat%mode_nominal(DES_MODE_UNIAXIAL, LAM(i), pt, sn, snp1, &
                            p_nom, lat, ok)
      write (label, '(a,f5.2,a)') 'lam=', LAM(i), ' : P mutlak fark'
      call t_check_le(label, abs(p_nom - P_REF(i)), TOL_REF)
   end do

   write (*, '(a)') ''
   do i = 1, size(LAM)
      call slope_of(mat, DES_MODE_UNIAXIAL, LAM(i), slope, ok)
      write (label, '(a,f5.2,a)') 'lam=', LAM(i), ' : dP/dlam fark'
      call t_check_le(label, abs(slope - DP_REF(i)), TOL_REF)
      call t_check_true('  ... ve pozitif', slope > 0.0_dp)
   end do

   ! =========================================================================
   ! 2 -- VER-001 ile capraz dogrulama
   ! =========================================================================
   call t_info('')
   call t_info(' 2. Capraz dogrulama: lambda = 1 de dP/dlambda = E')

   call slope_of(mat, DES_MODE_UNIAXIAL, 1.0_dp, slope, ok)
   write (*, '(a,f12.6)') '   dP/dlambda (lambda = 1)      = ', slope
   write (*, '(a,f12.6)') '   E = 9*K*mu/(3*K+mu)          = ', e_comp
   write (*, '(a,f12.6)') '   6*C10 (sikistirilamaz sinir) = ', 6.0_dp*C10
   call t_check_le('dP/dlam(1) vs E bagil hata', &
                   abs(slope - e_comp)/e_comp, TOL_E)

   ! =========================================================================
   ! 3 -- C10 < 0: kararsiz olarak siniflandirilmali
   ! =========================================================================
   call t_info('')
   call t_info(' 3. C10 = -0.6  (fiziksel olmayan malzeme)')

   do i = 1, size(LAM_BAD)
      call slope_of(mat_bad, DES_MODE_UNIAXIAL, LAM_BAD(i), slope, ok)
      if (.not. ok) then
         write (*, '(a,f6.3)') '   egim hesaplanamadi, lambda = ', LAM_BAD(i)
         error stop 4
      end if
      write (*, '(a,f6.3,a,f12.6,a,f10.5)') &
         '   lambda = ', LAM_BAD(i), '   dP/dlam = ', slope, &
         '   ref = ', DP_BAD(i)

      write (label, '(a,f5.2,a)') 'lam=', LAM_BAD(i), ' : dP/dlam fark'
      call t_check_le(label, abs(slope - DP_BAD(i)), TOL_REF)
      call t_check_true('  ... ve negatif', slope < 0.0_dp)
   end do

   ! =========================================================================
   ! 4 -- Uc modun tamaminda siniflandirma
   ! =========================================================================
   call t_info('')
   call t_info(' 4. Uc mod, lambda = 0.5 ... 4.0 taramasi')

   call mat%check_stability(pt, sn, snp1, rng, res)
   call t_check_int('C10 > 0 : DES_STAB_OK', res%stat, DES_STAB_OK)
   call t_check_int('C10 > 0 : kararsiz mod yok', res%first_mode, 0_ip)
   call t_check_int('C10 > 0 : hacimsel OK', res%vol_stat, DES_STAB_OK)
   call t_check_true('C10 > 0 : tek eksenli min egim > 0', &
                     res%mode_min_slope(DES_MODE_UNIAXIAL) > 0.0_dp)
   call t_check_true('C10 > 0 : iki eksenli min egim > 0', &
                     res%mode_min_slope(DES_MODE_EQUIBIAXIAL) > 0.0_dp)
   call t_check_true('C10 > 0 : duzlemsel min egim > 0', &
                     res%mode_min_slope(DES_MODE_PLANAR) > 0.0_dp)

   write (*, '(a)') '   mod bazinda en kucuk dP/dlambda:'
   write (*, '(a,es13.6)') '     tek eksenli      : ', &
      res%mode_min_slope(DES_MODE_UNIAXIAL)
   write (*, '(a,es13.6)') '     esit iki eksenli : ', &
      res%mode_min_slope(DES_MODE_EQUIBIAXIAL)
   write (*, '(a,es13.6)') '     duzlemsel        : ', &
      res%mode_min_slope(DES_MODE_PLANAR)
   write (*, '(a,es13.6,a,es13.6)') '   toplu min = ', res%min_slope, &
      '   mu_ref ile normalize = ', res%min_slope_n

   call mat_bad%check_stability(pt, sn, snp1, rng, res)
   call t_check_int('C10 < 0 : DES_STAB_UNSTABLE', res%stat, DES_STAB_UNSTABLE)
   call t_check_true('C10 < 0 : uc mod da kararsiz', &
                     all(res%mode_stat == DES_STAB_UNSTABLE))
   write (*, '(a,i0,a,f6.3,a,es13.6)') &
      '   ilk kararsizlik: mod ', res%first_mode, '  lambda = ', &
      res%first_lambda, '   min egim = ', res%min_slope

   write (*, '(a)') ''
   call t_finish()

contains

   !> Nominal gerilmenin uzamaya göre türevi, merkezi farkla.
   !>
   !> Yanal uzama her adımda yeniden çözülür; sabit tutulursa türev
   !> tek eksenli GERİLME durumunun değil, dayatılmış bir kinematiğin
   !> türevi olur.
   !> `lam_at` adi bilinçli: tek harfli `lam`, host kapsamindaki LAM(7)
   !> parametre dizisini maskelerdi (bkz. AGENTS.md, host maskeleme kurali).
   subroutine slope_of(m, mode, lam_at, slope_out, ok_out)
      type(mat_neohookean_t), intent(in) :: m
      integer(ip), intent(in) :: mode
      real(dp), intent(in) :: lam_at
      real(dp), intent(out) :: slope_out
      logical, intent(out) :: ok_out

      real(dp) :: p_plus, p_minus, lat_local

      slope_out = 0.0_dp

      call m%mode_nominal(mode, lam_at + H_STEP, pt, sn, snp1, &
                          p_plus, lat_local, ok_out)
      if (.not. ok_out) return

      call m%mode_nominal(mode, lam_at - H_STEP, pt, sn, snp1, &
                          p_minus, lat_local, ok_out)
      if (.not. ok_out) return

      slope_out = (p_plus - p_minus)/(2.0_dp*H_STEP)
   end subroutine slope_of

end program check_stability
