!> ---------------------------------------------------------------------------
!> des_assemble -- eleman katkılarının global sisteme montajı
!>
!> ÖLÇEK: radyan başına (bkz. des_bc). Eleman ne üretiyorsa o toplanır.
!>
!> SEMBOLİK DESEN BİR KEZ KURULUR
!>
!> `build_pattern` bir ağ için BİR KEZ çağrılır. Newton yinelemeleri
!> `zero` + `assemble_tangent` kullanır; desen yeniden hesaplanmaz.
!> Deseni her yinelemede kurmak, tipik bir analizde baskın maliyet olurdu
!> (bkz. des_sparse başlığı).
!>
!> K_gu SAKLANMAZ
!>
!> ADR-0009: hiperelastisitede tanjant simetriktir, dolayısıyla
!> K_gu = transpose(K_ug). Eleman yalnızca K_uu, K_ug ve K_gg döndürür;
!> montaj alt bloğu devrikten üretir. Simetrik depolamada (sym = .true.)
!> zaten yalnızca üst üçgen saklanır ve bu iş kendiliğinden olur.
!>
!> DURUM SAHİPLİĞİ
!>
!> Gauss noktası malzeme durumlarının sahibi ÇÖZÜCÜdür (ADR-0009 e).
!> Bu modül onları `state(n_gauss, n_elem)` biçiminde dışarıdan alır ve
!> elemanlara dilim olarak uzatır.
!>
!> Katman: 4 -- Analiz çekirdeği
!> ---------------------------------------------------------------------------
module des_assemble
   use des_kinds, only: dp, ip
   use des_mesh, only: mesh_t, DES_MESH_OK
   use des_sparse, only: sparse_csr_t, DES_SPM_OK
   use des_material, only: material_state_t
   use des_element, only: element_t, element_ctx_t, DES_ELEM_OK
   implicit none
   private

   public :: DES_ASM_OK, DES_ASM_BAD_ARG, DES_ASM_ELEM_FAIL, DES_ASM_SPARSE_FAIL
   public :: DES_ASM_MAX_NODE, DES_ASM_MAX_NDOF, DES_ASM_MAX_EDOF
   public :: element_ref_t
   public :: build_pattern, assemble_residual, assemble_tangent

   integer(ip), parameter :: DES_ASM_OK = 0_ip
   integer(ip), parameter :: DES_ASM_BAD_ARG = 1_ip
   !> Bir eleman hata bildirdi; `dt_factor` çağırana taşınır.
   integer(ip), parameter :: DES_ASM_ELEM_FAIL = 2_ip
   integer(ip), parameter :: DES_ASM_SPARSE_FAIL = 3_ip

   !> Sabit boyutlu çalışma tamponları: montaj sıcak döngüdedir ve
   !> tahsis etmez. Sınırlar ileriki eleman aileleri için seçilmiştir.
   integer(ip), parameter :: DES_ASM_MAX_NODE = 9_ip
   integer(ip), parameter :: DES_ASM_MAX_NDOF = 3_ip
   integer(ip), parameter :: DES_ASM_MAX_EDOF = DES_ASM_MAX_NODE*DES_ASM_MAX_NDOF
   integer(ip), parameter :: DES_ASM_MAX_GDOF = 2_ip
   integer(ip), parameter :: DES_ASM_MAX_TOT = DES_ASM_MAX_EDOF + DES_ASM_MAX_GDOF

   !> Çok biçimli eleman dizisi için sarmalayıcı.
   !>
   !> Fortran'da farklı dinamik tiplere sahip bir `class(element_t)` dizisi
   !> doğrudan tutulamaz; tahsis edilebilir bileşenli bir sarmalayıcı
   !> gerekir. Ağdaki elemanlar farklı tiplerde olabilsin diye böyle.
   type :: element_ref_t
      class(element_t), allocatable :: e
   end type element_ref_t

