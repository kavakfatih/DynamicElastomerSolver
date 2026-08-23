!> ---------------------------------------------------------------------------
!> des26 -- geçici duman testi (smoke test) sürücüsü
!>
!> Bu program bir kullanıcı arayüzü DEĞİLDİR. Çekirdeğin kurulup
!> çalıştığını göstermek için tek bir malzeme noktası değerlendirir.
!>
!> Gerçek arayüz v0.2'de (CLI) ve v0.6'da (Qt) gelecektir. Mimari kural
!> gereği çekirdek metin üretmez; buradaki çıktı da bilinçli olarak ham
!> sayılardan ve durum KODLARINDAN ibarettir. Kodların insan diline
!> çevrilmesi üst katmanın işidir (messages/tr.toml).
!>
!> Katman: 1 -- Sunum (geçici)
!> ---------------------------------------------------------------------------
program des26
   use des_kinds, only: dp, ip
   use des_material, only: mat_point_t, material_state_t
   use des_mat_neohookean, only: mat_neohookean_t, new_neohookean
   implicit none

   type(mat_neohookean_t) :: mat
   type(mat_point_t)      :: pt
   type(material_state_t) :: sn, snp1

   real(dp) :: C(3, 3), S(3, 3), CC(3, 3, 3, 3)
   real(dp) :: dt_factor, margin
   integer(ip) :: stat, sstat, i

   mat = new_neohookean(0.6_dp, 1.0e5_dp)
   call sn%init(mat%n_sv)
   call snp1%init(mat%n_sv)

   !> F = diag(1.2, 0.95, 0.95) -> C = F^T F
   C = 0.0_dp
   C(1, 1) = 1.44_dp
   C(2, 2) = 0.9025_dp
   C(3, 3) = 0.9025_dp

   call mat%eval(C, pt, sn, S, CC, snp1, stat, dt_factor)
   call mat%check_stability(C, pt, sn, snp1, sstat, margin)

   write (*, '(a)') 'DES/26  0.0.1'
   write (*, '(a,a)') 'material  : ', trim(mat%name)
   write (*, '(a,i0)') 'mat_stat  : ', stat
   write (*, '(a,f8.5)') 'dt_factor : ', dt_factor
   write (*, '(a,i0)') 'stab_stat : ', sstat
   write (*, '(a,es13.6)') 'stab_marj : ', margin
   write (*, '(a)') 'S ='
   do i = 1, 3
      write (*, '(3es16.8)') S(i, 1), S(i, 2), S(i, 3)
   end do

end program des26
