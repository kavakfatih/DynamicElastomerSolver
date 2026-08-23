!> ---------------------------------------------------------------------------
!> check_uniaxial -- VER-001: tek eksenli gerilme doğrulaması
!>
!> Sıkıştırılamaz Neo-Hookean için tek eksenli gerilme tam çözümü:
!>
!>    sigma_11 = 2*C10*( lambda^2 - 1/lambda )
!>    E (küçük şekil değiştirme) = 6*C10
!>
!> BURADA BİR TUZAK VAR
!>
!> lambda2 = lambda3 = lambda^(-1/2) dayatmak tek eksenli GERİLME durumu
!> VERMEZ. O, sıkıştırılamaz malzemenin kinematik cevabıdır; bizim
!> malzememiz sıkıştırılabilirdir. Sıkıştırılabilir bir malzemede yanal
!> uzama BİLİNMEYENDİR ve sigma_22 = 0 koşulundan ÇÖZÜLMELİDİR.
!>
!> Yanlış yapılırsa elastisite modülü 6*C10 yerine 4*C10 çıkar. 3.6 yerine
!> 2.4 -- ve bu sayı, kimsenin gözüne batmayacak kadar makul görünür.
!> Testin asıl varlık sebebi budur.
!>
!> Yanal uzama burada ikiye bölme (bisection) ile çözülür: sigma_22(lam_t)
!> monoton artandır, dolayısıyla kök bulma güvenlidir ve Newton'un
!> yakınsamama riski yoktur. Doğrulama testi, doğruladığı şeyden daha
!> kırılgan olmamalıdır.
!> ---------------------------------------------------------------------------
program check_uniaxial
   use des_kinds, only: dp, ip
   use des_tensor, only: cauchy_from_pk2
   use des_material, only: mat_point_t, material_state_t, DES_MAT_OK
   use des_mat_neohookean, only: mat_neohookean_t, new_neohookean
   use test_support, only: t_begin, t_check_le, t_finish
   implicit none

   real(dp), parameter :: C10 = 0.6_dp
   real(dp), parameter :: KBULK = 1.0e5_dp

   !> Doğrulama uzama oranları.
   real(dp), parameter :: LAM(5) = [1.05_dp, 1.25_dp, 1.50_dp, 2.00_dp, 3.00_dp]

   !> Beklenen bağıl sapmalar. Bunlar SAYISAL hata değil, FİZİKSEL sapmadır:
   !> tam çözüm sıkıştırılamaz malzeme içindir, bizim malzememizin sonlu bir
   !> K'sı vardır. Sapma mu/K = 1.2e-5 mertebesinde ve uzamayla büyür.
   !> Tolerans, beklenenin iki katı alınmıştır -- daha fazlası formül
   !> hatasını gizler, daha azı platform gürültüsüne takılır.
   real(dp), parameter :: TOL_SIG(5) = &
                          [1.0e-5_dp, 1.6e-5_dp, 2.6e-5_dp, 5.0e-5_dp, 1.2e-4_dp]

   !> E için merkezi fark adımı. Yanal uzama her adımda yeniden çözüldüğü
   !> için bu, tam sıkıştırılabilir cevabın türevidir.
   real(dp), parameter :: E_STEP = 1.0e-4_dp

   !> E'nin 6*C10'a bağıl yakınlığı. Asıl amaç 4*C10 tuzağını yakalamaktır
   !> (%33 sapma); sonlu K yüzünden beklenen sapma ~4e-6'dır.
   real(dp), parameter :: TOL_E_INCOMP = 1.0e-4_dp

   !> E'nin, sonlu K için ANALİTİK küçük şekil değiştirme değerine
   !> yakınlığı. Burada fiziksel sapma yoktur, yalnızca sayısal hata
   !> kalır; dolayısıyla tolerans sıkıdır.
   real(dp), parameter :: TOL_E_COMP = 1.0e-6_dp

   type(mat_neohookean_t) :: mat
   type(mat_point_t)      :: pt
   type(material_state_t) :: sn, snp1

   real(dp) :: lam_t, sig11, sig_exact, err, resid
   real(dp) :: err_tab(size(LAM))
   real(dp) :: e_num, e_incomp, e_comp, mu
   real(dp) :: sp, sm
   character(len=34) :: label
   integer(ip) :: i
   logical :: ok

   call t_begin('VER-001  Tek eksenli gerilme  (Neo-Hookean)')

   mat = new_neohookean(C10, KBULK)
   call sn%init(0_ip)
   call snp1%init(0_ip)

   mu = 2.0_dp*C10
   e_incomp = 6.0_dp*C10
   e_comp = 9.0_dp*KBULK*mu/(3.0_dp*KBULK + mu)

   write (*, '(a,f6.3,a,es9.2,a,es9.2)') &
      ' C10 = ', C10, '   K = ', KBULK, '   K/C10 = ', KBULK/C10
   write (*, '(a)') ''
   write (*, '(a)') '  lambda    lam_yanal      sigma11        tam cozum     bagil hata'
   write (*, '(a)') '  ----------------------------------------------------------------'

   do i = 1, size(LAM)
      call solve_lateral(mat, LAM(i), lam_t, sig11, resid, ok)
      if (.not. ok) then
         write (*, '(a,f6.3)') '  yanal uzama cozulemedi, lambda = ', LAM(i)
         error stop 2
      end if

      sig_exact = 2.0_dp*C10*(LAM(i)**2 - 1.0_dp/LAM(i))
      err = abs(sig11 - sig_exact)/abs(sig_exact)

      write (*, '(a,f7.3,3x,f10.7,3x,es13.6,2x,es13.6,2x,es10.3)') &
         '  ', LAM(i), lam_t, sig11, sig_exact, err

      write (label, '(a,f5.2,a)') 'lambda = ', LAM(i), ' : sigma11 hata'
      err_tab(i) = err
   end do

   write (*, '(a)') ''

   do i = 1, size(LAM)
      write (label, '(a,f5.2,a)') 'lambda = ', LAM(i), ' : sigma11 hata'
      call t_check_le(label, err_tab(i), TOL_SIG(i))
   end do

   !> sigma_22 = 0 koşulunun gerçekten sağlandığını da doğrula: yanal uzama
   !> yanlış çözülmüşse gerilme hatası küçük kalıp bu artık büyük çıkar.
   call solve_lateral(mat, 2.0_dp, lam_t, sig11, resid, ok)
   call t_check_le('yanal serbestlik : |sigma22|/K', abs(resid)/KBULK, 1.0e-14_dp)

   ! --- Küçük şekil değiştirme elastisite modülü ----------------------------
   call uniaxial_sigma(mat, 1.0_dp + E_STEP, sp, ok)
   call uniaxial_sigma(mat, 1.0_dp - E_STEP, sm, ok)
   e_num = (sp - sm)/(2.0_dp*E_STEP)

   write (*, '(a)') ''
   write (*, '(a,f12.6)') '  E (sayisal, merkezi fark)        = ', e_num
   write (*, '(a,f12.6)') '  E = 6*C10 (sikistirilamaz)       = ', e_incomp
   write (*, '(a,f12.6)') '  E = 9*K*mu/(3*K+mu) (K = 1e5)    = ', e_comp
   write (*, '(a,f12.6)') '  4*C10 (YANLIS port bu sayiyi verir) = ', 4.0_dp*C10
   write (*, '(a)') ''

   call t_check_le('E vs 6*C10        bagil hata', &
                   abs(e_num - e_incomp)/e_incomp, TOL_E_INCOMP)
   call t_check_le('E vs 9Kmu/(3K+mu) bagil hata', &
                   abs(e_num - e_comp)/e_comp, TOL_E_COMP)

   write (*, '(a)') ''
   call t_finish()

