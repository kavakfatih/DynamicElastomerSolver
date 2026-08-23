!> ---------------------------------------------------------------------------
!> check_material_tangent -- VER-002: tutarlı tanjant doğrulaması
!>
!> Analitik tanjant CC = 2 dS/dC, S'nin merkezi farkına karşı doğrulanır.
!> Ayrıca major simetri (CC_ijkl = CC_klij) kontrol edilir.
!>
!> SAYISAL TANJANTIN TÜRETİLMESİ
!>
!> CC = 2 dS/dC tanımı, simetrik bir dC yönü için şu anlama gelir:
!>
!>    dS = (1/2) CC : dC
!>
!> Simetrik bir M yönünde dC = h*M alırsak:
!>
!>    S(C + h*M) - S(C - h*M) = h * CC:M + O(h^3)
!>
!> Köşegen yön M = e_k(x)e_k için  CC:M = CC_ijkk  olur, dolayısıyla
!>    CC_ijkk = [S(C+hM) - S(C-hM)] / h
!>
!> Kayma yönü M = e_k(x)e_l + e_l(x)e_k (k /= l) için minör simetri nedeniyle
!> CC:M = 2*CC_ijkl olur, dolayısıyla
!>    CC_ijkl = [S(C+hM) - S(C-hM)] / (2h)
!>
!> Bu, pertürbasyonun C'nin simetrisini bozmamasını sağlar. Bileşenleri
!> tek tek (simetrisiz) oynatmak, S'nin tanım kümesi dışına çıkmak demektir.
!>
!> DETERMİNİSTİK deformasyon gradyanları kullanılır, rastgele DEĞİL: CI'da
!> kırmızıya dönen bir kontrol tekrar üretilebilir olmalıdır.
!>
!> İki malzeme: K/C10 = 1.7e3 (orta sıkıştırılabilirlik) ve 1.7e5
!> (kauçuk için gerçekçi, neredeyse sıkıştırılamaz).
!> ---------------------------------------------------------------------------
program check_material_tangent
   use des_kinds, only: dp, ip
   use des_material, only: mat_point_t, material_state_t, DES_MAT_OK
   use des_mat_neohookean, only: mat_neohookean_t, new_neohookean
   use test_support, only: t_begin, t_check_le, t_finish
   implicit none

   !> Merkezi fark adımı. h^2 kesme hatası ile h^-1 yuvarlama hatasının
   !> dengelendiği bölge; cift hassasiyette 1e-6 civarı optimumdur.
   real(dp), parameter :: FD_STEP = 1.0e-6_dp

   !> Beklenen bağıl hata ~1e-10'dur (yuvarlama tabanı). Tolerans iki
   !> mertebe pay bırakır: farklı derleyici/optimizasyon seviyelerinde
   !> yuvarlama tabanı birkaç kat oynayabilir, ama 1e-8'i aşan bir sapma
   !> yuvarlama değil FORMÜL hatasıdır.
   real(dp), parameter :: TOL_TANGENT = 1.0e-8_dp

   !> Major simetri analitik olarak TAM sağlanır; sapma yalnızca kayan
   !> nokta toplama sırasından gelebilir.
   real(dp), parameter :: TOL_MAJSYM = 1.0e-12_dp

   real(dp), parameter :: C10 = 0.6_dp

   type(mat_neohookean_t) :: mat
   type(mat_point_t)      :: pt
   type(material_state_t) :: sn, snp1

   real(dp) :: F(3, 3, 6)
   real(dp) :: kratio(2)
   character(len=28) :: fname(6)
   character(len=34) :: label

   real(dp) :: C(3, 3), S(3, 3), CCa(3, 3, 3, 3), CCn(3, 3, 3, 3)
   real(dp) :: err_rel, sym_rel, scale
   real(dp) :: dt_factor
   integer(ip) :: stat, im, ic
   logical :: ok

   call t_begin('VER-002  Tutarli tanjant  (CC = 2 dS/dC)')

   call sn%init(0_ip)
   call snp1%init(0_ip)

   call build_cases(F, fname)
   kratio = [1.7e3_dp, 1.7e5_dp]

   do im = 1, 2
      mat = new_neohookean(C10, kratio(im)*C10)

      write (*, '(a)') ''
      write (*, '(a,es9.2,a,es9.2,a,es9.2)') &
         ' Malzeme: C10 = ', mat%c10, '   K = ', mat%kappa, '   K/C10 = ', kratio(im)

      do ic = 1, 6
         C = matmul(transpose(F(:, :, ic)), F(:, :, ic))

         call mat%eval(C, pt, sn, S, CCa, snp1, stat, dt_factor)
         if (stat /= DES_MAT_OK) then
            write (*, '(a,i0)') '  eval basarisiz, stat = ', stat
            error stop 2
         end if

         call numeric_tangent(mat, C, pt, sn, snp1, FD_STEP, CCn, ok)
         if (.not. ok) then
            write (*, '(a)') '  sayisal tanjant hesaplanamadi'
            error stop 3
         end if

         scale = maxval(abs(CCa))
         err_rel = maxval(abs(CCn - CCa))/scale
         sym_rel = major_asymmetry(CCa)/scale

         label = trim(fname(ic))//' : CC bagil hata'
         call t_check_le(label, err_rel, TOL_TANGENT)
         label = trim(fname(ic))//' : major simetri'
         call t_check_le(label, sym_rel, TOL_MAJSYM)
      end do
   end do

   write (*, '(a)') ''
   call t_finish()

