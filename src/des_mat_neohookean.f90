!> ---------------------------------------------------------------------------
!> des_mat_neohookean -- sıkıştırılabilir Neo-Hookean hiperelastik malzeme
!>
!> Hacimsel/izokorik ayrışmalı serbest enerji:
!>
!>    Psi = C10 * (Ibar1 - 3) + (K/2) * (J-1)^2
!>
!>    J = sqrt(det C),  I1 = tr(C),  Ibar1 = J^(-2/3) * I1
!>
!> 2. Piola-Kirchhoff gerilmesi, S = 2 dPsi/dC:
!>
!>    S_iso = 2*C10*J^(-2/3) * [ I - (1/3)*I1*Cinv ]
!>    S_vol = K*J*(J-1) * Cinv
!>
!> Malzeme tanjantı, CC = 2 dS/dC:
!>
!>    IIc_ijkl = 0.5*( Cinv_ik*Cinv_jl + Cinv_il*Cinv_jk )   [ = -d(Cinv)/dC ]
!>
!>    CC_iso = 4*C10*J^(-2/3) * [ -(1/3)*( I(x)Cinv + Cinv(x)I )
!>                                + (1/9)*I1*( Cinv(x)Cinv )
!>                                + (1/3)*I1*IIc ]
!>
!>    CC_vol = K * [ J*(2J-1)*( Cinv(x)Cinv ) - 2*J*(J-1)*IIc ]
!>
!> Burada (x) diyadik çarpımdır: (A(x)B)_ijkl = A_ij * B_kl
!>
!> Küçük şekil değiştirmede kayma modülü mu = 2*C10, hacim modülü K'dır;
!> dolayısıyla elastisite modülü E = 9*K*mu/(3*K + mu) olur. Sıkıştırılamaz
!> sınırda (K >> mu) bu 3*mu = 6*C10'a gider.
!>
!> Tam türetme: docs/teori/0001-hiperelastik-neo-hookean.md
!> Kaynaklar: Bonet & Wood (2008) böl. 6; Holzapfel (2000) 6.4;
!>            Simo & Taylor, CMAME 85 (1991) 273-310.
!>
!> Durum değişkeni yoktur (n_sv = 0): hiperelastisite yol bağımsızdır.
!>
!> Katman: 4 -- Analiz çekirdeği
!> ---------------------------------------------------------------------------
module des_mat_neohookean
   use des_kinds, only: dp, ip
   use des_tensor, only: IDENT3, det3, trace3, inv3
   use des_material, only: material_t, mat_point_t, material_state_t, &
                           DES_MAT_OK, DES_MAT_SINGULAR, DES_MAT_NONPHYSICAL
   implicit none
   private

   public :: mat_neohookean_t, new_neohookean

   !> Sıkıştırılabilir Neo-Hookean malzeme.
   type, extends(material_t) :: mat_neohookean_t
      !> İzokorik katkı parametresi; mu = 2*C10.
      real(dp) :: c10 = 0.0_dp
      !> Hacim modülü (penaltı parametresi).
      real(dp) :: kappa = 0.0_dp
   contains
      procedure :: eval => nh_eval
   end type mat_neohookean_t

   !> det C'nin, C'nin büyüklüğüne göre tekil sayılacağı bağıl eşik.
   real(dp), parameter :: DET_REL_TOL = 1.0e-14_dp

   !> Fiziksel olmayan veya tekil bir durumla karşılaşıldığında çözücüden
   !> istenecek adım küçültme oranı. Dörtte bir, geri adımın (cut-back) tek
   !> bir denemede ters dönmüş elemanı kurtarması için yeterince agresiftir.
   real(dp), parameter :: CUTBACK_FACTOR = 0.25_dp

