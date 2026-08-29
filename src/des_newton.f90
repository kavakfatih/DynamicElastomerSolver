!> ---------------------------------------------------------------------------
!> des_newton -- yük adımlamalı tam Newton sürücüsü
!>
!> BU SÜRÜMDE OLANLAR
!>
!>   - Tam Newton (tutarlı tanjant)
!>   - REZİDÜ yakınsama kriteri: bağıl ve mutlak
!>   - Sabit yük artımı + yakınsamazsa GERİ ADIM (cut-back)
!>   - Durum kaydet/geri al (Sözleşme 4)
!>   - Malzemenin `dt_factor` talebine uyum
!>   - Ters dönmüş eleman (J <= 0) bildirilirse anında geri adım
!>
!> BU SÜRÜMDE OLMAYANLAR -- v0.3
!>
!>   Hat araması (line search), yay uzunluğu (arc-length), quasi-Newton,
!>   uyarlanır iniş, yer değiştirme ve enerji kriterleri, dejenere durum
!>   tespiti.
!>
!> Gerekçe: şimdi tek kriterle çalışan, doğruluğu kanıtlanmış bir çekirdek
!> isteniyor. Ama kriter yapısı GENİŞLETİLEBİLİR kuruldu: v0.3'te iki
!> kriter daha eklemek yeni bir tip değil, `newton_opts_t`e iki alan
!> olacak (aşağıdaki yorumlara bakınız).
!>
!> YAKINSAMA RAPORU
!>
!> Her yinelemenin artık normu `newton_result_t` içinde saklanabilir.
!> Çekirdek METİN ÜRETMEZ (ADR-0008); bu dizi, ileride yazılacak tanı
!> aracının veri kaynağıdır.
!>
!> Katman: 4 -- Analiz çekirdeği
!> ---------------------------------------------------------------------------
module des_newton
   use des_kinds, only: dp, ip
   use des_mesh, only: mesh_t
   use des_sparse, only: sparse_csr_t
   use des_material, only: material_state_t
   use des_element, only: element_ctx_t
   use des_linsolve, only: linsolver_t, DES_LIN_OK
   use des_bc, only: bc_set_t, DES_BC_OK
   use des_assemble, only: element_ref_t, assemble_residual, assemble_tangent, &
                           DES_ASM_OK, DES_ASM_ELEM_FAIL
   implicit none
   private

   public :: DES_NWT_OK, DES_NWT_BAD_ARG, DES_NWT_NO_CONVERGE
   public :: DES_NWT_LIN_FAIL, DES_NWT_STEP_TOO_SMALL
   public :: newton_opts_t, newton_result_t, newton_solve

   integer(ip), parameter :: DES_NWT_OK = 0_ip
   integer(ip), parameter :: DES_NWT_BAD_ARG = 1_ip
   !> Adım küçültme sınırına rağmen yakınsanamadı.
   integer(ip), parameter :: DES_NWT_NO_CONVERGE = 2_ip
   integer(ip), parameter :: DES_NWT_LIN_FAIL = 3_ip
   integer(ip), parameter :: DES_NWT_STEP_TOO_SMALL = 4_ip

   !> ------------------------------------------------------------------------
   !> Newton seçenekleri
   !>
   !> GENİŞLETME NOKTASI: v0.3'te yer değiştirme ve enerji kriterleri
   !> buraya `tol_disp` ve `tol_energy` alanları olarak eklenecek; yeni
   !> bir tip AÇILMAYACAK. Kriter mantığı `is_converged` içinde tek yerde
   !> toplanmıştır, oraya iki dal eklenir.
   !> ------------------------------------------------------------------------
   type :: newton_opts_t
      !> Bağıl artık toleransı (referansa göre).
      real(dp) :: tol_rel = 1.0e-9_dp
      !> Mutlak artık toleransı; sıfır yük durumunda tek ölçüt budur.
      real(dp) :: tol_abs = 1.0e-10_dp
      !> Adım başına en çok yineleme.
      integer(ip) :: max_iter = 30_ip
      !> Yük aralığı [0,1] kaç eşit adıma bölünsün.
      integer(ip) :: n_step = 5_ip
      !> Geri adımda artım bu oranla çarpılır.
      real(dp) :: cutback_factor = 0.5_dp
      !> En çok kaç geri adım denenir.
      integer(ip) :: max_cutback = 15_ip
      !> Artım bunun altına inerse pes edilir.
      real(dp) :: min_step = 1.0e-8_dp
      !> Yakınsama geçmişi saklansın mı.
      logical :: keep_history = .true.
   end type newton_opts_t

   !> ------------------------------------------------------------------------
   !> Newton sonucu ve yakınsama geçmişi
   !> ------------------------------------------------------------------------
   type :: newton_result_t
      integer(ip) :: stat = DES_NWT_BAD_ARG
      !> Tamamlanan yük adımı sayısı.
      integer(ip) :: n_step = 0_ip
      !> Toplam Newton yinelemesi.
      integer(ip) :: n_iter = 0_ip
      !> Toplam geri adım sayısı.
      integer(ip) :: n_cutback = 0_ip
      !> Ulaşılan yük parametresi (başarıda 1.0).
      real(dp) :: t_final = 0.0_dp
      !> Son adımın son artık normu.
      real(dp) :: resid_final = 0.0_dp
      !> Yineleme başına artık normu.
      real(dp), allocatable :: hist_resid(:)
      !> Her kaydın hangi yük adımına ait olduğu.
      integer(ip), allocatable :: hist_step(:)
      integer(ip) :: n_hist = 0_ip
   end type newton_result_t

