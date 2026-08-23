# ADR 0001 — Hesaplama çekirdeği Fortran 2018

**Durum:** KABUL EDİLDİ

---

## Bağlam

DES/26'nın hesaplama çekirdeği, sıkı iç içe döngülerden oluşur: her
integrasyon noktasında bir malzeme değerlendirmesi (3x3 tensör cebiri,
4. mertebe tanjant), her elemanda bir sertlik matrisi montajı, her Newton
adımında bunların tekrarı. Tipik bir eksenel simetrik damper analizinde bu,
milyonlarca malzeme çağrısı demektir.

Dil seçimi, projenin geri dönüşü en pahalı kararıdır.

## Karar

Katman 4 (analiz çekirdeği) ve katman 5 (sayısal temel) **Fortran 2018** ile
yazılır.

Kullanılan modern özellikler: türetilmiş tipler ve tip-bağlı yordamlar
(soyut malzeme arayüzü için), `intent` belirteçleri, `pure` yordamlar,
`iso_fortran_env` ile taşınabilir tür tanımları, `associate` blokları,
tahsis edilebilir (allocatable) diziler.

Kullanılmayanlar: `common` blokları, `equivalence`, sabit biçim (fixed
form), örtük tip (implicit typing), `goto`. `implicit none` her yerde
zorunludur ve `-fimplicit-none` bayrağıyla derleyici tarafından da dayatılır.

## Gerekçe

**Dizi semantiği ve takma ad (aliasing).** Fortran'da dummy argümanların
takma ad yapmadığı varsayılır. C'de derleyici bunu varsayamaz ve her yazma
işleminden sonra yeniden yükleme yapmak zorunda kalır (`restrict` ile elle
söylenmedikçe). Sıkı tensör döngülerinde bu, ölçülebilir bir fark üretir.
Çok boyutlu dizilerin dilin birinci sınıf vatandaşı olması da aynı yöne
çalışır: `CC(i,j,k,l)` bir işaretçi aritmetiği değil, bir dizi erişimidir.

**Ekosistem.** Doğrusal cebir (LAPACK, PARDISO), FE literatürünün referans
uygulamaları ve mevcut kurumsal kod tabanları Fortran konuşur. Bir
UMAT/USERMAT yazmış mühendis, `des_material.f90` arayüzünü açtığında ne
gördüğünü anlar.

**Kararlılık.** Fortran standardı geriye dönük uyumluluğa fanatikçe
bağlıdır. 2026'da yazılan bir modül 2040'ta derlenecektir. Bu, on yıllık
ömrü olan bir mühendislik aracı için önemsiz bir özellik değildir.

**Derleyici kalitesi.** gfortran ücretsiz ve her platformda mevcut; Intel
ifx, Intel donanımında ciddi bir hız avantajı sunar. İkisi de aynı
standardı derler.

## Sonuçlar

**Olumlu**

- Sıkı döngülerde iyi kod üretimi, elle optimizasyona az ihtiyaç
- `-fcheck=all` ile dizi sınırı kontrolü, geliştirme sırasında ucuz güvenlik
- Türetilmiş tipler ve soyut arayüzler sayesinde malzeme kütüphanesi
  genişletilebilir kalıyor — bu, FORTRAN 77 ile mümkün olmazdı

**Olumsuz**

- Karakter işleme ve dosya biçimleri Fortran'da acı vericidir. Bu yüzden
  zaten katman 4'te yasaktır ([ADR 0002](0002-c-abi-siniri.md)) — yasağın
  bir kısmı erdemden değil zaruretten doğmuştur, kabul.
- Paket yöneticisi ekosistemi zayıf. fpm gelişiyor ama CMake asıl yol olarak
  kalıyor.
- Büyük/küçük harf duyarsızlık gerçek bir tuzaktır: hacim oranı `J` ile
  döngü indisi `j` **aynı isimdir**. Bu, v0.0.1 geliştirmesinde fiilen
  yaşandı; tensör döngülerinde `ii, jj, kk, ll` kuralı buradan doğdu.
- Havuz küçük. Fortran bilen geliştirici bulmak, C++ bilen bulmaktan zordur.

## Değerlendirilen alternatifler

**C++** — Katman 3'te kullanılıyor, çekirdek için değerlendirildi ve
reddedildi. Şablon ağırlıklı tensör kütüphaneleri (Eigen, Blaze) ifade
gücü sunar ama derleme süresi ve hata mesajı karmaşıklığı ciddi bir vergi
alır. Takma ad sorunu `restrict` ile çözülebilir, ama her yerde doğru
uygulamak disiplin ister ve bir kez unutulduğunda sessizce yavaşlar.

**Julia** — Sayısal ifade gücü mükemmel, çok çekici. Reddedilme sebebi
dağıtım: müşteriye bir Julia çalışma zamanı ve JIT ısınma süresi göndermek,
ticari bir mühendislik aracı için kabul edilebilir değil. Bir de ekosistemin
kararlılık geçmişi, on yıllık bir bağlılık için henüz yeterince uzun değil.

**Rust** — Bellek güvenliği garantileri çekici. İki sebeple reddedildi: çok
boyutlu dizi ergonomisi bilimsel hesaplama için hâlâ olgunlaşmamış durumda
(`ndarray` iyi ama Fortran'ın diline gömülü desteğiyle yarışmıyor), ve FE
literatürüyle/mevcut kodla köprü kurmak sıfırdan yazmayı gerektiriyor.

**Fortran 90/95** — Modern Fortran'ın soyut tipleri ve `class` mekanizması
olmadan, malzeme kütüphanesi ya `select case` ağaçlarına ya da işlev
işaretçisi tablolarına dönerdi. 2018'e bağlanmanın maliyeti, derleyici
sürümü gereksinimidir (gfortran 13+); bu kabul edilebilir bulundu.
