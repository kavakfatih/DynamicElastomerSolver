!> ---------------------------------------------------------------------------
!> des_linsolve -- doğrusal çözücü arayüzü (DONDURULMUŞ SÖZLEŞME 3/4)
!>
!> ARAYÜZ SİMETRİK INDEFINITE TAŞIR
!>
!> Karışık u-p formülasyonu (v0.3) bir eyer noktası (saddle point) sistemi
!> üretir: basınç blokunun köşegeni sıfırdır, matris simetriktir ama
!> pozitif tanımlı DEĞİLDİR. Yalnızca Cholesky varsayan bir arayüz orada
!> çöker ve çözücü katmanı baştan yazılır. Bu yüzden sözleşme baştan
!> indefinite taşır:
!>
!>   - `factorize` pozitif tanımlılık VARSAYMAZ; LDL^T yapar
!>   - `inertia` (n_poz, n_neg, n_sifir) döndürür -- LDL^T'den neredeyse
!>     bedava gelir ve kararlılık kaybını yakalar
!>
!> BU OTURUMDAKİ UYGULAMANIN SINIRI -- AÇIKÇA
!>
!> `skyline_ldlt_t` **PİVOTLAMA YAPMAZ**. Simetrik pozitif tanımlı
!> sistemlerde her zaman çalışır. Genel indefinite sistemlerde sıfıra
!> yakın bir pivotla karşılaşabilir ve DES_LIN_ZERO_PIVOT döndürür;
!> sessizce yanlış cevap ÜRETMEZ.
!>
!> Bunun sebebi profil (skyline) depolamasının doğasıdır: Bunch-Kaufman'ın
!> gerektirdiği satır/sütun takasları profili bozar. Pivotlu bir uygulama
!> (Bunch-Kaufman veya seyrek doğrudan çözücü) v0.3'te karışık u-p ile
!> birlikte gelecektir. Arayüz o gün değişmeyecek -- taşıdığı sözleşme
!> zaten indefinite'i kapsıyor.
!>
!> Katman: 5 -- Sayısal temel
!> ---------------------------------------------------------------------------
module des_linsolve
   use des_kinds, only: dp, ip
   use des_sparse, only: sparse_csr_t
   implicit none
   private

   public :: DES_LIN_OK, DES_LIN_BAD_ARG, DES_LIN_NOT_ANALYSED
   public :: DES_LIN_NOT_FACTORED, DES_LIN_ZERO_PIVOT
   public :: linsolver_t, skyline_ldlt_t

   !> Başarılı.
   integer(ip), parameter :: DES_LIN_OK = 0_ip
   !> Geçersiz argüman veya boyut uyuşmazlığı.
   integer(ip), parameter :: DES_LIN_BAD_ARG = 1_ip
   !> `analyse` çağrılmadan kullanıldı.
   integer(ip), parameter :: DES_LIN_NOT_ANALYSED = 2_ip
   !> `factorize` çağrılmadan `solve` denendi.
   integer(ip), parameter :: DES_LIN_NOT_FACTORED = 3_ip
   !> Sıfıra yakın pivot: matris tekil veya pivotlama gerekiyor.
   integer(ip), parameter :: DES_LIN_ZERO_PIVOT = 4_ip

   !> ------------------------------------------------------------------------
   !> Soyut doğrusal çözücü
   !>
   !> Kullanım sırası:
   !>   analyse(A)    -- deseni bir kez inceler, profil/sembolik yapı kurar
   !>   factorize(A)  -- her Newton adımında sayısal ayrıştırma
   !>   solve(b, x)   -- aynı ayrıştırmayla birden çok sağ taraf
   !>   free()
   !>
   !> `analyse` ile `factorize`in ayrı olması ZORUNLUDUR: desen bir ağ için
   !> sabittir ve Newton yinelemeleri arasında yeniden hesaplanmamalıdır.
   !> ------------------------------------------------------------------------
   type, abstract :: linsolver_t
      character(len=32) :: name = ''
      integer(ip) :: n = 0_ip
      logical :: analysed = .false.
      logical :: factored = .false.
   contains
      procedure(ls_analyse_i), deferred :: analyse
      procedure(ls_factorize_i), deferred :: factorize
      procedure(ls_solve_i), deferred :: solve
      procedure(ls_inertia_i), deferred :: inertia
      procedure(ls_free_i), deferred :: free
   end type linsolver_t

   abstract interface

      subroutine ls_analyse_i(this, A, stat)
         import :: ip, linsolver_t, sparse_csr_t
         class(linsolver_t), intent(inout) :: this
         type(sparse_csr_t), intent(in) :: A
         integer(ip), intent(out) :: stat
      end subroutine ls_analyse_i

      subroutine ls_factorize_i(this, A, stat)
         import :: ip, linsolver_t, sparse_csr_t
         class(linsolver_t), intent(inout) :: this
         type(sparse_csr_t), intent(in) :: A
         integer(ip), intent(out) :: stat
      end subroutine ls_factorize_i

      subroutine ls_solve_i(this, b, x, stat)
         import :: dp, ip, linsolver_t
         class(linsolver_t), intent(in) :: this
         real(dp), intent(in) :: b(:)
         real(dp), intent(out) :: x(:)
         integer(ip), intent(out) :: stat
      end subroutine ls_solve_i

      !> Atalet (inertia): pozitif, negatif ve sıfır özdeğer sayıları.
      !>
      !> Sylvester atalet yasası gereği LDL^T'nin D köşegenindeki işaret
      !> dağılımı, matrisin özdeğer işaret dağılımıyla aynıdır. Kararlılık
      !> kaybı burada görünür: beklenmeyen bir negatif, sistemin kritik
      !> noktayı geçtiğini söyler.
      subroutine ls_inertia_i(this, n_pos, n_neg, n_zero, stat)
         import :: ip, linsolver_t
         class(linsolver_t), intent(in) :: this
         integer(ip), intent(out) :: n_pos, n_neg, n_zero
         integer(ip), intent(out) :: stat
      end subroutine ls_inertia_i

      subroutine ls_free_i(this)
         import :: linsolver_t
         class(linsolver_t), intent(inout) :: this
      end subroutine ls_free_i

   end interface

   !> ------------------------------------------------------------------------
   !> Profil (skyline) LDL^T
   !>
   !> A = U^T D U,  U birim üst üçgen.
   !>
   !> Depolama: her j sütunu için, sütundaki ilk sıfır olmayan satır
   !> `jmin(j)`'den köşegene kadar olan girdiler paketli tutulur.
   !> `dptr(j)` köşegen girdinin `val` içindeki konumudur; A(i,j) girdisi
   !> `dptr(j) - (j - i)` konumundadır.
   !>
   !> Basit ve bariz doğru olması bilinçlidir. Başarım hedefi v0.4'tedir.
   !> ------------------------------------------------------------------------
   type, extends(linsolver_t) :: skyline_ldlt_t
      !> Sütun başına en küçük satır indisi.
      integer(ip), allocatable :: jmin(:)
      !> Köşegen girdilerin konumu.
      integer(ip), allocatable :: dptr(:)
      !> Paketli değerler; ayrıştırma sonrası U ve D'yi taşır.
      real(dp), allocatable :: val(:)
      !> Ayrıştırma çalışma alanı.
      real(dp), allocatable :: work(:)
      !> Pivot eşiği için matris ölçeği.
      real(dp) :: scale = 1.0_dp
   contains
      procedure :: analyse => sky_analyse
      procedure :: factorize => sky_factorize
      procedure :: solve => sky_solve
      procedure :: inertia => sky_inertia
      procedure :: free => sky_free
   end type skyline_ldlt_t

   !> Pivot, matris ölçeğinin bu katından küçükse tekil sayılır.
   real(dp), parameter :: PIVOT_REL_TOL = 1.0e-14_dp

