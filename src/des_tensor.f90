!> ---------------------------------------------------------------------------
!> des_tensor -- 3x3 ve 4. mertebe tensör araçları
!>
!> Malzeme çekirdeğinin ihtiyaç duyduğu küçük, sabit boyutlu tensör
!> işlemleri. Her şey 3x3 üzerinden yürür: malzeme katmanı analiz tipini
!> (düzlem şekil değiştirme / eksenel simetrik / burulmalı) asla bilmez,
!> dolayısıyla indirgenmiş 2x2 varyantlar burada bilinçli olarak yoktur.
!>
!> Bu modül tahsis (allocate) yapmaz, dosya açmaz, yazdırmaz.
!>
!> Katman: 5 -- Sayısal temel
!> ---------------------------------------------------------------------------
module des_tensor
   use des_kinds, only: dp, ip
   implicit none
   private

   public :: IDENT3
   public :: det3, inv3, trace3
   public :: cauchy_from_pk2
   public :: cc_to_mandel
   public :: cholesky_margin

   !> 3x3 birim tensör (Kronecker delta).
   real(dp), parameter :: IDENT3(3, 3) = reshape( &
                          [1.0_dp, 0.0_dp, 0.0_dp, &
                           0.0_dp, 1.0_dp, 0.0_dp, &
                           0.0_dp, 0.0_dp, 1.0_dp], [3, 3])

   !> Mandel/Kelvin gösteriminde 6 bazın satır indisleri:
   !> 1:(1,1) 2:(2,2) 3:(3,3) 4:(1,2) 5:(2,3) 6:(1,3)
   integer(ip), parameter :: MANDEL_I(6) = [1_ip, 2_ip, 3_ip, 1_ip, 2_ip, 1_ip]
   integer(ip), parameter :: MANDEL_J(6) = [1_ip, 2_ip, 3_ip, 2_ip, 3_ip, 3_ip]

