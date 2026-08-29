!> ---------------------------------------------------------------------------
!> des_bc -- sınır koşulları, yük eğrileri ve reaksiyon okuma
!>
!> ÖLÇEK KONVANSİYONU -- RADYAN BAŞINA
!>
!> `des_elem_axi_q4` hacim elemanını dV = R dA olarak alır; 2*pi çarpanı
!> YOKTUR. Bu modüldeki bütün yükler ve reaksiyonlar AYNI ölçektedir:
!> basınç kenar integrali de 2*pi taşımaz. Karışık konvansiyon, bu projede
!> en pahalı hata sınıfıdır; tek bir ölçek seçilip her yerde tutulur.
!>
!> Fiziksel (tam çevre) kuvvet isteniyorsa 2*pi ile çarpılır. Gerilme
!> hesaplarında çarpan sadeleşir: P = -sigma_rr = R_toplam / (a*L)
!> ifadesinde hem pay hem payda aynı ölçektedir.
!>
!> DİRICHLET UYGULAMA YÖNTEMİ: ELEME (satır/sütun sıfırlama)
!>
!> Penaltı DEĞİL. Gerekçe: penaltı yöntemi köşegene büyük bir sayı ekler
!> ve koşul sayısını bozar. Kauçukta K/mu ~ 1e5 olduğu için sistem zaten
!> kötü koşulludur; penaltı bunun üstüne binerdi. Eleme koşullanmaya hiç
!> dokunmaz.
!>
!> Uygulama biçimi: dayatılmış serbestliğin SATIRI VE SÜTUNU sıfırlanır,
!> köşegene 1 konur, sağ taraf o konumda sıfırlanır. Böylece matris
!> SİMETRİK kalır ve seyrek DESEN korunur (Newton içinde desen yeniden
!> kurulmaz). Newton düzeltmesi o serbestlikte tam olarak sıfır çıkar --
!> zaten u dayatılmış değerdedir.
!>
!> REAKSİYON
!>
!> Eleme MATRİSE uygulanır, ARTIĞA (residual) değil. Bu yüzden yakınsamış
!> durumda dayatılmış serbestlikteki artık doğrudan mesnet tepkisidir:
!>
!>    r = f_int - f_ext   =>   yakinsamada serbest DOF'larda r = 0
!>                             dayatilmis DOF'ta   r = R (reaksiyon)
!>
!> Bölüm D (kalın cidarlı silindir) basıncı bu reaksiyondan okur.
!>
!> Katman: 4 -- Analiz çekirdeği
!> ---------------------------------------------------------------------------
module des_bc
   use des_kinds, only: dp, ip
   use des_mesh, only: mesh_t
   use des_sparse, only: sparse_csr_t
   implicit none
   private

   public :: DES_BC_OK, DES_BC_BAD_ARG, DES_BC_FULL, DES_BC_NOT_BUILT
   public :: DES_LOAD_NODAL, DES_LOAD_PRESSURE
   public :: bc_set_t

   integer(ip), parameter :: DES_BC_OK = 0_ip
   integer(ip), parameter :: DES_BC_BAD_ARG = 1_ip
   integer(ip), parameter :: DES_BC_FULL = 2_ip
   integer(ip), parameter :: DES_BC_NOT_BUILT = 3_ip

   !> Düğüme doğrudan uygulanan kuvvet.
   integer(ip), parameter :: DES_LOAD_NODAL = 1_ip
   !> Kenar üzerinde yüzey basıncı.
   integer(ip), parameter :: DES_LOAD_PRESSURE = 2_ip

   !> ------------------------------------------------------------------------
   !> Dayatılmış yer değiştirme
   !> ------------------------------------------------------------------------
   type :: dirichlet_t
      integer(ip) :: node = 0_ip
      !> 1 = u_r, 2 = u_z, 3 = u_theta (v0.2)
      integer(ip) :: comp = 0_ip
      !> t = 1'deki tam değer; ara adımlarda eğriyle ölçeklenir.
      real(dp) :: value = 0.0_dp
      !> Yük eğrisi indisi; 0 = doğrusal rampa (çarpan = t).
      integer(ip) :: curve = 0_ip
   end type dirichlet_t

   !> ------------------------------------------------------------------------
   !> Dış yük
   !> ------------------------------------------------------------------------
   type :: neumann_t
      integer(ip) :: kind = DES_LOAD_NODAL
      !> DES_LOAD_NODAL için düğüm ve bileşen.
      integer(ip) :: node = 0_ip
      integer(ip) :: comp = 0_ip
      !> DES_LOAD_PRESSURE için kenarın iki düğümü.
      !>
      !> SIRALAMA ÖNEMLİ: dış normal, kenar teğetinin -90 derece
      !> döndürülmüşüdür; n = (dZ, -dR)/L. Eleman düğümleri saat yönünün
      !> tersine numaralandığında sınır da saat yönünün tersine dolaşılır
      !> ve bu kural dış normali verir.
      integer(ip) :: edge(2) = 0_ip
      real(dp) :: value = 0.0_dp
      integer(ip) :: curve = 0_ip
   end type neumann_t

   !> Parçalı doğrusal yük eğrisi.
   type :: load_curve_t
      real(dp), allocatable :: t(:)
      real(dp), allocatable :: v(:)
   end type load_curve_t

   !> ------------------------------------------------------------------------
   !> Sınır koşulu kümesi
   !> ------------------------------------------------------------------------
   type :: bc_set_t
      type(dirichlet_t), allocatable :: dir(:)
      integer(ip) :: n_dir = 0_ip
      type(neumann_t), allocatable :: neu(:)
      integer(ip) :: n_neu = 0_ip
      type(load_curve_t), allocatable :: curves(:)
      integer(ip) :: n_curve = 0_ip

      !> `build` sonrası kurulan DOF haritaları (n_dof).
      logical, allocatable :: fixed(:)
      real(dp), allocatable :: pres_val(:)
      integer(ip), allocatable :: pres_curve(:)
      logical :: built = .false.
   contains
      procedure :: init => bc_init
      procedure :: add_dirichlet => bc_add_dirichlet
      procedure :: add_dirichlet_nodes => bc_add_dirichlet_nodes
      procedure :: add_nodal_force => bc_add_nodal_force
      procedure :: add_pressure => bc_add_pressure
      procedure :: set_curve => bc_set_curve
      procedure :: build => bc_build
      procedure :: factor_at => bc_factor_at
      procedure :: apply_prescribed => bc_apply_prescribed
      procedure :: external_force => bc_external_force
      procedure :: constrain_matrix => bc_constrain_matrix
      procedure :: constrain_vector => bc_constrain_vector
      procedure :: reaction_sum => bc_reaction_sum
      procedure :: free_norm => bc_free_norm
   end type bc_set_t

