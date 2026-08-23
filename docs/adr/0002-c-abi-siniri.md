# ADR 0002 — C ABI sınırı, katman 3 ile 4 arasında

**Durum:** KABUL EDİLDİ

---

## Bağlam

DES/26 üç dil kullanır: ağ ve geometri C++ (katman 3), analiz çekirdeği
Fortran (katman 4-5), orkestrasyon ve arayüz Python (katman 1-2). Bu
dillerin birbirini nasıl çağıracağı, projenin en sık dokunulacak
sınırlarından biridir.

Fortran ile C++ arasında doğrudan bir çağırma sözleşmesi yoktur. Ad
bozma (name mangling), dizi tanımlayıcıları (descriptor), string temsili
ve istisna yayılımı üç derleyici ailesinde üç farklı şekilde çalışır.

## Karar

Katman 3 ile katman 4 arasındaki **tek** geçiş noktası, düz bir C
arayüzüdür. Fortran tarafında `iso_c_binding` ve `bind(C)` kullanılır.

Sınırı geçebilecekler:

- `integer(c_int)`, `real(c_double)`, `logical(c_bool)` skalerleri
- Bitişik (contiguous) ham diziler ve boyut bilgisi ayrı bir tamsayı olarak
- Opak tutamaçlar (`type(c_ptr)`) — Fortran nesnelerine C tarafında
  tutulacak işaretçiler
- Sıfır sonlandırmalı C stringleri (yalnızca dosya yolları için)

Sınırı **geçemeyecekler**:

- Fortran türetilmiş tipleri (`type(material_state_t)` gibi)
- Tahsis edilebilir (allocatable) veya işaretçi dizi tanımlayıcıları
- Fortran karakter değişkenleri (uzunluk bilgisi ayrı taşınır)
- C++ şablonları, sınıfları, `std::` konteynerları
- **C++ istisnaları.** Bir istisnanın Fortran çerçevesinden geçmesi
  tanımsız davranıştır. C++ tarafındaki her `extern "C"` girişi kendi
  `try/catch` bloğunu taşır ve hatayı bir tamsayı koda çevirir.

Bellek sahipliği kuralı: **tahsis eden serbest bırakır.** C++ tarafında
tahsis edilen bir tampon, C++ tarafında serbest bırakılır; Fortran ona
yalnızca yazar.

## Gerekçe

**C ABI, ortak paydadır.** Her derleyici onu konuşur ve otuz yıldır
değişmedi. Fortran-C++ arasında doğrudan bir köprü kurmaya çalışmak,
gfortran + GCC, gfortran + MSVC, ifx + MSVC kombinasyonlarının her biri
için ayrı bakım demektir.

**Sınır, mimarinin en dar yeri olmalıdır.** Katman 3 ile 4 arasında geçen
şey, ağ verisi (düğüm koordinatları, bağlantı tablosu) ve sonuç verisidir
(yer değiştirmeler, gerilmeler). Bunlar düz sayı dizileridir. Zengin bir
arayüze ihtiyaç yoktur; zengin arayüz sunmak, bağlantıyı gereksiz yere
sıkılaştırır.

**İstisna yalıtımı, tartışma konusu değildir.** Bir C++ `std::bad_alloc`
istisnasının Fortran yığın çerçevesini geçmesi çökme veya sessiz bozulma
üretir. Bu, hata ayıklaması en pahalı hata sınıfıdır.

**Python bedavaya gelir.** C ABI üzerinden `ctypes` veya `cffi` ile
bağlanmak, ek bir sarmalayıcı katmanı gerektirmez. Aynı sınır iki tüketiciye
birden hizmet eder.

## Sonuçlar

**Olumlu**

- Derleyici kombinasyonları bağımsız: gfortran + MSVC çalışır
- Python bağlaması ek iş gerektirmez
- Sınır dar olduğu için test edilmesi kolay
- Fortran çekirdeği, C++ katmanı olmadan da (testlerde olduğu gibi) tek
  başına derlenip çalışabilir

**Olumsuz**

- Sınırda elle veri paketleme gerekir. Bir ağ yapısını düz dizilere açmak
  ve öbür tarafta yeniden kurmak sıkıcı ve hata açısından risklidir.
- Tip güvenliği sınırda kaybolur. `real(c_double), dimension(*)` bir
  tamsayı dizisi de olabilir; derleyici yakalamaz. Bu yüzden sınır
  yordamları için ayrı sözleşme testleri yazılacaktır.
- Opak tutamaç kullanımı, sahiplik kurallarının belgelenmesini zorunlu
  kılar; sızıntı riski elle yönetilir.

## Değerlendirilen alternatifler

**Doğrudan Fortran-C++ bağlaması.** Bazı derleyici çiftlerinde işe yarar
(gfortran + GCC). Reddedildi: hedef platformlar arasında Windows + MSVC
var ve orada ad bozma kuralları uyuşmuyor. Bir kez çalışan bir hack,
derleyici sürümü yükseldiğinde sessizce kırılır.

**Her şeyi tek dilde yazmak.** Ağ üretimini Fortran'da yazmak
([ADR 0001](0001-fortran-hesaplama-cekirdegi.md) gerekçelerinin tersi
yönde) veya çekirdeği C++'ta yazmak, sınırı tamamen ortadan kaldırırdı.
Reddedildi: her iki dil de kendi alanında açık ara daha iyi ve sınırın
maliyeti, yanlış dilde çalışmanın maliyetinden düşük.

**SWIG veya benzeri bir sarmalayıcı üretici.** Reddedildi: üretilen kod
okunabilir değil, hata ayıklaması zor ve araç zincirine bir bağımlılık daha
ekliyor. Sınır zaten dar; elle yazmak birkaç yüz satır tutar.

**Fortran'dan doğrudan Python'a (f2py).** Katman 3'ü atlayıp Python'u
doğrudan çekirdeğe bağlamak cazip. Reddedildi: ağ katmanı arada durmak
zorunda, çünkü yeniden ağ örme (v0.5) çözüm döngüsünün içinde çalışacak —
Python üzerinden gidip gelmek kabul edilemez bir gecikme üretir.
