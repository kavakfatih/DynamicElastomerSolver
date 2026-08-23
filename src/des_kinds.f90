!> ---------------------------------------------------------------------------
!> des_kinds -- sayısal tür tanımları
!>
!> DES/26'nın tamamında kullanılan kayan nokta ve tamsayı türleri burada,
!> tek yerde tanımlanır. Hiçbir modül doğrudan `real(8)` veya
!> `double precision` yazmaz; böylece ileride bir hassasiyet değişikliği
!> gerekirse etkisi tek dosyayla sınırlı kalır.
!>
!> Katman: 5 -- Sayısal temel
!> ---------------------------------------------------------------------------
module des_kinds
   use, intrinsic :: iso_fortran_env, only: real64, int32
   implicit none
   private

   public :: dp, ip

   !> Çözücünün her yerinde kullanılan kayan nokta türü (çift hassasiyet).
   integer, parameter :: dp = real64

   !> Hata kodları, indisler ve sayaçlar için tamsayı türü.
   !> C ABI sınırında `int` ile birebir eşleşeceğinden 32 bit sabitlenmiştir.
   integer, parameter :: ip = int32

end module des_kinds
