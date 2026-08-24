!> ---------------------------------------------------------------------------
!> des_sparse -- CSR seyrek matris, montaj ve RCM sıralaması
!>
!> SEMBOLİK YAPI İLE SAYISAL DEĞERLERİN AYRILMASI
!>
!> Bir ağ için seyrek desen SABİTTİR: hangi satırda hangi sütunların
!> bulunduğu, düğüm bağlantılarından belirlenir ve Newton yinelemeleri
!> boyunca değişmez. Değişen yalnızca sayılardır.
!>
!> Bu yüzden arayüz ikiye ayrılmıştır:
!>
!>   analyse(...)   -> deseni BİR KEZ kurar (satır işaretçileri, sütun
!>                     indisleri, sıralama). Pahalı kısım budur.
!>   zero() + add() -> her Newton adımında yalnızca değerleri yazar.
!>
!> Deseni her yinelemede yeniden hesaplamak, tipik bir analizde toplam
!> sürenin baskın kalemi olurdu. Ayrım arayüzde zorunlu tutuluyor ki
!> kimse yanlışlıkla öteki yolu seçmesin.
!>
!> SİMETRİ
!>
!> Depolama iki kipte çalışır:
!>   sym = .false. -> bütün sıfır olmayanlar saklanır
!>   sym = .true.  -> yalnızca üst üçgen (köşegen dâhil) saklanır
!>
!> Hiperelastisitede tanjant simetriktir; sürtünmeli temas (v1.x)
!> geldiğinde simetri kaybolacağı için iki kip baştan destekleniyor.
!>
!> Katman: 5 -- Sayısal temel
!> ---------------------------------------------------------------------------
module des_sparse
   use des_kinds, only: dp, ip
   implicit none
   private

   public :: DES_SPM_OK, DES_SPM_BAD_ARG, DES_SPM_NOT_ANALYSED
   public :: DES_SPM_NO_ENTRY, DES_SPM_FULL
   public :: sparse_csr_t, rcm_order, bandwidth

   !> İşlem başarılı.
   integer(ip), parameter :: DES_SPM_OK = 0_ip
   !> Geçersiz argüman.
   integer(ip), parameter :: DES_SPM_BAD_ARG = 1_ip
   !> Desen kurulmadan değer yazılmaya çalışıldı.
   integer(ip), parameter :: DES_SPM_NOT_ANALYSED = 2_ip
   !> Desende olmayan bir konuma yazılmaya çalışıldı.
   integer(ip), parameter :: DES_SPM_NO_ENTRY = 3_ip
   !> Kapasite doldu.
   integer(ip), parameter :: DES_SPM_FULL = 4_ip

   !> ------------------------------------------------------------------------
   !> CSR (Compressed Sparse Row) matris
   !> ------------------------------------------------------------------------
   type :: sparse_csr_t
      !> Satır sayısı (= sütun sayısı; matris kare).
      integer(ip) :: n = 0_ip
      !> Sıfır olmayan eleman sayısı.
      integer(ip) :: nnz = 0_ip
      !> Yalnızca üst üçgen saklanıyor mu.
      logical :: sym = .false.
      !> Satır başlangıç işaretçileri (n+1).
      integer(ip), allocatable :: row_ptr(:)
      !> Sütun indisleri (nnz), satır içinde ARTAN sırada.
      integer(ip), allocatable :: col_idx(:)
      !> Sayısal değerler (nnz).
      real(dp), allocatable :: val(:)
      !> Desen kuruldu mu.
      logical :: analysed = .false.
   contains
      procedure :: analyse => csr_analyse
      procedure :: zero => csr_zero
      procedure :: add => csr_add
      procedure :: add_block => csr_add_block
      procedure :: get => csr_get
      procedure :: bandwidth => csr_bandwidth
      procedure :: free => csr_free
   end type sparse_csr_t