contains

   !> Deseni inceler ve profili kurar.
   !>
   !> A yalnızca üst üçgeni saklıyor olabilir (sym = .true.) veya tamamını;
   !> her iki durumda da profil, (i,j) ve (j,i) girdilerinin birleşiminden
   !> çıkarılır -- simetrik bir matrisin profili simetriktir.
   subroutine sky_analyse(this, A, stat)
      class(skyline_ldlt_t), intent(inout) :: this
      type(sparse_csr_t), intent(in) :: A
      integer(ip), intent(out) :: stat

      integer(ip) :: n, i, j, k, total

      stat = DES_LIN_BAD_ARG
      call this%free()

      if (.not. A%analysed) then
         stat = DES_LIN_NOT_ANALYSED
         return
      end if
      n = A%n
      if (n < 1_ip) return

      allocate (this%jmin(n), this%dptr(n))
      do j = 1_ip, n
         this%jmin(j) = j
      end do

      !> Profil: her sütunun en yüksek girdisi.
      do i = 1_ip, n
         do k = A%row_ptr(i), A%row_ptr(i + 1_ip) - 1_ip
            j = A%col_idx(k)
            if (j >= i) then
               if (i < this%jmin(j)) this%jmin(j) = i
            else
               !> Alt üçgen girdisi: simetri gereği (j,i) de vardır.
               if (j < this%jmin(i)) this%jmin(i) = j
            end if
         end do
      end do

      total = 0_ip
      do j = 1_ip, n
         total = total + (j - this%jmin(j) + 1_ip)
         this%dptr(j) = total
      end do

      allocate (this%val(total), this%work(n))
      this%val = 0.0_dp
      this%work = 0.0_dp

      this%n = n
      this%name = 'skyline_ldlt'
      this%analysed = .true.
      this%factored = .false.
      stat = DES_LIN_OK
   end subroutine sky_analyse

   !> Değerleri profile topla ve LDL^T ayrıştırmasını yap.
   subroutine sky_factorize(this, A, stat)
      class(skyline_ldlt_t), intent(inout) :: this
      type(sparse_csr_t), intent(in) :: A
      integer(ip), intent(out) :: stat

      integer(ip) :: n, i, j, k, kk, kstart, pos
      real(dp) :: s, piv, tol

      stat = DES_LIN_BAD_ARG
      if (.not. this%analysed) then
         stat = DES_LIN_NOT_ANALYSED
         return
      end if
      if (A%n /= this%n) return

      n = this%n
      this%val = 0.0_dp
      this%factored = .false.

      !> Üst üçgeni topla.
      this%scale = 0.0_dp
      do i = 1_ip, n
         do k = A%row_ptr(i), A%row_ptr(i + 1_ip) - 1_ip
            j = A%col_idx(k)
            if (j < i) cycle
            pos = this%dptr(j) - (j - i)
            this%val(pos) = this%val(pos) + A%val(k)
            this%scale = max(this%scale, abs(A%val(k)))
         end do
      end do

      if (this%scale <= 0.0_dp) then
         stat = DES_LIN_ZERO_PIVOT
         return
      end if
      tol = PIVOT_REL_TOL*this%scale

      !> LDL^T, sütun sütun.
      do j = 1_ip, n
         !> work(i) = D(i) * U(i,j)
         do i = this%jmin(j), j - 1_ip
            s = this%val(this%dptr(j) - (j - i))
            kstart = max(this%jmin(i), this%jmin(j))
            do kk = kstart, i - 1_ip
               s = s - this%val(this%dptr(i) - (i - kk))*this%work(kk)
            end do
            this%work(i) = s
            this%val(this%dptr(j) - (j - i)) = s/this%val(this%dptr(i))
         end do

         s = this%val(this%dptr(j))
         do i = this%jmin(j), j - 1_ip
            s = s - this%val(this%dptr(j) - (j - i))*this%work(i)
         end do

         piv = s
         if (abs(piv) <= tol) then
            stat = DES_LIN_ZERO_PIVOT
            return
         end if
         this%val(this%dptr(j)) = piv
      end do

      this%factored = .true.
      stat = DES_LIN_OK
   end subroutine sky_factorize

   !> A x = b.
   subroutine sky_solve(this, b, x, stat)
      class(skyline_ldlt_t), intent(in) :: this
      real(dp), intent(in) :: b(:)
      real(dp), intent(out) :: x(:)
      integer(ip), intent(out) :: stat

      integer(ip) :: n, i, j

      stat = DES_LIN_BAD_ARG
      if (.not. this%factored) then
         stat = DES_LIN_NOT_FACTORED
         return
      end if
      n = this%n
      if (int(size(b), ip) /= n .or. int(size(x), ip) /= n) return

      x = b

      !> İleri yerine koyma: U^T y = b
      do j = 1_ip, n
         do i = this%jmin(j), j - 1_ip
            x(j) = x(j) - this%val(this%dptr(j) - (j - i))*x(i)
         end do
      end do

      !> Köşegen
      do j = 1_ip, n
         x(j) = x(j)/this%val(this%dptr(j))
      end do

      !> Geri yerine koyma: U x = z
      do j = n, 2_ip, -1_ip
         do i = this%jmin(j), j - 1_ip
            x(i) = x(i) - this%val(this%dptr(j) - (j - i))*x(j)
         end do
      end do

      stat = DES_LIN_OK
   end subroutine sky_solve

   subroutine sky_inertia(this, n_pos, n_neg, n_zero, stat)
      class(skyline_ldlt_t), intent(in) :: this
      integer(ip), intent(out) :: n_pos, n_neg, n_zero
      integer(ip), intent(out) :: stat

      integer(ip) :: j
      real(dp) :: d, tol

      n_pos = 0_ip
      n_neg = 0_ip
      n_zero = 0_ip
      stat = DES_LIN_NOT_FACTORED
      if (.not. this%factored) return

      tol = PIVOT_REL_TOL*this%scale
      do j = 1_ip, this%n
         d = this%val(this%dptr(j))
         if (d > tol) then
            n_pos = n_pos + 1_ip
         else if (d < -tol) then
            n_neg = n_neg + 1_ip
         else
            n_zero = n_zero + 1_ip
         end if
      end do

      stat = DES_LIN_OK
   end subroutine sky_inertia

   subroutine sky_free(this)
      class(skyline_ldlt_t), intent(inout) :: this

      if (allocated(this%jmin)) deallocate (this%jmin)
      if (allocated(this%dptr)) deallocate (this%dptr)
      if (allocated(this%val)) deallocate (this%val)
      if (allocated(this%work)) deallocate (this%work)
      this%n = 0_ip
      this%analysed = .false.
      this%factored = .false.
   end subroutine sky_free

end module des_linsolve
