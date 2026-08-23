# CLAUDE.md — DES/26 proje kuralları

Bu dosya, bu depoda çalışan her yapay zekâ asistanı ve her yeni katkıcı için
bağlayıcı kuralları içerir. Kod yazmadan önce okunur.

DES/26 (DynamicElastomerSolver 2026), elastomer ve kauçuk bileşenler için
2B nonlineer sonlu elemanlar (finite element) çözücüsüdür. Hedef ürünler:
burulmalı titreşim damperi (torsional vibration damper) kauçuğu, decoupler,
burç (bushing), motor takozu, şanzıman takozu, kaplin.

---

## Dil kuralı

**Yorumlar ve dokümanlar Türkçedir. Kod tanımlayıcıları İngilizcedir.**

Türkçe kalır: tüm `!>` ve `!` yorum satırları, tüm Markdown dokümanları,
Python docstring'leri, commit mesajları.

İngilizce kalır: modül, tip, değişken, fonksiyon, parametre adları
(`des_material`, `check_stability`, `dt_factor`, `DES_MAT_OK`), dosya ve
dizin adları, `LICENSE` dosyası, CI komutları.

Gerekçe: kod tanımlayıcılarının İngilizce olması, kütüphaneyi uluslararası
bir kullanıcıya ve ANSYS/Marc/Abaqus konvansiyonlarından gelen bir mühendise
okunabilir tutar. Yorumların Türkçe olması, asıl geliştirme ekibinin
düşündüğü dilde düşünmesini sağlar.

Yerleşik Türkçe karşılığı olan terimler çevrilir: gerilme, şekil değiştirme,
yakınsama, eleman, düğüm, tanjant, sıkıştırılamazlık. Literatür terimi olarak
yerleşmiş İngilizce ifadeler ilk geçtiği yerde parantez içinde verilir —
"tutarlı tanjant (consistent tangent)" — sonra Türkçesi kullanılır.

### UTF-8

Fortran kaynak dosyalarında Türkçe karakterler (ç ğ ı ö ş ü) yorumlarda
serbestçe kullanılır. gfortran bunun için **ek bayrak gerektirmez**;
`-finput-charset` seçeneği Fortran'da geçersizdir ve verilirse uyarı üretir.
Ayrıntı: `CMakeLists.txt` içindeki UTF-8 notu.

Türkçe karakterler yalnızca **yorumlarda** kullanılır. Tanımlayıcılar ve
karakter sabitleri ASCII kalır.

---

## Bozulmaz kurallar

### 1. `ctest` çalıştırmadan sayısal bir değişikliğin çalıştığını ASLA iddia etme

"Düzeltmiş olmalı", "artık doğru olmalı" gibi ifadeler bu projede
kabul edilmez. Sayısal bir değişiklik yaptıysan testi çalıştır ve ÇIKAN
SAYIYI yaz. Test çalıştırılmadıysa bunu açıkça söyle.

### 2. Testi geçirmek için tolerans GEVŞETME

Bir test kalıyorsa sebebi bulunur. Tolerans bir mühendislik kararıdır ve
gerekçesi `docs/dogrulama/DOGRULAMA-PLANI.md` içinde yazılıdır; testi yeşile
boyamak için değiştirilemez. "Geçiyor" bir tolerans gerekçesi değildir.

Tolerans değişikliği gerçekten gerekiyorsa: önce sor, sonra gerekçeyi
doğrulama planına yaz.

### 3. GPL/AGPL bağımlılık ekleme — ve GPL kaynak KODU OKUMA

Yasak lisanslar: GPL, AGPL, SSPL ve "ticari kullanım yasak" kaydı taşıyan
her şey. Kural linklemenin ötesine geçer: **kaynak kodunu okuma.** GPL kod
okuyup sonra kendi versiyonunu yazmak, türev eser iddiasına açıktır.
Algoritmayı makalesinden öğren.

Ayrıntı: `THIRD_PARTY.md` ve `docs/adr/0004-copyleft-bagimlilik-yok.md`.

### 4. Dört dondurulmuş sözleşmeyi ADR yazmadan değiştirme

