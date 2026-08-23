!> ---------------------------------------------------------------------------
!> check_contract -- dondurulmuş malzeme sözleşmesinin davranış testleri
!>
!> Bu test SAYI doğrulamaz, SÖZLEŞME doğrular. Gerilme formülü doğru olsa
!> bile bu dört davranıştan biri bozulursa çözücü sessizce yanlış çalışır:
!>
!>   1. serialise / restore gidiş-dönüşü  (geri adım, restart, remesh)
!>   2. set_bounds + project              (remesh sonrası hasar kırpma)
!>   3. det C <= 0 -> DES_MAT_NONPHYSICAL ve dt_factor < 1
!>   4. Drucker kararlılığı: C10 > 0 kararlı, C10 < 0 KARARSIZ
!>
!> 4. maddenin önemi: kararlılık kontrolü temel sınıfta bir kez yazılmıştır
!> ve yalnızca eval'e dayanır. Burada kırılırsa, ileride eklenecek HER
!> malzeme sessizce kararlılık kontrolünü kaybeder.
!> ---------------------------------------------------------------------------
program check_contract
   use des_kinds, only: dp, ip
   use des_tensor, only: cc_to_mandel, cholesky_margin
   use des_material, only: mat_point_t, material_state_t, &
                           stability_range_t, stability_result_t, &
                           DES_MAT_OK, DES_MAT_NONPHYSICAL, &
                           DES_STAB_OK, DES_STAB_UNSTABLE, DES_STAB_UNKNOWN, &
                           DES_MODE_UNIAXIAL, DES_MODE_EQUIBIAXIAL, &
                           DES_MODE_PLANAR
   use des_mat_neohookean, only: mat_neohookean_t, new_neohookean
   use test_support, only: t_begin, t_check_le, t_check_true, t_check_int, &
                           t_info, t_finish
   implicit none

   real(dp), parameter :: C10 = 0.6_dp
   real(dp), parameter :: KBULK = 1.0e3_dp

   type(mat_neohookean_t)   :: mat, mat_bad
   type(mat_point_t)        :: pt
   type(material_state_t)   :: st, sn, snp1
   type(stability_range_t)  :: rng, rng_one
   type(stability_result_t) :: res, res_bad

   real(dp) :: buf_ok(3), buf_small(2)
   real(dp) :: C(3, 3), S(3, 3), CC(3, 3, 3, 3), M6(6, 6)
   real(dp) :: dt_factor, margin
   integer(ip) :: n, stat
   logical :: pd

   call t_begin('Malzeme sozlesmesi  (dondurulmus arayuz davranisi)')

   ! =========================================================================
   ! 1 -- serialise / restore gidis-donusu
   ! =========================================================================
   call t_info('')
   call t_info(' 1. serialise / restore')

   call st%init(3_ip)
   st%sv = [0.125_dp, -2.5_dp, 7.0_dp]

   buf_ok = 0.0_dp
   n = st%serialise(buf_ok)
   call t_check_int('serialise -> yazilan eleman', n, 3_ip)
   call t_check_le('serialise degerleri', maxval(abs(buf_ok - st%sv)), 0.0_dp)

   !> Tampon küçükse -1 dönmeli ve tampona DOKUNULMAMALI.
   buf_small = 0.0_dp
   n = st%serialise(buf_small)
   call t_check_int('kucuk tampon -> serialise', n, -1_ip)
   call t_check_le('kucuk tampona dokunulmadi', maxval(abs(buf_small)), 0.0_dp)

   !> Gidiş-dönüş: durumu boz, tampondan geri yükle, aslını geri al.
   st%sv = [0.0_dp, 0.0_dp, 0.0_dp]
   n = st%restore(buf_ok)
   call t_check_int('restore -> okunan eleman', n, 3_ip)
   call t_check_le('gidis-donus farki', &
                   maxval(abs(st%sv - [0.125_dp, -2.5_dp, 7.0_dp])), 0.0_dp)

   n = st%restore(buf_small)
   call t_check_int('kucuk tampon -> restore', n, -1_ip)
   call t_check_le('kucuk tamponda durum korundu', &
                   maxval(abs(st%sv - [0.125_dp, -2.5_dp, 7.0_dp])), 0.0_dp)

   ! =========================================================================
   ! 2 -- set_bounds + project
   ! =========================================================================
   call t_info('')
   call t_info(' 2. set_bounds + project  (remesh sonrasi kirpma)')

   call st%init(3_ip)
   !> 1 ve 2 hasar benzeri, [0,1] ile sinirli. 3 sinirsiz birakiliyor.
   call st%set_bounds(1_ip, 0.0_dp, 1.0_dp)
   call st%set_bounds(2_ip, 0.0_dp, 1.0_dp)

   st%sv = [1.35_dp, -1.0e-9_dp, 42.0_dp]
   call st%project()

   call t_check_le('ust sinir  1.35 -> 1.0', abs(st%sv(1) - 1.0_dp), 0.0_dp)
   call t_check_le('alt sinir -1e-9 -> 0.0', abs(st%sv(2) - 0.0_dp), 0.0_dp)
   call t_check_le('sinirsiz  42.0 degismedi', abs(st%sv(3) - 42.0_dp), 0.0_dp)

   ! =========================================================================
   ! 3 -- fiziksel olmayan durum: det C <= 0
   ! =========================================================================
   call t_info('')
   call t_info(' 3. det C <= 0  (ters donmus eleman)')

   mat = new_neohookean(C10, KBULK)
   call sn%init(0_ip)
   call snp1%init(0_ip)

   !> Gerçek bir F'den asla üretilemeyecek bir C. Çözücü, ağ ters döndüğünde
   !> veya Newton düzeltmesi çok büyük olduğunda malzemeye böyle bir şey
   !> uzatabilir; malzeme durmak yerine haber vermelidir.
   C = 0.0_dp
   C(1, 1) = 1.0_dp
   C(2, 2) = 1.0_dp
   C(3, 3) = -0.5_dp

   call mat%eval(C, pt, sn, S, CC, snp1, stat, dt_factor)

   call t_check_int('stat = DES_MAT_NONPHYSICAL', stat, DES_MAT_NONPHYSICAL)
   call t_check_true('dt_factor < 1.0 (adim kucultme)', dt_factor < 1.0_dp)
   call t_check_true('dt_factor > 0.0', dt_factor > 0.0_dp)
   call t_check_le('S sifirlandi', maxval(abs(S)), 0.0_dp)
   call t_check_le('CC sifirlandi', maxval(abs(CC)), 0.0_dp)

   !> Geçerli bir C ile aynı malzeme sorunsuz çalışmalı: yukarıdaki reddin
   !> her şeyi reddeden bir kısayol olmadığını gösterir.
   C = 0.0_dp
   C(1, 1) = 1.44_dp
   C(2, 2) = 0.9025_dp
   C(3, 3) = 0.9025_dp
   call mat%eval(C, pt, sn, S, CC, snp1, stat, dt_factor)
   call t_check_int('gecerli C -> DES_MAT_OK', stat, DES_MAT_OK)
   call t_check_le('gecerli C -> dt_factor = 1', abs(dt_factor - 1.0_dp), 0.0_dp)

   ! =========================================================================
   ! 4 -- Kararlilik kontrolu  (mod bazli monotonluk, ADR 0007)
   !
   ! Olcut: uc deformasyon modunda dP/dlambda > 0.
   ! Tam tanjant pozitif tanimliligi (eski Drucker olcutu) DEGIL -- saglikli
   ! bir Neo-Hookean onu saglamaz; karsi ornek asagida 5. maddede.
   ! =========================================================================
   call t_info('')
   call t_info(' 4. Kararlilik: mod bazli dP/dlambda > 0')

   !> Fiziksel malzeme: C10 > 0. Uc modun tamaminda, lambda = 0.5 ... 4.0
   !> araliginda kararli olmali.
   mat = new_neohookean(C10, KBULK)
   call mat%check_stability(pt, sn, snp1, rng, res)

   call t_check_int('C10 > 0  : DES_STAB_OK', res%stat, DES_STAB_OK)
   call t_check_true('C10 > 0  : min egim > 0', res%min_slope > 0.0_dp)
   call t_check_int('C10 > 0  : kararsiz mod yok', res%first_mode, 0_ip)
   call t_check_int('hacimsel : DES_STAB_OK', res%vol_stat, DES_STAB_OK)
   write (*, '(a,es12.5,a,es12.5)') '            min dP/dlam = ', res%min_slope, &
      '   mu_ref ile = ', res%min_slope_n
   write (*, '(a)') '            mod bazinda en kucuk egim:'
   write (*, '(a,es12.5)') '              tek eksenli      : ', &
      res%mode_min_slope(DES_MODE_UNIAXIAL)
   write (*, '(a,es12.5)') '              esit iki eksenli : ', &
      res%mode_min_slope(DES_MODE_EQUIBIAXIAL)
   write (*, '(a,es12.5)') '              duzlemsel        : ', &
      res%mode_min_slope(DES_MODE_PLANAR)

   !> Fiziksel olmayan malzeme: C10 < 0 negatif kayma modulu demektir.
   !> Nominal gerilme uzamayla AZALIR; her uc mod da kararsiz cikmali.
   mat_bad = new_neohookean(-C10, KBULK)
   call mat_bad%check_stability(pt, sn, snp1, rng, res_bad)

   call t_check_int('C10 < 0  : DES_STAB_UNSTABLE', res_bad%stat, DES_STAB_UNSTABLE)
   call t_check_true('C10 < 0  : min egim < 0', res_bad%min_slope < 0.0_dp)
   call t_check_true('C10 < 0  : ilk kararsiz mod var', res_bad%first_mode > 0_ip)
   call t_check_true('C10 < 0  : ilk kararsizlik lam_min da', &
                     abs(res_bad%first_lambda - rng%lam_min) < 1.0e-12_dp)
   write (*, '(a,es12.5,a,i0,a,f6.3)') '            min dP/dlam = ', &
      res_bad%min_slope, '   ilk mod = ', res_bad%first_mode, &
      '   lambda = ', res_bad%first_lambda

   !> Mod secimi calisiyor mu: yalnizca duzlemsel modu tara.
   rng_one = rng
   rng_one%modes = .false.
   rng_one%modes(DES_MODE_PLANAR) = .true.
   call mat%check_stability(pt, sn, snp1, rng_one, res)
   call t_check_int('tek mod  : DES_STAB_OK', res%stat, DES_STAB_OK)
   call t_check_int('tek mod  : taranmayan mod UNKNOWN', &
                    res%mode_stat(DES_MODE_UNIAXIAL), DES_STAB_UNKNOWN)
   call t_check_int('tek mod  : taranan mod OK', &
                    res%mode_stat(DES_MODE_PLANAR), DES_STAB_OK)

   ! =========================================================================
   ! 5 -- ADR 0007 KARSI ORNEGI  (regresyon kilidi)
   !
   ! Eski olcutun neden birakildigini kayit altina alir: SAGLIKLI bir
   ! Neo-Hookean (C10 = +0.6, K = 1e3), F = diag(1.40, 0.85, 0.85) altinda
   ! tam tanjant pozitif tanimliligini saglamaz.
   !
   !   dC : CC : dC = -3.9389e+01   (dC = E5, yani (2,3) kayma yonu)
   !
   ! Ayni sayi uc bagimsiz yoldan dogrulanmistir (ADR 0007). Bu test,
   ! birinin ileride "kararliligi Cholesky ile yapalim" diye geri donmesini
   ! engeller: o olcut bu malzemeyi reddeder, yeni olcut kabul eder.
   ! =========================================================================
   call t_info('')
   call t_info(' 5. ADR 0007 karsi ornegi  (eski olcut neden birakildi)')

   mat = new_neohookean(C10, 1.0e3_dp)
   C = 0.0_dp
   C(1, 1) = 1.40_dp**2; C(2, 2) = 0.85_dp**2; C(3, 3) = 0.85_dp**2
   call mat%eval(C, pt, sn, S, CC, snp1, stat, dt_factor)
   call t_check_int('karsi ornek: eval OK', stat, DES_MAT_OK)

   call cc_to_mandel(CC, M6)
   call cholesky_margin(M6, pd, margin)

   !> Eski olcut bu SAGLIKLI malzemeyi reddediyor:
   call t_check_true('eski olcut: pozitif tanimli DEGIL', .not. pd)
   call t_check_le('dC:CC:dC = -3.9389e+01 (bagil)', &
                   abs(M6(5, 5) - (-3.9388773e+01_dp))/3.9388773e+01_dp, 1.0e-6_dp)
   write (*, '(a,es14.7)') '            M(5,5) = ', M6(5, 5)

   !> Yeni olcut ayni malzemeyi kabul ediyor:
   call mat%check_stability(pt, sn, snp1, rng, res)
   call t_check_int('yeni olcut: DES_STAB_OK', res%stat, DES_STAB_OK)

   write (*, '(a)') ''
   call t_finish()

end program check_contract