contains

   ! =========================================================================
   ! Sembolik asama
   ! =========================================================================

   !> Deseni eleman DOF listelerinden kurar.
   !>
   !> `elem_dofs(:, e)` e. elemanın dokunduğu serbestlikler, `n_of(e)`
   !> tanesi geçerli (kalanı 0). Her eleman kendi serbestlikleri arasında
   !> tam bağlantı üretir; bu, sertlik matrisinin doğal desenidir.
   !>
   !> `perm` verilirse yeni sıra olarak uygulanır: `perm(i)` = eski
   !> numarası i olan serbestliğin YENİ numarası. RCM çıktısı doğrudan
   !> buraya verilebilir.
   subroutine csr_analyse(this, n, elem_dofs, n_of, sym, perm, stat)
      class(sparse_csr_t), intent(inout) :: this
      integer(ip), intent(in) :: n
      integer(ip), intent(in) :: elem_dofs(:, :)
      integer(ip), intent(in) :: n_of(:)
      logical, intent(in) :: sym
      integer(ip), intent(in), optional :: perm(:)
      integer(ip), intent(out) :: stat

      integer(ip), allocatable :: cnt(:), work(:, :), wn(:)
      integer(ip) :: ne, e, a, b, i, j, k, r, c, cap, pos
      logical :: found

      stat = DES_SPM_BAD_ARG
      if (n < 1_ip) return
      ne = int(size(n_of), ip)
      if (ne < 0_ip) return
      if (present(perm)) then
         if (int(size(perm), ip) /= n) return
      end if

      !> Satır başına kaç farklı sütun olabileceğini kabaca sınırla:
      !> bir serbestliğin komşusu, ona dokunan elemanların serbestlik
      !> sayıları toplamını aşamaz.
      allocate (cnt(n))
      cnt = 0_ip
      do e = 1_ip, ne
         do a = 1_ip, n_of(e)
            r = map_dof(elem_dofs(a, e), perm)
            if (r < 1_ip .or. r > n) cycle
            cnt(r) = cnt(r) + n_of(e)
         end do
      end do
      cap = max(1_ip, maxval(cnt))

      allocate (work(cap, n))
      allocate (wn(n))
      work = 0_ip
      wn = 0_ip

      !> Köşegen her zaman desende olsun -- doğrudan çözücüler bunu bekler.
      do i = 1_ip, n
         wn(i) = 1_ip
         work(1, i) = i
      end do

      do e = 1_ip, ne
         do a = 1_ip, n_of(e)
            r = map_dof(elem_dofs(a, e), perm)
            if (r < 1_ip .or. r > n) cycle
            do b = 1_ip, n_of(e)
               c = map_dof(elem_dofs(b, e), perm)
               if (c < 1_ip .or. c > n) cycle
               if (sym .and. c < r) cycle

               found = .false.
               do k = 1_ip, wn(r)
                  if (work(k, r) == c) then
                     found = .true.
                     exit
                  end if
               end do
               if (found) cycle

               if (wn(r) >= cap) then
                  stat = DES_SPM_FULL
                  return
               end if
               wn(r) = wn(r) + 1_ip
               work(wn(r), r) = c
            end do
         end do
      end do

      !> Satır içi sütunları artan sıraya sok (ekleme sıralaması; satırlar
      !> kısadır, karmaşıklık pratikte sorun değil).
      do i = 1_ip, n
         call sort_int(work(1:wn(i), i))
      end do

      call this%free()

      this%n = n
      this%sym = sym
      this%nnz = sum(wn)

      allocate (this%row_ptr(n + 1_ip))
      allocate (this%col_idx(this%nnz))
      allocate (this%val(this%nnz))

      pos = 1_ip
      do i = 1_ip, n
         this%row_ptr(i) = pos
         do j = 1_ip, wn(i)
            this%col_idx(pos) = work(j, i)
            pos = pos + 1_ip
         end do
      end do
      this%row_ptr(n + 1_ip) = pos

      this%val = 0.0_dp
      this%analysed = .true.
      stat = DES_SPM_OK
   end subroutine csr_analyse

   !> Sıra dönüşümü; `perm` yoksa birim.
   pure function map_dof(i, perm) result(j)
      integer(ip), intent(in) :: i
      integer(ip), intent(in), optional :: perm(:)
      integer(ip) :: j

      j = i
      if (.not. present(perm)) return
      if (i < 1_ip .or. i > int(size(perm), ip)) then
         j = 0_ip
         return
      end if
      j = perm(i)
   end function map_dof

   !> Küçük tamsayı dizisi için ekleme sıralaması.
   pure subroutine sort_int(a)
      integer(ip), intent(inout) :: a(:)
      integer(ip) :: i, j, key

      do i = 2_ip, int(size(a), ip)
         key = a(i)
         j = i - 1_ip
         do while (j >= 1_ip)
            if (a(j) <= key) exit
            a(j + 1_ip) = a(j)
            j = j - 1_ip
         end do
         a(j + 1_ip) = key
      end do
   end subroutine sort_int

   ! =========================================================================
   ! Sayisal asama
   ! =========================================================================

   !> Değerleri sıfırlar; deseni KORUR. Her Newton adımının başında çağrılır.
   subroutine csr_zero(this)
      class(sparse_csr_t), intent(inout) :: this

      if (allocated(this%val)) this%val = 0.0_dp
   end subroutine csr_zero

   !> Tek bir konuma değer ekler (montaj toplaması).
   !>
   !> Simetrik kipte alt üçgene yapılan yazma, karşılık gelen üst üçgen
   !> konumuna yönlendirilir. Bu, çağıranın simetri muhasebesi yapmasını
   !> gereksiz kılar.
   subroutine csr_add(this, i, j, v, stat)
      class(sparse_csr_t), intent(inout) :: this
      integer(ip), intent(in) :: i
      integer(ip), intent(in) :: j
      real(dp), intent(in) :: v
      integer(ip), intent(out) :: stat

      integer(ip) :: r, c, k

      stat = DES_SPM_BAD_ARG
      if (.not. this%analysed) then
         stat = DES_SPM_NOT_ANALYSED
         return
      end if
      if (i < 1_ip .or. i > this%n) return
      if (j < 1_ip .or. j > this%n) return

      r = i
      c = j
      if (this%sym .and. c < r) then
         r = j
         c = i
      end if

      do k = this%row_ptr(r), this%row_ptr(r + 1_ip) - 1_ip
         if (this%col_idx(k) == c) then
            this%val(k) = this%val(k) + v
            stat = DES_SPM_OK
            return
         end if
      end do

      stat = DES_SPM_NO_ENTRY
   end subroutine csr_add

   !> Yoğun bir eleman bloğunu global matrise dağıtır.
   !>
   !> `dofs(1:nd)` blok satır/sütunlarının global numaraları. Eleman
   !> K_uu, K_ug, K_gg bloklarının tamamı tek bir yoğun blok olarak
   !> verilebilir: eleman DOF listesi zaten globalleri sona alır
   !> (des_mesh%element_dofs), dolayısıyla blok yapısı kendiliğinden
   !> doğru yere düşer.
   subroutine csr_add_block(this, dofs, nd, ke, stat)
      class(sparse_csr_t), intent(inout) :: this
      integer(ip), intent(in) :: dofs(:)
      integer(ip), intent(in) :: nd
      real(dp), intent(in) :: ke(:, :)
      integer(ip), intent(out) :: stat

      integer(ip) :: a, b, st

      stat = DES_SPM_BAD_ARG
      if (nd < 1_ip) return
      if (int(size(dofs), ip) < nd) return
      if (int(size(ke, 1), ip) < nd .or. int(size(ke, 2), ip) < nd) return

      do a = 1_ip, nd
         do b = 1_ip, nd
            if (this%sym .and. dofs(b) < dofs(a)) cycle
            call this%add(dofs(a), dofs(b), ke(a, b), st)
            if (st /= DES_SPM_OK) then
               stat = st
               return
            end if
         end do
      end do

      stat = DES_SPM_OK
   end subroutine csr_add_block

   !> Bir konumun değeri; desende yoksa 0. Simetrik kipte alt üçgen
   !> sorgusu üst üçgene yönlendirilir.
   pure function csr_get(this, i, j) result(v)
      class(sparse_csr_t), intent(in) :: this
      integer(ip), intent(in) :: i
      integer(ip), intent(in) :: j
      real(dp) :: v

      integer(ip) :: r, c, k

      v = 0.0_dp
      if (.not. this%analysed) return
      if (i < 1_ip .or. i > this%n) return
      if (j < 1_ip .or. j > this%n) return

      r = i
      c = j
      if (this%sym .and. c < r) then
         r = j
         c = i
      end if

      do k = this%row_ptr(r), this%row_ptr(r + 1_ip) - 1_ip
         if (this%col_idx(k) == c) then
            v = this%val(k)
            return
         end if
      end do
   end function csr_get

   !> Desenin bant genişliği: max |i - j|.
   pure function csr_bandwidth(this) result(bw)
      class(sparse_csr_t), intent(in) :: this
      integer(ip) :: bw
      integer(ip) :: i, k

      bw = 0_ip
      if (.not. this%analysed) return
      do i = 1_ip, this%n
         do k = this%row_ptr(i), this%row_ptr(i + 1_ip) - 1_ip
            bw = max(bw, abs(i - this%col_idx(k)))
         end do
      end do
   end function csr_bandwidth

   subroutine csr_free(this)
      class(sparse_csr_t), intent(inout) :: this

      if (allocated(this%row_ptr)) deallocate (this%row_ptr)
      if (allocated(this%col_idx)) deallocate (this%col_idx)
      if (allocated(this%val)) deallocate (this%val)
      this%n = 0_ip
      this%nnz = 0_ip
      this%analysed = .false.
   end subroutine csr_free

   ! =========================================================================
   ! RCM siralamasi
   ! =========================================================================

   !> Bir bitişiklik listesinin bant genişliği (serbest fonksiyon).
   pure function bandwidth(adj, adj_n) result(bw)
      integer(ip), intent(in) :: adj(:, :)
      integer(ip), intent(in) :: adj_n(:)
      integer(ip) :: bw
      integer(ip) :: i, k

      bw = 0_ip
      do i = 1_ip, int(size(adj_n), ip)
         do k = 1_ip, adj_n(i)
            bw = max(bw, abs(i - adj(k, i)))
         end do
      end do
   end function bandwidth

   !> Ters Cuthill-McKee sıralaması.
   !>
   !> Dolgu (fill-in) azaltmak için bant genişliğini küçültür. Çıktı
   !> `perm(i)` = eski numarası i olan serbestliğin YENİ numarasıdır;
   !> `csr_analyse`ın `perm` argümanına doğrudan verilebilir.
   !>
   !> Başlangıç düğümü olarak en düşük dereceli düğüm seçilir. Bu, sözde
   !> çevresel (pseudo-peripheral) düğüm aramasının ucuz bir yaklaşımıdır;
   !> George-Liu araması daha iyi sonuç verir ama v0.3'e kadar gerekmez.
   subroutine rcm_order(adj, adj_n, perm, stat)
      integer(ip), intent(in)  :: adj(:, :)
      integer(ip), intent(in)  :: adj_n(:)
      integer(ip), intent(out) :: perm(:)
      integer(ip), intent(out) :: stat

      integer(ip), allocatable :: order(:), deg(:), nbr(:)
      logical, allocatable :: seen(:)
      integer(ip) :: n, i, k, head, tail, v, w, nn, start, cnt

      stat = DES_SPM_BAD_ARG
      n = int(size(adj_n), ip)
      if (n < 1_ip) return
      if (int(size(perm), ip) /= n) return

      allocate (order(n), deg(n), seen(n), nbr(max(1_ip, maxval(adj_n))))
      seen = .false.
      do i = 1_ip, n
         deg(i) = adj_n(i)
      end do

      cnt = 0_ip

      !> Bağlantısız bileşenler olabilir; hepsini dolaş.
      do
         !> Görülmemişler arasında en düşük dereceli düğümü seç.
         start = 0_ip
         do i = 1_ip, n
            if (seen(i)) cycle
            if (start == 0_ip) then
               start = i
            else if (deg(i) < deg(start)) then
               start = i
            end if
         end do
         if (start == 0_ip) exit

         head = cnt + 1_ip
         cnt = cnt + 1_ip
         order(cnt) = start
         seen(start) = .true.

         tail = cnt
         do while (head <= tail)
            v = order(head)
            head = head + 1_ip

            !> v'nin görülmemiş komşularını dereceye göre artan sırada ekle.
            nn = 0_ip
            do k = 1_ip, adj_n(v)
               w = adj(k, v)
               if (w < 1_ip .or. w > n) cycle
               if (seen(w)) cycle
               nn = nn + 1_ip
               nbr(nn) = w
               seen(w) = .true.
            end do
            call sort_by_degree(nbr(1:nn), deg)
            do k = 1_ip, nn
               cnt = cnt + 1_ip
               order(cnt) = nbr(k)
            end do
            tail = cnt
         end do
      end do

      !> Cuthill-McKee sırasını TERSLE -- RCM'i RCM yapan adım budur.
      do i = 1_ip, n
         perm(order(i)) = n - i + 1_ip
      end do

      stat = DES_SPM_OK
   end subroutine rcm_order

   pure subroutine sort_by_degree(a, deg)
      integer(ip), intent(inout) :: a(:)
      integer(ip), intent(in) :: deg(:)
      integer(ip) :: i, j, key

      do i = 2_ip, int(size(a), ip)
         key = a(i)
         j = i - 1_ip
         do while (j >= 1_ip)
            if (deg(a(j)) <= deg(key)) exit
            a(j + 1_ip) = a(j)
            j = j - 1_ip
         end do
         a(j + 1_ip) = key
      end do
   end subroutine sort_by_degree

end module des_sparse