1. **Malzeme arayüzü** — `src/des_material.f90` (ADR 0006)
2. **Eleman arayüzü** — düğüm başına değişken DOF + eleman-dışı global DOF
   + formülasyon stratejisi
3. **Doğrusal çözücü arayüzü** — simetrik indefinite destekli
4. **Durum aktarımı** — serialise / restore / project

Bu arayüzler, üzerlerine yazılacak her şeyin temelidir. Değiştirmek
istiyorsan önce ADR yaz, sonra değiştir.

### 5. Kapsamı genişletme

`docs/KAPSAM.md` içinde "DIŞINDA" yazan şeyler kalıcı olarak dışarıdadır:
3B, metal plastisitesi, açık (explicit) dinamik, CFD. "ERTELENDİ" yazanlar
kendi sürümlerini bekler.

İyi bir fikrin varsa ADR öner. Sessizce ekleme.

### 6. `src/` içinde `stop`, `print`, dosya G/Ç YOK

Hesaplama çekirdeği metin üretmez ve programı sonlandırmaz. Hata `stat` ile,
adım küçültme talebi `dt_factor` ile bildirilir. Sebep: aynı çekirdek hem
CLI'dan hem Qt'den hem de bir Python betiğinden çağrılacak; hangisinin
çalıştığını bilemez ve kullanıcıya nasıl hitap edileceğine karar veremez.

İstisna: karakter değişkenine yapılan iç yazma (internal write) G/Ç
sayılmaz, serbesttir.

`test/` ve `app/` bu kuralın dışındadır; onlar sunum katmanıdır.

### 7. Kullanıcıya görünen metin kodda gömülü olmaz

Fortran çekirdeği hata KODU döndürür. Kodun insan diline çevrilmesi
`messages/tr.toml` ve `messages/en.toml` üzerinden üst katmanın işidir.
Ayrıntı: `docs/adr/0008-cok-dillilik.md`.

### 8. Ondalık ayırıcı: dosyalarda HER ZAMAN nokta

Girdi ve çıktı dosyalarında ondalık ayırıcı **noktadır**, locale'den
bağımsız. Virgül yalnızca ekranda gösterimde kullanılabilir.

Gerekçe: bir FEA modelinde `1,5` ile `1.5` karışırsa model sessizce yanlış
okunur ve sonuç makul görünmeye devam eder. Bu, çok dilli teknik
yazılımların klasik ve pahalı hatasıdır.

---

## Çalışma alışkanlıkları

**Tasarımda yanlış gördüğün şeyi söyle.** Bir spesifikasyon sana hatalı
görünüyorsa sessizce etrafından dolaşma, sessizce de uygulama. Söyle.
Bu kuralın somut bir örneği için `docs/adr/0007-kararlilik-kriteri.md`
dosyasına bak: genel Drucker kontrolü tam olarak istendiği gibi uygulandı,
sonra davranışının beklenenden farklı olduğu ölçülüp rapor edildi.

**Sayı göster.** "Hata küçük" değil, "bağıl hata 4.8e-06".

**Belirlenimci (deterministic) test yaz.** Rastgele girdi kullanma; CI'da
kırmızıya dönen bir kontrol tekrar üretilebilir olmalıdır.

---

## Derleme ve test

```
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

Alternatif olarak fpm — ama **ayrı bir yapı dizini ile**, çünkü fpm de
varsayılan olarak `build/` kullanır ve CMake ile çakışır:

```
fpm build --build-dir build-fpm
fpm test  --build-dir build-fpm
```

Derleyici bayrakları `CMakeLists.txt` içinde tanımlıdır. Ortak:
`-std=f2018 -Wall -Wextra -fimplicit-none`. Depo **sıfır uyarı** ile
derlenir; yeni bir uyarı üretmek regresyondur.

---

## Dizin düzeni

```
src/    Fortran hesaplama çekirdeği (katman 4-5). Yazdırmaz, durmaz.
test/   Doğrulama programları. Yazdırır.
app/    Geçici duman testi (smoke test) sürücüsü.
docs/   Mimari, kapsam, yol haritası, ADR'ler, teori, doğrulama planı.
messages/  Hata kodu -> metin eşlemeleri (tr, en).
```
