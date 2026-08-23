!> ---------------------------------------------------------------------------
!> des_mesh -- düğüm/eleman dizileri ve serbestlik derecesi haritası
!>
!> Bu modül ağ ÜRETMEZ; ağ üretimi katman 3'ün (C++) işidir. Burada
!> yalnızca çözücünün ihtiyaç duyduğu topoloji ve DOF muhasebesi tutulur.
!>
!> DOF HARİTASININ İKİ PARÇASI
!>
!>   1. Düğüm serbestlikleri -- düğüm başına DEĞİŞKEN sayıda (2 veya 3).
!>      Eksenel simetride 2 (u_r, u_z), burulma eklendiğinde 3
!>      (u_r, u_z, u_theta).
!>
!>   2. Eleman-dışı GLOBAL serbestlikler -- hiçbir düğüme ait olmayan,
!>      modelin tamamına ait serbestlikler. Genelleştirilmiş düzlem şekil
!>      değiştirmede eksenel uzama, burulmalı hâlinde ayrıca birim boy
!>      başına dönme.
!>
!> GLOBAL DOF PAYLAŞIMI -- BU MODÜLÜN EN KRİTİK SORUMLULUĞU
!>
!> Global serbestlikler bütün elemanlar arasında PAYLAŞILIR. A elemanının
!> 1. global DOF'u ile B elemanınınki AYNI serbestliktir. Her elemana ayrı
!> bir serbestlik verilirse model sessizce yanlış çözülür: eksenel uzama
!> eleman başına bağımsız olur, denge sağlanır ama fizik yanlıştır.
!>
!> Bu yüzden global serbestlikler `register_global_dof` ile ANAHTAR
!> üzerinden kaydedilir; aynı anahtarı isteyen her eleman aynı indisi alır.
!> Ayrıntı: ADR 0009 (b).
!>
!> Katman: 4 -- Analiz çekirdeği
!> ---------------------------------------------------------------------------
module des_mesh
   use des_kinds, only: dp, ip
   implicit none
   private

   public :: DES_MESH_OK, DES_MESH_BAD_ARG, DES_MESH_NOT_BUILT, DES_MESH_FULL
   public :: DES_GDOF_AXIAL_STRETCH, DES_GDOF_TWIST, DES_MAX_GLOBAL_DOF
   public :: mesh_t, node_group_t

   ! --- Durum kodları -------------------------------------------------------
   !> İşlem başarılı.
   integer(ip), parameter :: DES_MESH_OK = 0_ip
   !> Geçersiz argüman (boyut uyuşmazlığı, aralık dışı indis).
   integer(ip), parameter :: DES_MESH_BAD_ARG = 1_ip
   !> DOF haritası henüz kurulmadı (`build_dof_map` çağrılmadı).
   integer(ip), parameter :: DES_MESH_NOT_BUILT = 2_ip
   !> Kapasite doldu.
   integer(ip), parameter :: DES_MESH_FULL = 3_ip

   ! --- Global serbestlik anahtarları ---------------------------------------
   !> Genelleştirilmiş düzlem şekil değiştirmede eksenel uzama.
   integer(ip), parameter :: DES_GDOF_AXIAL_STRETCH = 1_ip
   !> Birim boy başına dönme (burulmalı GPS).
   integer(ip), parameter :: DES_GDOF_TWIST = 2_ip
   !> Desteklenen global serbestlik sayısı üst sınırı.
   integer(ip), parameter :: DES_MAX_GLOBAL_DOF = 2_ip

   !> ------------------------------------------------------------------------
   !> Sınır koşulu için düğüm veya kenar grubu
   !>
   !> Şimdilik yalnızca düğüm listesi tutar. v0.3'te geometriye (DXF/spline
   !> kenarlarına) bağlanacak; o zaman buraya bir geometri tutamacı eklenir
   !> ve mevcut kullanım kırılmaz.
   !> ------------------------------------------------------------------------
   type :: node_group_t
      !> Grup anahtarı. Kullanıcıya gösterilecek metin DEĞİL; çeviri
      !> tablosunun ve girdi dosyasının anahtarıdır. ASCII kalır.
      character(len=32) :: name = ''
      !> Gruba ait düğüm numaraları.
      integer(ip), allocatable :: nodes(:)
   end type node_group_t

   !> ------------------------------------------------------------------------
   !> Ağ ve serbestlik derecesi haritası
   !> ------------------------------------------------------------------------
   type :: mesh_t
      !> Düğüm koordinatları (2, n_node). Eksenel simetride (r, z).
      real(dp), allocatable :: coord(:, :)
      !> Eleman-düğüm bağlantıları (max_node_per_elem, n_elem).
      !> Kullanılmayan yuvalar 0'dır; farklı düğüm sayılı elemanlar
      !> aynı dizide yaşayabilsin diye.
      integer(ip), allocatable :: conn(:, :)
      !> Eleman başına gerçek düğüm sayısı (n_elem).
      integer(ip), allocatable :: n_node_of(:)
      !> Düğüm başına serbestlik sayısı (n_node). Değişken olabilir.
      integer(ip), allocatable :: ndof_of(:)
      !> Düğümün ilk serbestliğinin global numarası (n_node).
      integer(ip), allocatable :: node_dof0(:)
      !> Sınır koşulu grupları.
      type(node_group_t), allocatable :: groups(:)

      !> Kayıtlı global serbestlik anahtarları (DES_MAX_GLOBAL_DOF).
      integer(ip) :: gdof_key(DES_MAX_GLOBAL_DOF) = 0_ip
      !> Kayıtlı global serbestlik sayısı.
      integer(ip) :: n_gdof = 0_ip

      !> Düğüm serbestliklerinin toplamı.
      integer(ip) :: n_node_dof = 0_ip
      !> Toplam serbestlik = n_node_dof + n_gdof.
      integer(ip) :: n_dof = 0_ip
      !> DOF haritası kuruldu mu.
      logical :: built = .false.
   contains
      procedure :: init => mesh_init
      procedure :: set_node_dof => mesh_set_node_dof
      procedure :: register_global_dof => mesh_register_global_dof
      procedure :: build_dof_map => mesh_build_dof_map
      procedure :: node_dof => mesh_node_dof
      procedure :: global_dof => mesh_global_dof
      procedure :: n_node => mesh_n_node
      procedure :: n_elem => mesh_n_elem
      procedure :: element_dofs => mesh_element_dofs
   end type mesh_t