contains

   !> Elemanların DOF listelerinden seyrek deseni kurar.
   subroutine build_pattern(mesh, elems, A, sym, stat)
      type(mesh_t), intent(in) :: mesh
      type(element_ref_t), intent(in) :: elems(:)
      type(sparse_csr_t), intent(inout) :: A
      logical, intent(in) :: sym
      integer(ip), intent(out) :: stat

      integer(ip), allocatable :: ed(:, :), nof(:)
      integer(ip) :: ne, ie, nd, st

      stat = DES_ASM_BAD_ARG
      if (.not. mesh%built) return
      ne = int(size(elems), ip)
      if (ne < 1_ip) return

      allocate (ed(DES_ASM_MAX_TOT, ne), nof(ne))
      ed = 0_ip
      nof = 0_ip

      do ie = 1_ip, ne
         if (.not. allocated(elems(ie)%e)) return
         call mesh%element_dofs(ie, elems(ie)%e%cfg%global_dof_ids, &
                                ed(:, ie), nd, st)
         if (st /= DES_MESH_OK) return
         nof(ie) = nd
      end do

      call A%analyse(mesh%n_dof, ed, nof, sym, stat=st)
      if (st /= DES_SPM_OK) then
         stat = DES_ASM_SPARSE_FAIL
         return
      end if

      stat = DES_ASM_OK
   end subroutine build_pattern

   !> Global iç kuvvet vektörünü toplar ve durumu günceller.
   !>
   !> `dt_factor` bütün elemanlar üzerindeki EN KÜÇÜK değerdir: bir eleman
   !> adım küçültme istiyorsa bütün model küçültür.
   subroutine assemble_residual(mesh, elems, u, u_global, ctx, &
                                state_n, state_np1, f_int, stat, dt_factor)
      type(mesh_t), intent(in) :: mesh
      type(element_ref_t), intent(inout) :: elems(:)
      real(dp), intent(in) :: u(:)
      real(dp), intent(in) :: u_global(:)
      type(element_ctx_t), intent(in) :: ctx
      type(material_state_t), intent(in) :: state_n(:, :)
      type(material_state_t), intent(inout) :: state_np1(:, :)
      real(dp), intent(out) :: f_int(:)
      integer(ip), intent(out) :: stat
      real(dp), intent(out) :: dt_factor

      real(dp) :: ue(DES_ASM_MAX_NDOF, DES_ASM_MAX_NODE)
      real(dp) :: fe(DES_ASM_MAX_NDOF, DES_ASM_MAX_NODE)
      real(dp) :: uge(DES_ASM_MAX_GDOF), fge(DES_ASM_MAX_GDOF)
      integer(ip) :: dofs(DES_ASM_MAX_TOT)
      integer(ip) :: ne, ie, nn, ndn, ng, nd, a, i, k, idof, st
      real(dp) :: dtf

      f_int = 0.0_dp
      dt_factor = 1.0_dp
      stat = DES_ASM_BAD_ARG

      if (.not. mesh%built) return
      if (int(size(f_int), ip) /= mesh%n_dof) return
      if (int(size(u), ip) /= mesh%n_dof) return

      ne = int(size(elems), ip)
      if (int(size(state_n, 2), ip) < ne) return
      if (int(size(state_np1, 2), ip) < ne) return

      do ie = 1_ip, ne
         if (.not. allocated(elems(ie)%e)) return

         nn = elems(ie)%e%n_node()
         ndn = elems(ie)%e%n_dof_per_node()
         ng = elems(ie)%e%n_global_dof()
         if (nn > DES_ASM_MAX_NODE .or. ndn > DES_ASM_MAX_NDOF) return

         !> Global u'dan eleman dizisine topla.
         do a = 1_ip, nn
            do i = 1_ip, ndn
               idof = mesh%node_dof(mesh%conn(a, ie), i)
               if (idof < 1_ip) return
               ue(i, a) = u(idof)
            end do
         end do

         uge = 0.0_dp
         do k = 1_ip, ng
            if (elems(ie)%e%cfg%global_dof_ids(k) < 1_ip) cycle
            uge(k) = u_global(elems(ie)%e%cfg%global_dof_ids(k))
         end do

         call elems(ie)%e%residual(ue(1:ndn, 1:nn), uge(1:ng), ctx, &
                                   state_n(:, ie), fe(1:ndn, 1:nn), &
                                   fge(1:ng), state_np1(:, ie), st, dtf)
         dt_factor = min(dt_factor, dtf)
         if (st /= DES_ELEM_OK) then
            stat = DES_ASM_ELEM_FAIL
            return
         end if

         !> Eleman DOF listesi: önce düğüm serbestlikleri, sonra global.
         call mesh%element_dofs(ie, elems(ie)%e%cfg%global_dof_ids, &
                                dofs, nd, st)
         if (st /= DES_MESH_OK) return

         k = 0_ip
         do a = 1_ip, nn
            do i = 1_ip, ndn
               k = k + 1_ip
               f_int(dofs(k)) = f_int(dofs(k)) + fe(i, a)
            end do
         end do
         do i = 1_ip, ng
            k = k + 1_ip
            if (k > nd) exit
            f_int(dofs(k)) = f_int(dofs(k)) + fge(i)
         end do
      end do

      stat = DES_ASM_OK
   end subroutine assemble_residual

   !> Global tanjantı toplar. Desen önceden kurulmuş olmalıdır.
   subroutine assemble_tangent(mesh, elems, u, u_global, ctx, state_n, A, stat)
      type(mesh_t), intent(in) :: mesh
      type(element_ref_t), intent(inout) :: elems(:)
      real(dp), intent(in) :: u(:)
      real(dp), intent(in) :: u_global(:)
      type(element_ctx_t), intent(in) :: ctx
      type(material_state_t), intent(in) :: state_n(:, :)
      type(sparse_csr_t), intent(inout) :: A
      integer(ip), intent(out) :: stat

      real(dp) :: ue(DES_ASM_MAX_NDOF, DES_ASM_MAX_NODE)
      real(dp) :: uge(DES_ASM_MAX_GDOF)
      real(dp) :: Kuu(DES_ASM_MAX_EDOF, DES_ASM_MAX_EDOF)
      real(dp) :: Kug(DES_ASM_MAX_EDOF, DES_ASM_MAX_GDOF)
      real(dp) :: Kgg(DES_ASM_MAX_GDOF, DES_ASM_MAX_GDOF)
      real(dp) :: Ke(DES_ASM_MAX_TOT, DES_ASM_MAX_TOT)
      integer(ip) :: dofs(DES_ASM_MAX_TOT)
      !> `ia` adi bilincli: tek harfli `a`, kukla argüman olan A seyrek
      !> matrisini maskelerdi (Fortran harf duyarsizdir).
      integer(ip) :: ne, ie, nn, ndn, ng, ndt, nd, ia, i, k, idof, st

      stat = DES_ASM_BAD_ARG
      if (.not. mesh%built) return
      if (.not. A%analysed) return

      call A%zero()
      ne = int(size(elems), ip)

      do ie = 1_ip, ne
         if (.not. allocated(elems(ie)%e)) return

         nn = elems(ie)%e%n_node()
         ndn = elems(ie)%e%n_dof_per_node()
         ng = elems(ie)%e%n_global_dof()
         ndt = nn*ndn
         if (ndt > DES_ASM_MAX_EDOF) return

         do ia = 1_ip, nn
            do i = 1_ip, ndn
               idof = mesh%node_dof(mesh%conn(ia, ie), i)
               if (idof < 1_ip) return
               ue(i, ia) = u(idof)
            end do
         end do

         uge = 0.0_dp
         do k = 1_ip, ng
            if (elems(ie)%e%cfg%global_dof_ids(k) < 1_ip) cycle
            uge(k) = u_global(elems(ie)%e%cfg%global_dof_ids(k))
         end do

         call elems(ie)%e%tangent(ue(1:ndn, 1:nn), uge(1:ng), ctx, &
                                  state_n(:, ie), Kuu(1:ndt, 1:ndt), &
                                  Kug(1:ndt, 1:ng), Kgg(1:ng, 1:ng), st)
         if (st /= DES_ELEM_OK) then
            stat = DES_ASM_ELEM_FAIL
            return
         end if

         !> Üç bloğu tek bir yoğun bloğa yerleştir. Eleman DOF listesi
         !> globalleri sona aldığı için blok yapısı kendiliğinden doğru
         !> yere düşer. K_gu = transpose(K_ug) burada üretilir.
         nd = ndt + ng
         Ke(1:nd, 1:nd) = 0.0_dp
         Ke(1:ndt, 1:ndt) = Kuu(1:ndt, 1:ndt)
         if (ng > 0_ip) then
            Ke(1:ndt, ndt + 1_ip:nd) = Kug(1:ndt, 1:ng)
            Ke(ndt + 1_ip:nd, 1:ndt) = transpose(Kug(1:ndt, 1:ng))
            Ke(ndt + 1_ip:nd, ndt + 1_ip:nd) = Kgg(1:ng, 1:ng)
         end if

         call mesh%element_dofs(ie, elems(ie)%e%cfg%global_dof_ids, &
                                dofs, k, st)
         if (st /= DES_MESH_OK) return
         if (k /= nd) return

         call A%add_block(dofs, nd, Ke(1:nd, 1:nd), st)
         if (st /= DES_SPM_OK) then
            stat = DES_ASM_SPARSE_FAIL
            return
         end if
      end do

      stat = DES_ASM_OK
   end subroutine assemble_tangent

end module des_assemble