contains

   !> Altı deterministik deformasyon gradyanı.
   subroutine build_cases(Fout, nameout)
      real(dp), intent(out) :: Fout(3, 3, 6)
      character(len=28), intent(out) :: nameout(6)

      Fout = 0.0_dp

      !> 1 -- tek eksenli çekme
      Fout(:, :, 1) = diag3(1.20_dp, 0.95_dp, 0.95_dp)
      nameout(1) = 'cekme          '

      !> 2 -- tek eksenli basma
      Fout(:, :, 2) = diag3(0.80_dp, 1.05_dp, 1.05_dp)
      nameout(2) = 'basma          '

      !> 3 -- saf kayma (izokorik düzlem uzama: lambda, 1/lambda, 1)
      Fout(:, :, 3) = diag3(1.30_dp, 1.0_dp/1.30_dp, 1.0_dp)
      nameout(3) = 'saf kayma      '

      !> 4 -- büyük uzama, lambda = 3
      Fout(:, :, 4) = diag3(3.00_dp, 0.60_dp, 0.60_dp)
      nameout(4) = 'lambda = 3     '

      !> 5 -- birleşik kayma + uzama (köşegen dışı terimli, en zorlu vaka)
      Fout(1, 1, 5) = 1.15_dp; Fout(1, 2, 5) = 0.25_dp; Fout(1, 3, 5) = 0.00_dp
      Fout(2, 1, 5) = 0.00_dp; Fout(2, 2, 5) = 0.95_dp; Fout(2, 3, 5) = 0.10_dp
      Fout(3, 1, 5) = 0.05_dp; Fout(3, 2, 5) = 0.00_dp; Fout(3, 3, 5) = 1.05_dp
      nameout(5) = 'kayma + uzama  '

      !> 6 -- saf hacimsel (K büyükken tanjantın en sert bileşeni)
      Fout(:, :, 6) = diag3(1.03_dp, 1.03_dp, 1.03_dp)
      nameout(6) = 'hacimsel       '
   end subroutine build_cases

   !> Kösegen deformasyon gradyani. Kukla argüman adlari bilinçli olarak
   !> d11/d22/d33: tek harfli `c`, host kapsamindaki C(3,3) tensörünü
   !> maskelerdi (bkz. AGENTS.md, host maskeleme kurali).
   pure function diag3(d11, d22, d33) result(D)
      real(dp), intent(in) :: d11, d22, d33
      real(dp) :: D(3, 3)

      D = 0.0_dp
      D(1, 1) = d11
      D(2, 2) = d22
      D(3, 3) = d33
   end function diag3

   !> S'nin simetrik yönlerde merkezi farkıyla sayısal tanjant.
   subroutine numeric_tangent(m, C0, ptl, s_n, s_np1, h, CCout, okout)
      type(mat_neohookean_t), intent(in)    :: m
      real(dp), intent(in)                  :: C0(3, 3)
      type(mat_point_t), intent(in)         :: ptl
      type(material_state_t), intent(in)    :: s_n
      type(material_state_t), intent(inout) :: s_np1
      real(dp), intent(in)                  :: h
      real(dp), intent(out)                 :: CCout(3, 3, 3, 3)
      logical, intent(out)                  :: okout

      real(dp) :: Mp(3, 3), Cp(3, 3), Cm(3, 3)
      real(dp) :: Sp(3, 3), Sm(3, 3), dS(3, 3)
      real(dp) :: CCdummy(3, 3, 3, 3), dtf
      integer(ip) :: k, l, st

      CCout = 0.0_dp
      okout = .true.

      do l = 1, 3
         do k = 1, l
            Mp = 0.0_dp
            if (k == l) then
               Mp(k, k) = 1.0_dp
            else
               Mp(k, l) = 1.0_dp
               Mp(l, k) = 1.0_dp
            end if

            Cp = C0 + h*Mp
            Cm = C0 - h*Mp

            call m%eval(Cp, ptl, s_n, Sp, CCdummy, s_np1, st, dtf)
            if (st /= DES_MAT_OK) then
               okout = .false.
               return
            end if

            call m%eval(Cm, ptl, s_n, Sm, CCdummy, s_np1, st, dtf)
            if (st /= DES_MAT_OK) then
               okout = .false.
               return
            end if

            dS = (Sp - Sm)/h

            if (k == l) then
               CCout(:, :, k, k) = dS
            else
               CCout(:, :, k, l) = 0.5_dp*dS
               CCout(:, :, l, k) = 0.5_dp*dS
            end if
         end do
      end do
   end subroutine numeric_tangent

   !> max |CC_ijkl - CC_klij|
   pure function major_asymmetry(T) result(d)
      real(dp), intent(in) :: T(3, 3, 3, 3)
      real(dp) :: d
      integer(ip) :: i, j, k, l

      d = 0.0_dp
      do l = 1, 3
         do k = 1, 3
            do j = 1, 3
               do i = 1, 3
                  d = max(d, abs(T(i, j, k, l) - T(k, l, i, j)))
               end do
            end do
         end do
      end do
   end function major_asymmetry

end program check_material_tangent