contains

   !> Ağı verilen boyutlarla kurar. Düğüm başına serbestlik sayısı
   !> `ndof_default` ile başlar; `set_node_dof` ile düğüm bazında
   !> değiştirilebilir.
   subroutine mesh_init(this, n_node, n_elem, max_node_per_elem, &
                        ndof_default, stat)
      class(mesh_t), intent(inout) :: this
      integer(ip), intent(in)  :: n_node
      integer(ip), intent(in)  :: n_elem
      integer(ip), intent(in)  :: max_node_per_elem
      integer(ip), intent(in)  :: ndof_default
      integer(ip), intent(out) :: stat

      stat = DES_MESH_BAD_ARG
      if (n_node < 1_ip) return
      if (n_elem < 0_ip) return
      if (max_node_per_elem < 1_ip) return
      if (ndof_default < 1_ip) return

      if (allocated(this%coord)) deallocate (this%coord)
      if (allocated(this%conn)) deallocate (this%conn)
      if (allocated(this%n_node_of)) deallocate (this%n_node_of)
      if (allocated(this%ndof_of)) deallocate (this%ndof_of)
      if (allocated(this%node_dof0)) deallocate (this%node_dof0)

      allocate (this%coord(2, n_node))
      allocate (this%conn(max_node_per_elem, n_elem))
      allocate (this%n_node_of(n_elem))
      allocate (this%ndof_of(n_node))
      allocate (this%node_dof0(n_node))

      this%coord = 0.0_dp
      this%conn = 0_ip
      this%n_node_of = max_node_per_elem
      this%ndof_of = ndof_default
      this%node_dof0 = 0_ip

      this%gdof_key = 0_ip
      this%n_gdof = 0_ip
      this%n_node_dof = 0_ip
      this%n_dof = 0_ip
      this%built = .false.

      stat = DES_MESH_OK
   end subroutine mesh_init

   !> Tek bir düğümün serbestlik sayısını değiştirir. DOF haritası varsa
   !> geçersizleşir; yeniden kurulması gerekir.
   subroutine mesh_set_node_dof(this, inode, ndof, stat)
      class(mesh_t), intent(inout) :: this
      integer(ip), intent(in)  :: inode
      integer(ip), intent(in)  :: ndof
      integer(ip), intent(out) :: stat

      stat = DES_MESH_BAD_ARG
      if (.not. allocated(this%ndof_of)) return
      if (inode < 1_ip .or. inode > int(size(this%ndof_of), ip)) return
      if (ndof < 1_ip) return

      this%ndof_of(inode) = ndof
      this%built = .false.
      stat = DES_MESH_OK
   end subroutine mesh_set_node_dof

   !> Bir global serbestliği ANAHTARIYLA kaydeder ve indisini döndürür.
   !>
   !> AYNI ANAHTARLA İKİNCİ ÇAĞRI YENİ SERBESTLİK AÇMAZ; ilk kaydın
   !> indisini döndürür. Global serbestlikler bütün elemanlarca
   !> paylaşıldığı için doğru davranış budur (ADR 0009 b). Her eleman
   !> kurulumunda çağrılabilir olması bilinçlidir: eleman "bana bir eksenel
   !> uzama serbestliği lazım" der, ağ ona ortak olanın indisini verir.
   subroutine mesh_register_global_dof(this, key, idx, stat)
      class(mesh_t), intent(inout) :: this
      integer(ip), intent(in)  :: key
      integer(ip), intent(out) :: idx
      integer(ip), intent(out) :: stat

      integer(ip) :: i

      idx = 0_ip
      stat = DES_MESH_BAD_ARG
      if (key < 1_ip) return

      !> Zaten kayıtlı mı.
      do i = 1_ip, this%n_gdof
         if (this%gdof_key(i) == key) then
            idx = i
            stat = DES_MESH_OK
            return
         end if
      end do

      if (this%n_gdof >= DES_MAX_GLOBAL_DOF) then
         stat = DES_MESH_FULL
         return
      end if

      this%n_gdof = this%n_gdof + 1_ip
      this%gdof_key(this%n_gdof) = key
      idx = this%n_gdof
      this%built = .false.
      stat = DES_MESH_OK
   end subroutine mesh_register_global_dof

   !> Serbestlik derecesi haritasını kurar.
   !>
   !> Numaralandırma: önce bütün düğüm serbestlikleri (düğüm sırasıyla),
   !> sonra global serbestlikler. Globallerin SONA konması bilinçlidir --
   !> yoğun global satırlar/sütunlar seyrek matrisin sonunda toplanır ve
   !> bant yapısını bozmaz.
   subroutine mesh_build_dof_map(this, stat)
      class(mesh_t), intent(inout) :: this
      integer(ip), intent(out) :: stat

      integer(ip) :: i, next

      stat = DES_MESH_BAD_ARG
      if (.not. allocated(this%ndof_of)) return

      next = 1_ip
      do i = 1_ip, int(size(this%ndof_of), ip)
         this%node_dof0(i) = next
         next = next + this%ndof_of(i)
      end do

      this%n_node_dof = next - 1_ip
      this%n_dof = this%n_node_dof + this%n_gdof
      this%built = .true.
      stat = DES_MESH_OK
   end subroutine mesh_build_dof_map

   !> Bir düğümün k. serbestliğinin global numarası; hata hâlinde 0.
   pure function mesh_node_dof(this, inode, k) result(idof)
      class(mesh_t), intent(in) :: this
      integer(ip), intent(in) :: inode
      integer(ip), intent(in) :: k
      integer(ip) :: idof

      idof = 0_ip
      if (.not. this%built) return
      if (inode < 1_ip .or. inode > int(size(this%ndof_of), ip)) return
      if (k < 1_ip .or. k > this%ndof_of(inode)) return

      idof = this%node_dof0(inode) + k - 1_ip
   end function mesh_node_dof

   !> Kayıtlı global serbestliğin global numarası; hata hâlinde 0.
   pure function mesh_global_dof(this, idx) result(idof)
      class(mesh_t), intent(in) :: this
      integer(ip), intent(in) :: idx
      integer(ip) :: idof

      idof = 0_ip
      if (.not. this%built) return
      if (idx < 1_ip .or. idx > this%n_gdof) return

      idof = this%n_node_dof + idx
   end function mesh_global_dof

   pure function mesh_n_node(this) result(n)
      class(mesh_t), intent(in) :: this
      integer(ip) :: n
      n = 0_ip
      if (allocated(this%ndof_of)) n = int(size(this%ndof_of), ip)
   end function mesh_n_node

   pure function mesh_n_elem(this) result(n)
      class(mesh_t), intent(in) :: this
      integer(ip) :: n
      n = 0_ip
      if (allocated(this%n_node_of)) n = int(size(this%n_node_of), ip)
   end function mesh_n_elem

   !> Bir elemanın dokunduğu bütün serbestlikleri sırayla toplar:
   !> önce düğüm serbestlikleri, sonra `gdof_ids` ile istenen globaller.
   !>
   !> `gdof_ids` elemanın `cfg%global_dof_ids` alanıdır; sıfır olanlar
   !> atlanır. Bu, montajın global blokları doğru yere koymasını sağlar.
   subroutine mesh_element_dofs(this, ielem, gdof_ids, dofs, n_out, stat)
      class(mesh_t), intent(in) :: this
      integer(ip), intent(in)  :: ielem
      integer(ip), intent(in)  :: gdof_ids(:)
      integer(ip), intent(out) :: dofs(:)
      integer(ip), intent(out) :: n_out
      integer(ip), intent(out) :: stat

      integer(ip) :: a, k, nd, inode, idof

      n_out = 0_ip
      stat = DES_MESH_BAD_ARG
      if (.not. this%built) then
         stat = DES_MESH_NOT_BUILT
         return
      end if
      if (ielem < 1_ip .or. ielem > this%n_elem()) return

      nd = this%n_node_of(ielem)
      do a = 1_ip, nd
         inode = this%conn(a, ielem)
         if (inode < 1_ip) cycle
         do k = 1_ip, this%ndof_of(inode)
            n_out = n_out + 1_ip
            if (n_out > int(size(dofs), ip)) then
               n_out = 0_ip
               stat = DES_MESH_FULL
               return
            end if
            dofs(n_out) = this%node_dof(inode, k)
         end do
      end do

      do k = 1_ip, int(size(gdof_ids), ip)
         if (gdof_ids(k) < 1_ip) cycle
         idof = this%global_dof(gdof_ids(k))
         if (idof < 1_ip) cycle
         n_out = n_out + 1_ip
         if (n_out > int(size(dofs), ip)) then
            n_out = 0_ip
            stat = DES_MESH_FULL
            return
         end if
         dofs(n_out) = idof
      end do

      stat = DES_MESH_OK
   end subroutine mesh_element_dofs

end module des_mesh