contains

   !> Neo-Hookean malzeme kurucusu.
   pure function new_neohookean(c10, kappa) result(m)
      real(dp), intent(in) :: c10
      real(dp), intent(in) :: kappa
      type(mat_neohookean_t) :: m

      m%name = 'neohookean'
      m%n_sv = 0_ip
      m%c10 = c10
      m%kappa = kappa
   end function new_neohookean

   !> Gerilme ve tanjant değerlendirmesi. Sözleşme için des_material'a bakınız.
   subroutine nh_eval(this, C, pt, state_n, S, CC, state_np1, stat, dt_factor)
      class(mat_neohookean_t), intent(in)   :: this
      real(dp), intent(in)                  :: C(3, 3)
      type(mat_point_t), intent(in)         :: pt
      type(material_state_t), intent(in)    :: state_n
      real(dp), intent(out)                 :: S(3, 3)
      real(dp), intent(out)                 :: CC(3, 3, 3, 3)
      type(material_state_t), intent(inout) :: state_np1
      integer(ip), intent(out)              :: stat
      real(dp), intent(out)                 :: dt_factor

      real(dp) :: Cinv(3, 3)
      real(dp) :: detC, J, I1, Jm23, cnorm
      real(dp) :: a_iso, a_vol, b_vol, iic
      !> Döngü indisleri bilinçli olarak çift harfli: Fortran büyük/küçük
      !> harf duyarsızdır, dolayısıyla tek harfli `j` hacim oranı J'yi ezer.
      integer(ip) :: ii, jj, kk, ll
      logical :: ok

      !> Hiperelastisitede durum yoktur: n+1 durumu n durumunun aynısıdır.
      !> Yine de kopyalanır, çünkü çözücü state_np1'i okuyacaktır.
      if (allocated(state_n%sv) .and. allocated(state_np1%sv)) then
         if (size(state_np1%sv) == size(state_n%sv)) state_np1%sv = state_n%sv
      end if

      S = 0.0_dp
      CC = 0.0_dp
      dt_factor = 1.0_dp

      detC = det3(C)

      !> det C <= 0: eleman ters dönmüş. Gerilme tanımsızdır. Çözücüye hem
      !> hatayı hem de "daha küçük adımla düzelebilir" bilgisini veriyoruz.
      if (detC <= 0.0_dp) then
         stat = DES_MAT_NONPHYSICAL
         dt_factor = CUTBACK_FACTOR
         return
      end if

      !> det C pozitif ama C'nin büyüklüğüne göre ihmal edilebilirse tersi
      !> güvenilir değildir. Mutlak eşik yerine bağıl eşik kullanılır, aksi
      !> hâlde ölçek değişince kriter anlamını yitirir.
      cnorm = maxval(abs(C))
      if (detC < DET_REL_TOL*cnorm**3) then
         stat = DES_MAT_SINGULAR
         dt_factor = CUTBACK_FACTOR
         return
      end if

      call inv3(C, detC, Cinv, ok)
      if (.not. ok) then
         stat = DES_MAT_SINGULAR
         dt_factor = CUTBACK_FACTOR
         return
      end if

      J = sqrt(detC)
      I1 = trace3(C)
      Jm23 = J**(-2.0_dp/3.0_dp)

      ! --- Gerilme ----------------------------------------------------------
      S = 2.0_dp*this%c10*Jm23*(IDENT3 - (I1/3.0_dp)*Cinv) &
          + this%kappa*J*(J - 1.0_dp)*Cinv

      ! --- Tanjant ----------------------------------------------------------
      a_iso = 4.0_dp*this%c10*Jm23
      a_vol = this%kappa*J*(2.0_dp*J - 1.0_dp)
      b_vol = 2.0_dp*this%kappa*J*(J - 1.0_dp)

      do ll = 1, 3
         do kk = 1, 3
            do jj = 1, 3
               do ii = 1, 3
                  iic = 0.5_dp*(Cinv(ii, kk)*Cinv(jj, ll) &
                                + Cinv(ii, ll)*Cinv(jj, kk))

                  CC(ii, jj, kk, ll) = &
                     a_iso*(-(1.0_dp/3.0_dp) &
                            *(IDENT3(ii, jj)*Cinv(kk, ll) &
                              + Cinv(ii, jj)*IDENT3(kk, ll)) &
                            + (I1/9.0_dp)*Cinv(ii, jj)*Cinv(kk, ll) &
                            + (I1/3.0_dp)*iic) &
                     + a_vol*Cinv(ii, jj)*Cinv(kk, ll) - b_vol*iic
               end do
            end do
         end do
      end do

      stat = DES_MAT_OK

      !> `pt` bu malzemede kullanılmıyor: Neo-Hookean ne sıcaklığa ne zamana
      !> ne de yarıçapa bağlıdır. Sözleşme gereği imzada bulunmak zorundadır;
      !> WLF kaydırmalı viskoelastik malzeme eklendiğinde imza değişmeyecek.
      associate (unused_pt => pt)
      end associate
   end subroutine nh_eval

end module des_mat_neohookean