contains

   !> Elemanların kendi durumunu düz bir tampona yazar.
   subroutine save_element_state(elems, buf, ntot, stat)
      type(element_ref_t), intent(in) :: elems(:)
      real(dp), intent(inout) :: buf(:)
      integer(ip), intent(in) :: ntot
      integer(ip), intent(out) :: stat

      integer(ip) :: ie, m, pos, got

      stat = DES_NWT_BAD_ARG
      if (ntot == 0_ip) then
         stat = DES_NWT_OK
         return
      end if
      if (int(size(buf), ip) < ntot) return

      pos = 1_ip
      do ie = 1_ip, int(size(elems), ip)
         if (.not. allocated(elems(ie)%e)) return
         m = elems(ie)%e%n_internal_dof()
         if (m == 0_ip) cycle
         got = elems(ie)%e%serialise(buf(pos:pos + m - 1_ip))
         if (got /= m) return
         pos = pos + m
      end do

      stat = DES_NWT_OK
   end subroutine save_element_state

   !> Eleman durumunu tampondan geri yükler.
   subroutine load_element_state(elems, buf, ntot, stat)
      type(element_ref_t), intent(inout) :: elems(:)
      real(dp), intent(in) :: buf(:)
      integer(ip), intent(in) :: ntot
      integer(ip), intent(out) :: stat

      integer(ip) :: ie, m, pos, got

      stat = DES_NWT_BAD_ARG
      if (ntot == 0_ip) then
         stat = DES_NWT_OK
         return
      end if
      if (int(size(buf), ip) < ntot) return

      pos = 1_ip
      do ie = 1_ip, int(size(elems), ip)
         if (.not. allocated(elems(ie)%e)) return
         m = elems(ie)%e%n_internal_dof()
         if (m == 0_ip) cycle
         got = elems(ie)%e%restore(buf(pos:pos + m - 1_ip))
         if (got /= m) return
         pos = pos + m
      end do

      stat = DES_NWT_OK
   end subroutine load_element_state

   !> Yakınsama kararı.
   !>
   !> TEK YER: v0.3'te yer değiştirme ve enerji kriterleri buraya eklenir.
   !> Ölçüt yalnızca SERBEST serbestlikler üzerinde kurulur; dayatılmış
   !> serbestliklerdeki artık reaksiyondur ve sıfıra gitmez.
   pure function is_converged(rnorm, rref, opts) result(ok)
      real(dp), intent(in) :: rnorm, rref
      type(newton_opts_t), intent(in) :: opts
      logical :: ok

      ok = (rnorm <= opts%tol_abs) .or. (rnorm <= opts%tol_rel*rref)
   end function is_converged

   !> Yük adımlamalı tam Newton.
   !>
   !> `u` girişte başlangıç tahmini, çıkışta çözümdür. `resid` yakınsamış
   !> ARTIKtır (eleme uygulanmamış) -- reaksiyonlar buradan okunur.
   subroutine newton_solve(mesh, elems, bc, lin, A, ctx, &
                           state_n, state_np1, u, u_global, resid, opts, res)
      type(mesh_t), intent(in) :: mesh
      type(element_ref_t), intent(inout) :: elems(:)
      type(bc_set_t), intent(in) :: bc
      class(linsolver_t), intent(inout) :: lin
      type(sparse_csr_t), intent(inout) :: A
      type(element_ctx_t), intent(inout) :: ctx
      type(material_state_t), intent(inout) :: state_n(:, :)
      type(material_state_t), intent(inout) :: state_np1(:, :)
      real(dp), intent(inout) :: u(:)
      real(dp), intent(inout) :: u_global(:)
      real(dp), intent(out) :: resid(:)
      type(newton_opts_t), intent(in) :: opts
      type(newton_result_t), intent(out) :: res

      real(dp), allocatable :: f_int(:), f_ext(:), rhs(:), du(:), u_save(:)
      !> Elemanın KENDİ sahip olduğu durum (yoğunlaştırılmış iç
      !> serbestlikler, ADR-0009 e). Geri adımda bu da geri alınmalıdır:
      !> yalnızca u ve Gauss durumları geri alınırsa, tekrarlanan artım
      !> farklı bir basınç alanından başlar ve sessizce yanlış çalışır.
      real(dp), allocatable :: e_save(:)
      integer(ip) :: n, it, st, ncut, ng, nel, ig, ie, n_esave
      real(dp) :: t, dt, t_try, rnorm, rref, dtf, fext_norm

      res%stat = DES_NWT_BAD_ARG
      n = mesh%n_dof
      if (n < 1_ip) return
      if (int(size(u), ip) /= n) return
      if (int(size(resid), ip) /= n) return
      if (.not. bc%built) return
      if (.not. A%analysed) return

      ng = int(size(state_n, 1), ip)
      nel = int(size(elems), ip)

      allocate (f_int(n), f_ext(n), rhs(n), du(n), u_save(n))

      !> Eleman durumu tamponu: bugün full ve fbar için sıfır uzunluktur,
      !> v0.3'te karışık u-p geldiğinde dolar. Yol şimdi kuruluyor ki o
      !> gün Newton'a dokunulmasın.
      n_esave = 0_ip
      do ie = 1_ip, nel
         if (allocated(elems(ie)%e)) n_esave = n_esave + elems(ie)%e%n_internal_dof()
      end do
      allocate (e_save(max(1_ip, n_esave)))
      e_save = 0.0_dp
      if (opts%keep_history) then
         allocate (res%hist_resid(opts%max_iter*(opts%n_step + opts%max_cutback + 1_ip)))
         allocate (res%hist_step(size(res%hist_resid)))
         res%hist_resid = 0.0_dp
         res%hist_step = 0_ip
      end if
      res%n_hist = 0_ip

      !> Doğrusal çözücünün sembolik incelemesi BİR KEZ.
      call lin%analyse(A, st)
      if (st /= DES_LIN_OK) then
         res%stat = DES_NWT_LIN_FAIL
         return
      end if

      t = 0.0_dp
      dt = 1.0_dp/real(max(1_ip, opts%n_step), dp)
      ncut = 0_ip
      resid = 0.0_dp

      do while (t < 1.0_dp - 1.0e-14_dp)
         t_try = min(t + dt, 1.0_dp)

         !> Adım başlangıcını kaydet: geri adımda buraya dönülür.
         u_save = u
         call save_element_state(elems, e_save, n_esave, st)
         if (st /= DES_NWT_OK) return
         res%n_step = res%n_step + 1_ip

         call bc%apply_prescribed(t_try, u, st)
         if (st /= DES_BC_OK) return
         call bc%external_force(mesh, t_try, f_ext, st)
         if (st /= DES_BC_OK) return
         fext_norm = bc%free_norm(f_ext)

         ctx%time = t
         ctx%dt = t_try - t

         rref = 0.0_dp
         rnorm = huge(1.0_dp)

         do it = 1_ip, opts%max_iter
            call assemble_residual(mesh, elems, u, u_global, ctx, &
                                   state_n, state_np1, f_int, st, dtf)

            !> Ters dönmüş eleman veya malzeme adım küçültme istiyor.
            if (st == DES_ASM_ELEM_FAIL .or. dtf < 1.0_dp) then
               rnorm = huge(1.0_dp)
               exit
            end if
            if (st /= DES_ASM_OK) return

            resid = f_int - f_ext
            rnorm = bc%free_norm(resid)

            res%n_iter = res%n_iter + 1_ip
            if (opts%keep_history .and. res%n_hist < int(size(res%hist_resid), ip)) then
               res%n_hist = res%n_hist + 1_ip
               res%hist_resid(res%n_hist) = rnorm
               res%hist_step(res%n_hist) = res%n_step
            end if

            !> Referans: adımın ilk artığı ile dış yükün büyüğü.
            if (it == 1_ip) rref = max(rnorm, fext_norm)
            if (rref <= 0.0_dp) rref = 1.0_dp

            if (is_converged(rnorm, rref, opts)) exit

            call assemble_tangent(mesh, elems, u, u_global, ctx, state_n, A, st)
            if (st == DES_ASM_ELEM_FAIL) then
               rnorm = huge(1.0_dp)
               exit
            end if
            if (st /= DES_ASM_OK) return

            call bc%constrain_matrix(A, st)
            if (st /= DES_BC_OK) return

            rhs = -resid
            call bc%constrain_vector(rhs, st)
            if (st /= DES_BC_OK) return

            call lin%factorize(A, st)
            if (st /= DES_LIN_OK) then
               rnorm = huge(1.0_dp)
               exit
            end if
            call lin%solve(rhs, du, st)
            if (st /= DES_LIN_OK) then
               rnorm = huge(1.0_dp)
               exit
            end if

            u = u + du
         end do

         if (is_converged(rnorm, rref, opts)) then
            !> Adım kabul: n+1 durumu n durumu olur.
            do ie = 1_ip, nel
               do ig = 1_ip, ng
                  if (allocated(state_np1(ig, ie)%sv) .and. &
                      allocated(state_n(ig, ie)%sv)) then
                     state_n(ig, ie)%sv = state_np1(ig, ie)%sv
                  end if
               end do
            end do
            t = t_try
            res%resid_final = rnorm
         else
            !> Geri adım: yer değiştirmeyi VE eleman durumunu geri al,
            !> artımı küçült. Gauss durumları zaten yalnızca kabul
            !> edildiğinde işleniyor.
            u = u_save
            call load_element_state(elems, e_save, n_esave, st)
            if (st /= DES_NWT_OK) return
            res%n_step = res%n_step - 1_ip
            ncut = ncut + 1_ip
            res%n_cutback = ncut
            if (ncut > opts%max_cutback) then
               res%stat = DES_NWT_NO_CONVERGE
               res%t_final = t
               return
            end if
            dt = dt*opts%cutback_factor
            if (dt < opts%min_step) then
               res%stat = DES_NWT_STEP_TOO_SMALL
               res%t_final = t
               return
            end if
         end if
      end do

      res%t_final = t
      res%stat = DES_NWT_OK
   end subroutine newton_solve

end module des_newton
