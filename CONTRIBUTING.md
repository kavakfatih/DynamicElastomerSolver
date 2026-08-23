# Katkı Rehberi

DES/26'ya katkıda bulunduğunuz için teşekkürler. Bu proje bir mühendislik
aracıdır; bir hesaplama hatası, kullanıcının ürününde bir çatlak demektir.
Aşağıdaki kurallar bu yüzden katıdır.

Başlamadan önce [AGENTS.md](AGENTS.md) dosyasını okuyunuz — orada yazan
kurallar insan katkıcılar için de bağlayıcıdır. (`CLAUDE.md` aynı dosyaya
bağlı bir symlink'tir.)

Araç zinciri ayrıntıları, derleyici bayrakları ve sıfır uyarı kuralının
kapsamı: [docs/TOOLCHAIN.md](docs/TOOLCHAIN.md).

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

Bu bir nezaket kuralı değil, bir mühendislik kuralıdır. Bu depoda iki kez
işe yaradı:

- **VER-001 referans değeri.** Verilen beklenti 3.599964 idi; doğrusu sonlu
  K için 9Kμ/(3K+μ) = **3.599986**. Spesifikasyondaki değer sonlu fark
  türevinden gelen 2.2e-5'lik bir hata taşıyordu.
- **[ADR 0007](docs/adr/0007-kararlilik-kriteri.md) kararlılık ölçütü.**
  Tam tanjant pozitif tanımlılığı yanlış ölçüttü: sağlıklı bir Neo-Hookean
  (C10 = +0.6, K = 1e3) F = diag(1.40, 0.85, 0.85) altında
  dC:CC:dC = **−3.9389e+01** verir. Ölçüt mod bazlı monotonluğa
  (dP/dλ > 0) değiştirildi.

İkisi de spesifikasyondaki hatalardı ve sorgulandıkları için düzeldiler.
Kimse sessizce etrafından dolaşmadı.

---

## Geliştirme döngüsü

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

Depo **sıfır uyarı** ile derlenir ve bu kural **iki** aracı birden
kapsar: derleyici (`-Wall -Wextra`) ve **fortls**. fortls, gfortran'ın
yakalamadığı host değişkeni maskelemesini yakalar; o uyarı gerçek bir
hatadır. Ayrıntı: [docs/TOOLCHAIN.md](docs/TOOLCHAIN.md).

```sh
pip install fortls
for f in src/*.f90 test/*.f90 app/*.f90; do
  fortls --debug_rootpath . --debug_filepath "$f" --debug_diagnostics
done
```

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
- **Yorumlarda `/` ve `*` karakterlerini yan yana yazmayın.** Ninja
  üreticisi, modül bağımlılık grafiğini çıkarmak için kaynakları C ön
  işlemcisinden geçirir; ön işlemci böyle bir diziyi C blok yorumu
  başlangıcı sanar ve `Error: unterminated comment` verir. Bu tuzak
  Makefile üreticisinde **sessizce çalışır** — yerelde `make` kullanıyorsanız
  göremezsiniz, Windows CI'da patlar. `messages/tr.toml ve en.toml` yazın,
  yıldızlı kısayolu değil. CI'da `kaynak-denetimi` işi bunu denetler.

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
