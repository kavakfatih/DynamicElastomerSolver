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
   use des_material, only: mat_point_t, material_state_t, &
                           DES_MAT_OK, DES_MAT_NONPHYSICAL, &
                           DES_STAB_OK, DES_STAB_UNSTABLE
   use des_mat_neohookean, only: mat_neohookean_t, new_neohookean
   use test_support, only: t_begin, t_check_le, t_check_true, t_check_int, &
                           t_info, t_finish
   implicit none

   real(dp), parameter :: C10 = 0.6_dp
   real(dp), parameter :: KBULK = 1.0e3_dp

   type(mat_neohookean_t) :: mat, mat_bad
   type(mat_point_t)      :: pt
   type(material_state_t) :: st, sn, snp1

   real(dp) :: buf_ok(3), buf_small(2)
   real(dp) :: C(3, 3), S(3, 3), CC(3, 3, 3, 3)
   real(dp) :: dt_factor, margin, margin_bad
   integer(ip) :: n, stat, sstat

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
   ! 4 -- Drucker kararlilik kontrolu
   ! =========================================================================
   call t_info('')
   call t_info(' 4. Drucker kararliligi  (Mandel bazi + Cholesky)')

   !> Fiziksel malzeme: C10 > 0. Hem deforme olmamis hem deforme durumda
   !> kararli olmali.
   C = 0.0_dp
   C(1, 1) = 1.0_dp; C(2, 2) = 1.0_dp; C(3, 3) = 1.0_dp
   call mat%check_stability(C, pt, sn, snp1, sstat, margin)
   call t_check_int('C = I    : DES_STAB_OK', sstat, DES_STAB_OK)
   call t_check_true('C = I    : marj > 0', margin > 0.0_dp)
   write (*, '(a,es12.5)') '            marj = ', margin

   !> Deforme ama İZOKORİK durum: F = diag(1.3, 1/1.3, 1), yani J = 1.
   !> C = I ile yetinmemek önemli; aksi hâlde kontrolün deformasyona
   !> gerçekten baktığı gösterilmiş olmaz.
   C = 0.0_dp
   C(1, 1) = 1.69_dp; C(2, 2) = 1.0_dp/1.69_dp; C(3, 3) = 1.0_dp
   call mat%check_stability(C, pt, sn, snp1, sstat, margin)
   call t_check_int('izokorik : DES_STAB_OK', sstat, DES_STAB_OK)
   call t_check_true('izokorik : marj > 0', margin > 0.0_dp)
   write (*, '(a,es12.5)') '            marj = ', margin

   !> Fiziksel olmayan malzeme: C10 < 0 negatif kayma modulu demektir.
   !> Hacimsel terim (K = 1e3) pozitif oldugu icin ilk Cholesky pivot'u hala
   !> pozitiftir -- kararsizlik ancak sapinsal modlarda ortaya cikar.
   !> Kontrolun bunu yakalamasi, kosegene bakmakla yetinmedigini gosterir.
   mat_bad = new_neohookean(-C10, KBULK)
   C = 0.0_dp
   C(1, 1) = 1.0_dp; C(2, 2) = 1.0_dp; C(3, 3) = 1.0_dp
   call mat_bad%check_stability(C, pt, sn, snp1, sstat, margin_bad)
   call t_check_int('C10 < 0  : DES_STAB_UNSTABLE', sstat, DES_STAB_UNSTABLE)
   call t_check_true('C10 < 0  : marj <= 0', margin_bad <= 0.0_dp)
   write (*, '(a,es12.5)') '            marj = ', margin_bad

   ! -------------------------------------------------------------------------
   ! TANI (iddia YOK) -- hacim degisimine karsi Drucker marji
   !
   ! Asagidaki tarama bir kontrol degil, bir GOZLEMDIR ve bilincli olarak
   ! iddiaya baglanmamistir. Gosterdigi sey su: CC'nin pozitif tanimliligi
   ! olarak tanimlanan Drucker kararliligi, sikistirilabilir Neo-Hookean'da
   ! J birden uzaklasir uzaklasmaz kaybolur ve esik K/C10 buyudukce 1'e
   ! yapisir. Bu bir port hatasi degildir: tanjant, sonlu farka karsi
   ! 1e-10 bagil hatayla dogrulanmistir (VER-002).
   !
   ! Kriterin kendisi tartismaya acilmistir; karar verilene kadar burada
   ! yalnizca kayit altina aliniyor. CI gunlugune bakan biri sayiyi gormeli.
   ! -------------------------------------------------------------------------
   call t_info('')
   call t_info(' TANI: hacimsel zorlanmaya karsi Drucker marji (iddia yok)')
   call t_info('    F = s*I,  C10 = 0.6,  K = 1.0e3')
   call scan_volumetric(mat)

   write (*, '(a)') ''
   call t_finish()

contains

   !> Saf hacimsel zorlanma boyunca kararlılık marjını yazdırır.
   subroutine scan_volumetric(m)
      type(mat_neohookean_t), intent(in) :: m

      real(dp) :: Cl(3, 3), s, marg
      integer(ip) :: i, sst

      write (*, '(a)') '        s        J         durum      marj'
      do i = -2, 4
         s = 1.0_dp + real(i, dp)*0.01_dp
         Cl = 0.0_dp
         Cl(1, 1) = s*s; Cl(2, 2) = s*s; Cl(3, 3) = s*s
         call m%check_stability(Cl, pt, sn, snp1, sst, marg)
         write (*, '(a,f8.4,2x,f8.5,6x,i0,4x,es12.4)') '   ', s, s**3, sst, marg
      end do
   end subroutine scan_volumetric

end program check_contract
