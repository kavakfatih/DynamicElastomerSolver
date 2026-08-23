!> ---------------------------------------------------------------------------
!> test_support -- doğrulama programları için ortak raporlama
!>
!> Yalnızca test/ altında kullanılır. src/ içindeki hiçbir modül buna
!> bağımlı değildir; çekirdek yazdırma yapmaz, bu modül yapar.
!>
!> Her kontrol tek satırda raporlanır: ölçülen değer, tolerans, sonuç.
!> Amaç, CI günlüğüne bakan birinin "geçti" yazısını değil SAYIYI görmesidir.
!> ---------------------------------------------------------------------------
module test_support
   use des_kinds, only: dp, ip
   implicit none
   private

   public :: t_begin, t_check_le, t_check_true, t_check_int, t_info, t_finish

   !> Başarısız kontrol sayacı.
   integer(ip) :: n_fail = 0_ip
   !> Toplam kontrol sayacı.
   integer(ip) :: n_check = 0_ip

contains

   !> Test programının başlığını yazar ve sayaçları sıfırlar.
   subroutine t_begin(title)
      character(len=*), intent(in) :: title

      n_fail = 0_ip
      n_check = 0_ip
      write (*, '(a)') '=============================================================='
      write (*, '(a)') title
      write (*, '(a)') '=============================================================='
   end subroutine t_begin

   !> Serbest metin satırı (bölüm başlıkları için).
   subroutine t_info(text)
      character(len=*), intent(in) :: text

      write (*, '(a)') text
   end subroutine t_info

   !> `value <= tol` bekler. Ölçülen değeri her hâlükârda yazdırır.
   subroutine t_check_le(label, value, tol)
      character(len=*), intent(in) :: label
      real(dp), intent(in) :: value
      real(dp), intent(in) :: tol

      n_check = n_check + 1_ip
      if (value <= tol) then
         write (*, '(a,a34,a,es11.4,a,es9.2,a)') &
            '  [ GECTI ] ', label, ' = ', value, '   (tol ', tol, ')'
      else
         n_fail = n_fail + 1_ip
         write (*, '(a,a34,a,es11.4,a,es9.2,a)') &
            '  [ KALDI ] ', label, ' = ', value, '   (tol ', tol, ')'
      end if
   end subroutine t_check_le

   !> Mantıksal koşul bekler.
   subroutine t_check_true(label, cond)
      character(len=*), intent(in) :: label
      logical, intent(in) :: cond

      n_check = n_check + 1_ip
      if (cond) then
         write (*, '(a,a34)') '  [ GECTI ] ', label
      else
         n_fail = n_fail + 1_ip
         write (*, '(a,a34)') '  [ KALDI ] ', label
      end if
   end subroutine t_check_true

   !> Tamsayı eşitliği bekler; her iki değeri de yazdırır.
   subroutine t_check_int(label, got, want)
      character(len=*), intent(in) :: label
      integer(ip), intent(in) :: got
      integer(ip), intent(in) :: want

      n_check = n_check + 1_ip
      if (got == want) then
         write (*, '(a,a34,a,i0)') '  [ GECTI ] ', label, ' = ', got
      else
         n_fail = n_fail + 1_ip
         write (*, '(a,a34,a,i0,a,i0)') &
            '  [ KALDI ] ', label, ' = ', got, '   beklenen ', want
      end if
   end subroutine t_check_int

   !> Özeti yazar; başarısızlık varsa sıfırdan farklı çıkış kodu üretir.
   subroutine t_finish()
      write (*, '(a)') '--------------------------------------------------------------'
      write (*, '(a,i0,a,i0,a)') '  ', n_check - n_fail, ' / ', n_check, ' kontrol gecti'
      write (*, '(a)') ''

      if (n_fail > 0_ip) error stop 1
   end subroutine t_finish

end module test_support