contains

   !> 3x3 matrisin determinantı.
   pure function det3(A) result(d)
      real(dp), intent(in) :: A(3, 3)
      real(dp) :: d

      d = A(1, 1)*(A(2, 2)*A(3, 3) - A(2, 3)*A(3, 2)) &
          - A(1, 2)*(A(2, 1)*A(3, 3) - A(2, 3)*A(3, 1)) &
          + A(1, 3)*(A(2, 1)*A(3, 2) - A(2, 2)*A(3, 1))
   end function det3

   !> 3x3 matrisin izi.
   pure function trace3(A) result(t)
      real(dp), intent(in) :: A(3, 3)
      real(dp) :: t

      t = A(1, 1) + A(2, 2) + A(3, 3)
   end function trace3

   !> 3x3 matrisin tersi, kofaktör açılımıyla.
   !>
   !> `det` çağıran tarafından hesaplanıp verilir: çağıranlar zaten J =
   !> sqrt(det C) için determinanta ihtiyaç duyar, iki kez hesaplamanın
   !> anlamı yok. `ok` yanlış dönerse `Ainv` tanımsızdır — bölme hiç
   !> yapılmaz, böylece -ffpe-trap=zero altında tuzağa düşülmez.
   pure subroutine inv3(A, det, Ainv, ok)
      real(dp), intent(in)  :: A(3, 3)
      real(dp), intent(in)  :: det
      real(dp), intent(out) :: Ainv(3, 3)
      logical, intent(out)  :: ok

      real(dp) :: invdet

      !> Eşiğin `tiny` olmasının sebebi: |det| bunun altındayken 1/det zaten
      !> taşar (overflow). Sıfırla tam eşitlik aramak hem bu durumu kaçırır
      !> hem de anlamsız bir kayan nokta karşılaştırmasıdır.
      if (abs(det) <= tiny(1.0_dp)) then
         ok = .false.
         Ainv = 0.0_dp
         return
      end if

      ok = .true.
      invdet = 1.0_dp/det

      Ainv(1, 1) = (A(2, 2)*A(3, 3) - A(2, 3)*A(3, 2))*invdet
      Ainv(1, 2) = (A(1, 3)*A(3, 2) - A(1, 2)*A(3, 3))*invdet
      Ainv(1, 3) = (A(1, 2)*A(2, 3) - A(1, 3)*A(2, 2))*invdet
      Ainv(2, 1) = (A(2, 3)*A(3, 1) - A(2, 1)*A(3, 3))*invdet
      Ainv(2, 2) = (A(1, 1)*A(3, 3) - A(1, 3)*A(3, 1))*invdet
      Ainv(2, 3) = (A(1, 3)*A(2, 1) - A(1, 1)*A(2, 3))*invdet
      Ainv(3, 1) = (A(2, 1)*A(3, 2) - A(2, 2)*A(3, 1))*invdet
      Ainv(3, 2) = (A(1, 2)*A(3, 1) - A(1, 1)*A(3, 2))*invdet
      Ainv(3, 3) = (A(1, 1)*A(2, 2) - A(1, 2)*A(2, 1))*invdet
   end subroutine inv3

   !> 2. Piola-Kirchhoff gerilmesinden Cauchy gerilmesi: sigma = (1/J) F S F^T
   pure function cauchy_from_pk2(F, S, J) result(sig)
      real(dp), intent(in) :: F(3, 3)
      real(dp), intent(in) :: S(3, 3)
      real(dp), intent(in) :: J
      real(dp) :: sig(3, 3)

      sig = matmul(F, matmul(S, transpose(F)))/J
   end function cauchy_from_pk2

   !> 4. mertebe tanjantı ortonormal Mandel/Kelvin bazında 6x6 matrise indirger.
   !>
   !> Baz tensörleri:
   !>   E1 = e1(x)e1,  E2 = e2(x)e2,  E3 = e3(x)e3,
   !>   E4 = (e1(x)e2 + e2(x)e1)/sqrt(2),
   !>   E5 = (e2(x)e3 + e3(x)e2)/sqrt(2),
   !>   E6 = (e1(x)e3 + e3(x)e1)/sqrt(2)
   !>
   !> M_ab = E_a : CC : E_b
   !>
   !> Baz ortonormal olduğu için Voigt gösterimindeki 2 ve 4 çarpanı
   !> muhasebesi YOKTUR: kayma satır/sütunları yalnızca sqrt(2) taşır ve
   !> M'nin özdeğerleri CC'nin gerçek özdeğerleridir. Kararlılık kararı
   !> tam da bu yüzden Mandel bazında verilir.
   pure subroutine cc_to_mandel(CC, M)
      real(dp), intent(in)  :: CC(3, 3, 3, 3)
      real(dp), intent(out) :: M(6, 6)

      real(dp) :: fac(6)
      integer(ip) :: a, b

      fac(1:3) = 1.0_dp
      fac(4:6) = sqrt(2.0_dp)

      do b = 1, 6
         do a = 1, 6
            M(a, b) = fac(a)*fac(b) &
                      *CC(MANDEL_I(a), MANDEL_J(a), MANDEL_I(b), MANDEL_J(b))
         end do
      end do
   end subroutine cc_to_mandel

   !> Cholesky ayrıştırması dener; pozitif tanımlılık kararını ve marjı döndürür.
   !>
   !> Cholesky'nin başarısı, simetrik bir matrisin pozitif tanımlı olmasıyla
   !> TAM OLARAK denktir; özdeğer çözücüsüne gerek yoktur. `margin`, en küçük
   !> normalize pivot'tur (pivot / köşegenin en büyük mutlak değeri):
   !> boyutsuzdur, pozitifse malzeme kararlı, sıfıra yaklaşıyorsa kararlılık
   !> sınırına yaklaşılıyor demektir.
   !>
   !> Başarısızlıkta `margin` tuzağa düşüren (pozitif olmayan) pivot'tur;
   !> bu, "ne kadar kararsız" sorusuna anlamlı bir cevap verir.
   pure subroutine cholesky_margin(M, ok, margin)
      real(dp), intent(in)  :: M(:, :)
      logical, intent(out)  :: ok
      real(dp), intent(out) :: margin

      real(dp), allocatable :: L(:, :)
      real(dp) :: piv, scal
      integer(ip) :: n, a, b

      n = int(size(M, 1), ip)
      ok = .false.
      margin = 0.0_dp

      scal = 0.0_dp
      do a = 1, n
         scal = max(scal, abs(M(a, a)))
      end do

      !> Köşegen tümüyle sıfırsa matris pozitif tanımlı olamaz ve
      !> normalizasyon için ölçek yoktur.
      if (scal <= 0.0_dp) return

      allocate (L(n, n))
      L = 0.0_dp
      margin = huge(1.0_dp)

      do a = 1, n
         piv = M(a, a) - sum(L(a, 1:a - 1)**2)
         margin = min(margin, piv/scal)
         if (piv <= 0.0_dp) then
            margin = piv/scal
            return
         end if
         L(a, a) = sqrt(piv)
         do b = a + 1, n
            L(b, a) = (M(b, a) - sum(L(b, 1:a - 1)*L(a, 1:a - 1)))/L(a, a)
         end do
      end do

      ok = .true.
   end subroutine cholesky_margin

end module des_tensor
