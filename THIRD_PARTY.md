# Üçüncü Taraf Bağımlılıklar ve Lisans Politikası

DES/26, Business Source License 1.1 altında dağıtılır ve Değişim Tarihi'nde
(2030-01-01) Apache License 2.0'a döner. Bu, bağımlılık seçimini bir tercih
değil bir **kısıt** hâline getirir: bugün eklenen bir kütüphane, dört yıl
sonra Apache-2.0 altında dağıtılabilir olmalıdır.

---

## Mevcut durum

**v0.0.1 hiçbir üçüncü taraf kütüphaneye bağımlı değildir.**

Yalnızca Fortran 2018 standart kütüphanesi kullanılmaktadır. Kararlılık
kontrolü bile bilinçli olarak LAPACK'siz yazılmıştır: Cholesky ayrıştırması
doğrudan uygulanmıştır, çünkü pozitif tanımlılık kararı için özdeğer
çözücüsüne gerek yoktur ve çekirdeği bağımlılıksız tutmak taşınabilirliği
ucuzlatır.

---

## Politika

### İZİN VERİLEN

MIT, BSD-2-Clause, BSD-3-Clause, Apache-2.0, MPL-2.0, ISC, Zlib, Boost.

Serbestçe eklenebilir. Tek gereklilik, atıfların `NOTICE` dosyasına
yazılmasıdır.

### KOŞULLU

**LGPL** — yalnızca **dinamik bağlama (dynamic linking)** ile ve bir ADR
kaydıyla.

Statik bağlama, LGPL'in yeniden bağlama (relinking) yükümlülüğünü tetikler ve
kapalı kaynak dağıtımı karmaşıklaştırır. Dinamik bağlamada kullanıcı
kütüphaneyi değiştirebilir; yükümlülük karşılanır. Her LGPL bağımlılığı için
bağlama biçimini ve gerekçesini yazan bir ADR açılır.

### YASAK

GPL (tüm sürümler), AGPL, SSPL, "ticari kullanım yasaktır" kaydı taşıyan her
lisans, ve lisansı belirsiz olan her şey.

> **Bu yasak linklemenin ötesine geçer: KAYNAK KODUNU OKUMAYIN.**
>
> GPL bir kaynak dosyayı okuyup ardından aynı işi yapan kendi sürümünüzü
> yazmak, türev eser iddiasına açıktır. "Ben sadece baktım, kopyalamadım"
> savunması mahkemede ucuzdur ve bu riski almanın hiçbir teknik karşılığı
> yoktur.
>
> **Algoritmayı makalesinden öğrenin.** Yayımlanmış bir makaledeki matematik
> telif hakkına tabi değildir; o makaledeki denklemi Fortran'a yazmak
> serbesttir. Bir GPL projesinin `.cpp` dosyasını okuyup aynı şeyi yazmak
> serbest değildir.

Bu kural, yapay zekâ asistanları için de aynen geçerlidir. Bir asistandan
"şu GPL projesinin şu dosyasına bak" istenmez.

Ayrıntılı gerekçe: [docs/adr/0004-copyleft-bagimlilik-yok.md](docs/adr/0004-copyleft-bagimlilik-yok.md)

---

## Planlanan bağımlılıklar

Aşağıdakiler **henüz kullanılmıyor**. Yol haritasındaki sürümlerde
değerlendirilecekler; her biri eklendiğinde bu tablo ve `NOTICE`
güncellenecek.

| Bileşen | Lisans | Durum | Amaç |
|---|---|---|---|
| [FEBio](https://febio.org/) | MIT | Referans | Analitik çözümü olmayan problemlerde karşılaştırma hedefi |
| [TQMesh](https://github.com/pbayer/TQMesh) | MIT | v0.3 | Dörtgen/üçgen ağ üretimi |
| [fortran-lang/stdlib](https://github.com/fortran-lang/stdlib) | MIT | Değerlendiriliyor | Yardımcı sayısal rutinler |
| HDF5 | BSD-3-Clause | v0.5 | Sonuç ve yeniden başlatma (restart) dosyaları |
| VTK | BSD-3-Clause | v0.5 | Sonuç görselleştirme çıktısı |
| [ezdxf](https://ezdxf.mozman.at/) | MIT | v0.3 | DXF geometri içe aktarma |
| [Shapely](https://shapely.readthedocs.io/) | BSD-3-Clause | v0.3 | 2B geometri işlemleri |
| PySide6 | LGPLv3 | v0.6 | Qt arayüzü — **dinamik bağlama zorunlu** |

### İki özel not

**FEBio (MIT).** MIT lisanslı olduğu için kaynak kodu okumak serbesttir ve
kod kopyalanıp BUSL altında yeniden lisanslanabilir. Bu, DES/26'nın analitik
çözümü olmayan doğrulama problemlerinde (VER-020 ve sonrası) lisans sorunu
olmadan karşılaştırma yapabilmesi demektir. Bir hiperelastik çözücü için bu
küçük bir avantaj değildir.

**PySide6, PyQt6 DEĞİL.** İkisi de Qt bağlamasıdır ama lisansları farklıdır:
PySide6 LGPLv3'tür ve dinamik bağlamayla kullanılabilir; PyQt6 GPL'dir ve
ticari sürümü ayrıca satın alınmadıkça bu projeye giremez. Bu ayrım kolayca
gözden kaçar ve v0.6'da geri dönüşü pahalı bir hata olurdu.

---

## Yeni bağımlılık ekleme yordamı

1. Lisansı doğrula. "GitHub'da MIT yazıyordu" yeterli değil — `LICENSE`
   dosyasını ve alt dizinlerdeki istisnaları oku.
2. Yasak listesindeyse dur. Alternatif ara veya kendin yaz.
3. Koşullu listedeyse ADR aç.
4. İzin verilen listedeyse: atfı `NOTICE` dosyasına, satırı bu tablodaki
   listeye ekle.
5. Değişim Tarihi kontrolü: bu bağımlılık 2030'da Apache-2.0 altında
   dağıtılabiliyor mu?
