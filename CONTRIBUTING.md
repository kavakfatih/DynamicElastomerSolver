# Katkı Rehberi

DES/26'ya katkıda bulunduğunuz için teşekkürler. Bu proje bir mühendislik
aracıdır; bir hesaplama hatası, kullanıcının ürününde bir çatlak demektir.
Aşağıdaki kurallar bu yüzden katıdır.

Başlamadan önce [CLAUDE.md](CLAUDE.md) dosyasını okuyunuz — orada yazan
kurallar insan katkıcılar için de bağlayıcıdır.

---

## Dil

Yorumlar, dokümanlar ve commit mesajları **Türkçe**. Kod tanımlayıcıları
(modül, tip, değişken, fonksiyon adları) **İngilizce**.

```fortran
!> Hacim oranını hesaplar ve tekillik durumunda haber verir.
pure function det3(A) result(d)
```

Türkçe karakterler yalnızca yorumlarda kullanılır; tanımlayıcılar ve karakter
sabitleri ASCII kalır. gfortran bunun için ek bayrak gerektirmez.

---

## Dört kırmızı çizgi

### 1. `ctest` çalıştırmadan "çalışıyor" demeyin

Sayısal bir değişiklik yaptıysanız testi çalıştırın ve **çıkan sayıyı** PR
açıklamasına yazın. "Düzeltmiş olmalı" bir doğrulama değildir.

### 2. Tolerans gevşetmeyin

Bir test kalıyorsa sebebi bulunur. Toleranslar mühendislik kararıdır,
gerekçeleri [docs/dogrulama/DOGRULAMA-PLANI.md](docs/dogrulama/DOGRULAMA-PLANI.md)
içinde yazılıdır. Bir toleransın gerçekten değişmesi gerekiyorsa: önce bir
issue açın, sonra gerekçeyi doğrulama planına yazın, sonra değiştirin.

Testi yeşile boyamak bir çözüm değildir; bir hatayı gizlemektir.

### 3. GPL/AGPL kaynak kodu okumayın

Bağımlılık eklemek de yasak, kaynak kodunu okumak da.
[THIRD_PARTY.md](THIRD_PARTY.md) dosyasına bakınız. Algoritmayı makalesinden
öğrenin.

### 4. Dondurulmuş sözleşmeleri ADR yazmadan değiştirmeyin

Malzeme arayüzü, eleman arayüzü, doğrusal çözücü arayüzü ve durum aktarımı.
Bunlar üzerlerine yazılacak her şeyin temelidir.

---

## Yanlış gördüğünüzü söyleyin

Bir tasarım kararı size hatalı görünüyorsa **sessizce etrafından
dolaşmayın**, sessizce de uygulamayın. Söyleyin.

Bu bir nezaket kuralı değil, bir mühendislik kuralıdır. Somut örnek:
[ADR 0007](docs/adr/0007-kararlilik-kriteri.md). Genel Drucker kararlılık
kontrolü tam olarak istendiği gibi uygulandı; sonra davranışının neredeyse
sıkıştırılamaz malzemelerde yanıltıcı olduğu ölçüldü ve rapor edildi.
Kontrol yerinde duruyor, karar açık — ama kimse bunu sessizce "düzeltip"
geçmedi.

---

## Geliştirme döngüsü

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

Depo **sıfır derleyici uyarısı** ile derlenir. Yeni bir uyarı üretmek
regresyondur; `-Wall -Wextra` çıktısını temiz tutun.

fpm kullanacaksanız **ayrı bir yapı dizini** verin — fpm de varsayılan
olarak `build/` kullanır ve CMake ile aynı dizini paylaşırlarsa iki çıktı
ağacı iç içe girer:

```sh
fpm test --build-dir build-fpm
```

Release yapısını da kontrol edin — optimizasyon altında değişen bir sayı,
tanımsız davranışın habercisidir:

```sh
cmake -B build-rel -DCMAKE_BUILD_TYPE=Release
cmake --build build-rel --parallel
ctest --test-dir build-rel
```

---

## Kod biçimi

- Girinti 3 boşluk, sekme yok.
- Satır uzunluğu en fazla 90 karakter.
- Her modül ve her açık (public) yordam `!>` blok yorumuyla başlar.
- `implicit none` her modülde ve her programda.
- `private` varsayılan, `public` açıkça listelenir.
- `use` her zaman `only:` ile.
- Tek harfli değişken adlarına dikkat: Fortran büyük/küçük harf duyarsızdır.
  Hacim oranı `J` ile döngü indisi `j` aynı isimdir; tensör döngülerinde
  `ii, jj, kk, ll` kullanılır.

---

## Test yazma

**Belirlenimci (deterministic) olun.** Rastgele girdi kullanmayın. CI'da
kırmızıya dönen bir kontrol, aynı sayılarla tekrar üretilebilmelidir.

**Sayıyı bastırın.** Test çıktısı "GEÇTİ" değil, ölçülen değer ve tolerans
göstermelidir. CI günlüğüne bakan biri, marjın ne kadar daraldığını
görebilmelidir.

**Toleransın gerekçesini yazın.** Her tolerans için: bu sayı neden bu?
Yuvarlama tabanı mı, fiziksel bir sapma mı, kesme hatası mı?

Yeni bir doğrulama problemi ekliyorsanız doğrulama planına bir VER-xxx satırı
ekleyin: bağımsız referans, tolerans, toleransın gerekçesi.

---

## Commit ve PR

Commit mesajları Türkçe, emir kipinde, ilk satır 72 karakteri geçmeyecek:

```
Neo-Hookean tanjantinda indis cakismasini duzelt

Hacim orani J ile dongu indisi j Fortran'da ayni isim. Dongu
indisleri ii/jj/kk/ll yapildi.

ctest: 3/3 gecti, tanjant bagil hatasi 1.04e-10 (degismedi).
```

PR açıklamasında bulunması gerekenler:

- Ne değişti ve neden
- `ctest` çıktısı — özellikle **değişen** ve **değişmeyen** sayılar
- Dondurulmuş bir sözleşmeye dokunulduysa ilgili ADR bağlantısı
- Yeni bağımlılık varsa lisansı ve `THIRD_PARTY.md` güncellemesi

---

## ADR yazma

Mimari bir karar alıyorsanız `docs/adr/` altına numaralı bir dosya ekleyin.
Biçim: Bağlam, Karar, Gerekçe, Sonuçlar, Alternatifler. Reddedilen
alternatifleri **neden** reddettiğinizi yazın — altı ay sonra o soruyu tekrar
soran kişi büyük ihtimalle siz olacaksınız.

Durum alanı: ÖNERİLDİ, KABUL EDİLDİ, REDDEDİLDİ, YERİNİ ALDI (0000).