contains

   !> Verilen eksenel uzama için yanal uzamayı sigma_22 = 0 olacak şekilde
   !> ikiye bölme ile çözer; eksenel Cauchy gerilmesini ve sigma_22 artığını
   !> döndürür.
   subroutine solve_lateral(m, lambda, lt_out, s11_out, resid_out, okout)
      type(mat_neohookean_t), intent(in) :: m
      real(dp), intent(in)  :: lambda
      real(dp), intent(out) :: lt_out
      real(dp), intent(out) :: s11_out
      real(dp), intent(out) :: resid_out
      logical, intent(out)  :: okout

      !> Kök aralığı. Alt sınır aşırı yanal basma, üst sınır aşırı yanal
      !> çekmedir; fiziksel çözüm her zaman arada kalır.
      real(dp), parameter :: LT_LO = 0.05_dp
      real(dp), parameter :: LT_HI = 2.00_dp
      integer(ip), parameter :: N_ITER = 200_ip

      real(dp) :: lo, hi, mid, f_lo, f_hi, f_mid, s11
      integer(ip) :: it

      okout = .false.
      lt_out = 0.0_dp
      s11_out = 0.0_dp
      resid_out = 0.0_dp

      lo = LT_LO
      hi = LT_HI

      call sigma_pair(m, lambda, lo, s11, f_lo, okout)
      if (.not. okout) return
      call sigma_pair(m, lambda, hi, s11, f_hi, okout)
      if (.not. okout) return

      !> Kök kuşatılmamışsa sessizce yanlış bir cevap üretmek yerine dur.
      if (f_lo > 0.0_dp .or. f_hi < 0.0_dp) then
         okout = .false.
         return
      end if

      do it = 1, N_ITER
         mid = 0.5_dp*(lo + hi)
         call sigma_pair(m, lambda, mid, s11, f_mid, okout)
         if (.not. okout) return

         if (f_mid < 0.0_dp) then
            lo = mid
         else
            hi = mid
         end if
      end do

      lt_out = mid
      s11_out = s11
      resid_out = f_mid
      okout = .true.
   end subroutine solve_lateral

   !> F = diag(lambda, lam_t, lam_t) için Cauchy gerilmesinin 11 ve 22
   !> bileşenlerini döndürür.
   subroutine sigma_pair(m, lambda, lam_lat, s11, s22, okout)
      type(mat_neohookean_t), intent(in) :: m
      real(dp), intent(in)  :: lambda
      real(dp), intent(in)  :: lam_lat
      real(dp), intent(out) :: s11
      real(dp), intent(out) :: s22
      logical, intent(out)  :: okout

      real(dp) :: F(3, 3), C(3, 3), S(3, 3), CC(3, 3, 3, 3), sig(3, 3)
      real(dp) :: J, dtf
      integer(ip) :: st

      F = 0.0_dp
      F(1, 1) = lambda
      F(2, 2) = lam_lat
      F(3, 3) = lam_lat

      C = matmul(transpose(F), F)
      J = lambda*lam_lat*lam_lat

      call m%eval(C, pt, sn, S, CC, snp1, st, dtf)
      if (st /= DES_MAT_OK) then
         s11 = 0.0_dp
         s22 = 0.0_dp
         okout = .false.
         return
      end if

      sig = cauchy_from_pk2(F, S, J)
      s11 = sig(1, 1)
      s22 = sig(2, 2)
      okout = .true.
   end subroutine sigma_pair

   !> Yanal serbestliği çözülmüş tek eksenli Cauchy gerilmesi.
   subroutine uniaxial_sigma(m, lambda, s11, okout)
      type(mat_neohookean_t), intent(in) :: m
      real(dp), intent(in)  :: lambda
      real(dp), intent(out) :: s11
      logical, intent(out)  :: okout

      real(dp) :: lt, rs

      call solve_lateral(m, lambda, lt, s11, rs, okout)
   end subroutine uniaxial_sigma

end program check_uniaxial