contains

   subroutine bc_init(this, max_dir, max_neu, max_curve, stat)
      class(bc_set_t), intent(inout) :: this
      integer(ip), intent(in) :: max_dir, max_neu, max_curve
      integer(ip), intent(out) :: stat

      stat = DES_BC_BAD_ARG
      if (max_dir < 0_ip .or. max_neu < 0_ip .or. max_curve < 0_ip) return

      if (allocated(this%dir)) deallocate (this%dir)
      if (allocated(this%neu)) deallocate (this%neu)
      if (allocated(this%curves)) deallocate (this%curves)
      if (allocated(this%fixed)) deallocate (this%fixed)
      if (allocated(this%pres_val)) deallocate (this%pres_val)
      if (allocated(this%pres_curve)) deallocate (this%pres_curve)

      allocate (this%dir(max(1_ip, max_dir)))
      allocate (this%neu(max(1_ip, max_neu)))
      allocate (this%curves(max(1_ip, max_curve)))

      this%n_dir = 0_ip
      this%n_neu = 0_ip
      this%n_curve = 0_ip
      this%built = .false.
      stat = DES_BC_OK
   end subroutine bc_init

   subroutine bc_add_dirichlet(this, node, comp, value, curve, stat)
      class(bc_set_t), intent(inout) :: this
      integer(ip), intent(in) :: node, comp
      real(dp), intent(in) :: value
      integer(ip), intent(in) :: curve
      integer(ip), intent(out) :: stat

      stat = DES_BC_BAD_ARG
      if (node < 1_ip .or. comp < 1_ip) return
      if (this%n_dir >= int(size(this%dir), ip)) then
         stat = DES_BC_FULL
         return
      end if

      this%n_dir = this%n_dir + 1_ip
      this%dir(this%n_dir)%node = node
      this%dir(this%n_dir)%comp = comp
      this%dir(this%n_dir)%value = value
      this%dir(this%n_dir)%curve = curve
      this%built = .false.
      stat = DES_BC_OK
   end subroutine bc_add_dirichlet

   !> Bir düğüm listesine aynı bileşen ve değeri uygular.
   subroutine bc_add_dirichlet_nodes(this, nodes, comp, value, curve, stat)
      class(bc_set_t), intent(inout) :: this
      integer(ip), intent(in) :: nodes(:)
      integer(ip), intent(in) :: comp
      real(dp), intent(in) :: value
      integer(ip), intent(in) :: curve
      integer(ip), intent(out) :: stat

      integer(ip) :: k

      stat = DES_BC_OK
      do k = 1_ip, int(size(nodes), ip)
         call this%add_dirichlet(nodes(k), comp, value, curve, stat)
         if (stat /= DES_BC_OK) return
      end do
   end subroutine bc_add_dirichlet_nodes

   subroutine bc_add_nodal_force(this, node, comp, value, curve, stat)
      class(bc_set_t), intent(inout) :: this
      integer(ip), intent(in) :: node, comp
      real(dp), intent(in) :: value
      integer(ip), intent(in) :: curve
      integer(ip), intent(out) :: stat

      stat = DES_BC_BAD_ARG
      if (node < 1_ip .or. comp < 1_ip) return
      if (this%n_neu >= int(size(this%neu), ip)) then
         stat = DES_BC_FULL
         return
      end if

      this%n_neu = this%n_neu + 1_ip
      this%neu(this%n_neu)%kind = DES_LOAD_NODAL
      this%neu(this%n_neu)%node = node
      this%neu(this%n_neu)%comp = comp
      this%neu(this%n_neu)%value = value
      this%neu(this%n_neu)%curve = curve
      stat = DES_BC_OK
   end subroutine bc_add_nodal_force

   !> Kenar üzerinde yüzey basıncı.
   !>
   !> ÖNEMLİ SINIR -- ÖLÜ (DEAD) YÜK: basınç REFERANS yüzeye uygulanır,
   !> deforme yüzeye değil. Yani takipçi (follower) yük DEĞİLDİR ve
   !> tanjanta katkı vermez.
   !>
   !> Gerçek takipçi basınç, simetrik olmayan bir "basınç rijitliği"
   !> terimi üretir ve v0.2'de burulmayla birlikte gelecektir. Büyük
   !> şekil değiştirmede ikisi belirgin biçimde ayrışır; bu yüzden
   !> v0.1'de basınç yüklemesi doğrulama problemlerinde KULLANILMAZ --
   !> VER-034 yer değiştirme kontrolü kullanır.
   subroutine bc_add_pressure(this, node1, node2, value, curve, stat)
      class(bc_set_t), intent(inout) :: this
      integer(ip), intent(in) :: node1, node2
      real(dp), intent(in) :: value
      integer(ip), intent(in) :: curve
      integer(ip), intent(out) :: stat

      stat = DES_BC_BAD_ARG
      if (node1 < 1_ip .or. node2 < 1_ip) return
      if (this%n_neu >= int(size(this%neu), ip)) then
         stat = DES_BC_FULL
         return
      end if

      this%n_neu = this%n_neu + 1_ip
      this%neu(this%n_neu)%kind = DES_LOAD_PRESSURE
      this%neu(this%n_neu)%edge = [node1, node2]
      this%neu(this%n_neu)%value = value
      this%neu(this%n_neu)%curve = curve
      stat = DES_BC_OK
   end subroutine bc_add_pressure

   !> Parçalı doğrusal yük eğrisi tanımlar; indisini döndürür.
   subroutine bc_set_curve(this, idx, t, v, stat)
      class(bc_set_t), intent(inout) :: this
      integer(ip), intent(in) :: idx
      real(dp), intent(in) :: t(:), v(:)
      integer(ip), intent(out) :: stat

      stat = DES_BC_BAD_ARG
      if (idx < 1_ip .or. idx > int(size(this%curves), ip)) return
      if (size(t) /= size(v) .or. size(t) < 2) return

      if (allocated(this%curves(idx)%t)) deallocate (this%curves(idx)%t)
      if (allocated(this%curves(idx)%v)) deallocate (this%curves(idx)%v)
      allocate (this%curves(idx)%t(size(t)))
      allocate (this%curves(idx)%v(size(v)))
      this%curves(idx)%t = t
      this%curves(idx)%v = v
      this%n_curve = max(this%n_curve, idx)
      stat = DES_BC_OK
   end subroutine bc_set_curve

   !> DOF haritalarını kurar. Ağın DOF haritası zaten kurulmuş olmalıdır.
   subroutine bc_build(this, mesh, stat)
      class(bc_set_t), intent(inout) :: this
      type(mesh_t), intent(in) :: mesh
      integer(ip), intent(out) :: stat

      integer(ip) :: k, idof

      stat = DES_BC_BAD_ARG
      if (.not. mesh%built) then
         stat = DES_BC_NOT_BUILT
         return
      end if

      if (allocated(this%fixed)) deallocate (this%fixed)
      if (allocated(this%pres_val)) deallocate (this%pres_val)
      if (allocated(this%pres_curve)) deallocate (this%pres_curve)

      allocate (this%fixed(mesh%n_dof))
      allocate (this%pres_val(mesh%n_dof))
      allocate (this%pres_curve(mesh%n_dof))
      this%fixed = .false.
      this%pres_val = 0.0_dp
      this%pres_curve = 0_ip

      do k = 1_ip, this%n_dir
         idof = mesh%node_dof(this%dir(k)%node, this%dir(k)%comp)
         if (idof < 1_ip) return
         this%fixed(idof) = .true.
         this%pres_val(idof) = this%dir(k)%value
         this%pres_curve(idof) = this%dir(k)%curve
      end do

      this%built = .true.
      stat = DES_BC_OK
   end subroutine bc_build

   !> Yük çarpanı. `curve = 0` doğrusal rampadır (çarpan = t).
   pure function bc_factor_at(this, curve, t) result(f)
      class(bc_set_t), intent(in) :: this
      integer(ip), intent(in) :: curve
      real(dp), intent(in) :: t
      real(dp) :: f

      integer(ip) :: k, n
      real(dp) :: t0, t1

      if (curve < 1_ip .or. curve > this%n_curve) then
         f = t
         return
      end if
      if (.not. allocated(this%curves(curve)%t)) then
         f = t
         return
      end if

      n = int(size(this%curves(curve)%t), ip)
      if (t <= this%curves(curve)%t(1)) then
         f = this%curves(curve)%v(1)
         return
      end if
      if (t >= this%curves(curve)%t(n)) then
         f = this%curves(curve)%v(n)
         return
      end if

      f = this%curves(curve)%v(n)
      do k = 1_ip, n - 1_ip
         t0 = this%curves(curve)%t(k)
         t1 = this%curves(curve)%t(k + 1_ip)
         if (t >= t0 .and. t <= t1) then
            if (t1 > t0) then
               f = this%curves(curve)%v(k) &
                   + (this%curves(curve)%v(k + 1_ip) - this%curves(curve)%v(k)) &
                   *(t - t0)/(t1 - t0)
            else
               f = this%curves(curve)%v(k)
            end if
            return
         end if
      end do
   end function bc_factor_at

   !> Dayatılmış serbestlikleri u vektörüne yazar.
   subroutine bc_apply_prescribed(this, t, u, stat)
      class(bc_set_t), intent(in) :: this
      real(dp), intent(in) :: t
      real(dp), intent(inout) :: u(:)
      integer(ip), intent(out) :: stat

      integer(ip) :: i

      stat = DES_BC_BAD_ARG
      if (.not. this%built) then
         stat = DES_BC_NOT_BUILT
         return
      end if
      if (int(size(u), ip) /= int(size(this%fixed), ip)) return

      do i = 1_ip, int(size(u), ip)
         if (this%fixed(i)) then
            u(i) = this%pres_val(i)*this%factor_at(this%pres_curve(i), t)
         end if
      end do

      stat = DES_BC_OK
   end subroutine bc_apply_prescribed

   !> Dış kuvvet vektörünü kurar.
   !>
   !> Basınç kenar integrali (RADYAN BAŞINA, referans yüzeyde):
   !>    f_a = -p * integral N_a n0 R0 dl0
   !> n0 = (dZ, -dR)/L kenarın dış normalidir.
   subroutine bc_external_force(this, mesh, t, f_ext, stat)
      class(bc_set_t), intent(in) :: this
      type(mesh_t), intent(in) :: mesh
      real(dp), intent(in) :: t
      real(dp), intent(out) :: f_ext(:)
      integer(ip), intent(out) :: stat

      real(dp), parameter :: GP = 0.577350269189625764509148780502_dp
      real(dp), parameter :: XI(2) = [-GP, GP]

      integer(ip) :: k, idof, n1, n2, g, a, node
      real(dp) :: fac, p, dR, dZ, elen, nr, nz
      real(dp) :: N(2), Rg, wgt

      f_ext = 0.0_dp
      stat = DES_BC_BAD_ARG
      if (.not. this%built) then
         stat = DES_BC_NOT_BUILT
         return
      end if
      if (int(size(f_ext), ip) /= mesh%n_dof) return

      do k = 1_ip, this%n_neu
         fac = this%factor_at(this%neu(k)%curve, t)

         select case (this%neu(k)%kind)

         case (DES_LOAD_NODAL)
            idof = mesh%node_dof(this%neu(k)%node, this%neu(k)%comp)
            if (idof < 1_ip) return
            f_ext(idof) = f_ext(idof) + this%neu(k)%value*fac

         case (DES_LOAD_PRESSURE)
            n1 = this%neu(k)%edge(1)
            n2 = this%neu(k)%edge(2)
            if (n1 < 1_ip .or. n2 < 1_ip) return
            if (n1 > mesh%n_node() .or. n2 > mesh%n_node()) return

            p = this%neu(k)%value*fac
            dR = mesh%coord(1, n2) - mesh%coord(1, n1)
            dZ = mesh%coord(2, n2) - mesh%coord(2, n1)
            elen = hypot(dR, dZ)
            if (elen <= 0.0_dp) return

            !> Dış normal: teğetin -90 derece döndürülmüşü.
            nr = dZ/elen
            nz = -dR/elen

            do g = 1_ip, 2_ip
               N(1) = 0.5_dp*(1.0_dp - XI(g))
               N(2) = 0.5_dp*(1.0_dp + XI(g))
               Rg = N(1)*mesh%coord(1, n1) + N(2)*mesh%coord(1, n2)
               !> dl = (L/2) dxi, Gauss agirligi 1
               wgt = 0.5_dp*elen*Rg

               do a = 1_ip, 2_ip
                  node = n1
                  if (a == 2_ip) node = n2

                  idof = mesh%node_dof(node, 1_ip)
                  if (idof < 1_ip) return
                  f_ext(idof) = f_ext(idof) - p*N(a)*nr*wgt

                  idof = mesh%node_dof(node, 2_ip)
                  if (idof < 1_ip) return
                  f_ext(idof) = f_ext(idof) - p*N(a)*nz*wgt
               end do
            end do

         case default
            return
         end select
      end do

      stat = DES_BC_OK
   end subroutine bc_external_force

   !> ELEME: dayatılmış serbestliklerin satır ve sütununu sıfırlar,
   !> köşegene 1 koyar. Simetri ve seyrek desen KORUNUR.
   subroutine bc_constrain_matrix(this, A, stat)
      class(bc_set_t), intent(in) :: this
      type(sparse_csr_t), intent(inout) :: A
      integer(ip), intent(out) :: stat

      integer(ip) :: i, k, j

      stat = DES_BC_BAD_ARG
      if (.not. this%built) then
         stat = DES_BC_NOT_BUILT
         return
      end if
      if (.not. A%analysed) return
      if (A%n /= int(size(this%fixed), ip)) return

      !> Tek geçiş: satırı veya sütunu dayatılmış olan her girdi sıfırlanır.
      do i = 1_ip, A%n
         do k = A%row_ptr(i), A%row_ptr(i + 1_ip) - 1_ip
            j = A%col_idx(k)
            if (this%fixed(i) .or. this%fixed(j)) A%val(k) = 0.0_dp
         end do
      end do

      !> Köşegene 1.
      do i = 1_ip, A%n
         if (.not. this%fixed(i)) cycle
         do k = A%row_ptr(i), A%row_ptr(i + 1_ip) - 1_ip
            if (A%col_idx(k) == i) then
               A%val(k) = 1.0_dp
               exit
            end if
         end do
      end do

      stat = DES_BC_OK
   end subroutine bc_constrain_matrix

   !> Sağ tarafı dayatılmış serbestliklerde sıfırlar.
   !>
   !> ARTIK VEKTÖRÜNÜN KENDİSİNE UYGULANMAZ -- reaksiyon oradan okunur.
   !> Bu yordam yalnızca çözücüye giden KOPYAYA uygulanır.
   subroutine bc_constrain_vector(this, b, stat)
      class(bc_set_t), intent(in) :: this
      real(dp), intent(inout) :: b(:)
      integer(ip), intent(out) :: stat

      integer(ip) :: i

      stat = DES_BC_BAD_ARG
      if (.not. this%built) then
         stat = DES_BC_NOT_BUILT
         return
      end if
      if (int(size(b), ip) /= int(size(this%fixed), ip)) return

      do i = 1_ip, int(size(b), ip)
         if (this%fixed(i)) b(i) = 0.0_dp
      end do

      stat = DES_BC_OK
   end subroutine bc_constrain_vector

   !> Verilen düğüm listesindeki bir bileşenin toplam reaksiyonu.
   !>
   !> `resid` yakınsamış artıktır (f_int - f_ext), ELEME UYGULANMAMIŞ hâli.
   subroutine bc_reaction_sum(this, mesh, nodes, comp, resid, total, stat)
      class(bc_set_t), intent(in) :: this
      type(mesh_t), intent(in) :: mesh
      integer(ip), intent(in) :: nodes(:)
      integer(ip), intent(in) :: comp
      real(dp), intent(in) :: resid(:)
      real(dp), intent(out) :: total
      integer(ip), intent(out) :: stat

      integer(ip) :: k, idof

      total = 0.0_dp
      stat = DES_BC_BAD_ARG
      if (.not. this%built) then
         stat = DES_BC_NOT_BUILT
         return
      end if
      if (int(size(resid), ip) /= mesh%n_dof) return

      do k = 1_ip, int(size(nodes), ip)
         idof = mesh%node_dof(nodes(k), comp)
         if (idof < 1_ip) return
         total = total + resid(idof)
      end do

      stat = DES_BC_OK
   end subroutine bc_reaction_sum

   !> Yalnızca SERBEST serbestlikler üzerinde Öklid normu.
   !>
   !> Yakınsama ölçütü buna bakar: dayatılmış serbestliklerdeki artık
   !> reaksiyondur ve sıfıra gitmesi beklenmez.
   pure function bc_free_norm(this, v) result(nrm)
      class(bc_set_t), intent(in) :: this
      real(dp), intent(in) :: v(:)
      real(dp) :: nrm

      integer(ip) :: i

      nrm = 0.0_dp
      if (.not. this%built) return
      if (int(size(v), ip) /= int(size(this%fixed), ip)) return

      do i = 1_ip, int(size(v), ip)
         if (.not. this%fixed(i)) nrm = nrm + v(i)*v(i)
      end do
      nrm = sqrt(nrm)
   end function bc_free_norm

end module des_bc
