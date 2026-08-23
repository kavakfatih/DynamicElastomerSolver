# ADR 0008 — Çok dillilik ve ondalık ayırıcı

**Durum:** KABUL EDİLDİ

Uygulama: [`messages/tr.toml`](../../messages/tr.toml),
[`messages/en.toml`](../../messages/en.toml)

---

## Bağlam

DES/26'nın birincil arayüz dili Türkçedir. İngilizce sonradan eklenecektir
(v0.6, Qt arayüzüyle birlikte). Altyapının **şimdi** kurulması gerekir:
çok dilliliği sonradan eklemek, o güne kadar yazılmış her mesajı bulup
çıkarmak demektir ve o iş asla tam yapılmaz.

Ayrıca teknik bir yazılımda dil, yalnızca metin sorunu değildir. Sayı
biçimlendirmesi de locale'e bağlıdır ve bir FEA çözücüsünde bu, sessiz
veri bozulmasının kapısıdır.

## Kararlar

### 1. Fortran çekirdeği metin üretmez, kod döndürür

`src/` altındaki hiçbir modül `print`, `write(*,...)` veya dosya G/Ç
yapmaz. Hata bilgisi `stat` tamsayı kodu ile, adım küçültme talebi
`dt_factor` ile bildirilir.

(İstisna: karakter değişkenine yapılan iç yazma (internal write) G/Ç
sayılmaz. `default_sv_name` bunu kullanır.)

Gerekçe: aynı çekirdek CLI'dan, Qt arayüzünden ve toplu bir Python
betiğinden çağrılacak. Hangisinin çalıştığını bilemez, kullanıcının dilini
bilemez, hatta bir kullanıcı olup olmadığını bilemez.

### 2. Kullanıcıya görünen hiçbir metin kodda gömülü olmaz

Bu, çekirdeğin ötesine geçer: Python ve C++ katmanlarında da kullanıcıya
gösterilecek metin, kaynak dosyada değil çeviri kaynağında durur.

Kod tarafında yalnızca **anahtarlar** bulunur ve anahtarlar İngilizce,
ASCII ve büyük harflidir: `DES_MAT_NONPHYSICAL`, `SV1`, `DAMAGE`.
`material_t%name` ve `sv_name()` de bu kategoridedir — bunlar kullanıcı
metni değil, çeviri tablosunun anahtarlarıdır.

### 3. ONDALIK AYIRICI: dosyalarda HER ZAMAN nokta

Girdi ve çıktı dosyalarında ondalık ayırıcı noktadır — locale'den bağımsız,
değişmez (invariant). Virgül **yalnızca ekranda gösterimde** kullanılabilir
ve orada locale'e göre biçimlenir.

Bu, bu ADR'nin en önemli maddesidir.

Gerekçe: bir FEA modelinde `1,5` ile `1.5` karışırsa model **sessizce**
yanlış okunur. Ayrıştırıcı hata vermez, çözücü yakınsar, sonuç makul
görünür — ve malzeme sabiti on kat yanlıştır. Daha kötüsü, `1,5` bir CSV
veya boşlukla ayrılmış dosyada iki ayrı alana bölünebilir ve tüm sütunlar
kayar.

Bu, çok dilli teknik yazılımların klasik ve pahalı hatasıdır. Türkçe
locale (`tr_TR`) ondalık ayırıcı olarak virgül kullanır; bir kullanıcının
makinesinde locale'e duyarlı bir `printf`/`format` çağrısı, o makinede
üretilen dosyayı başka bir makinede okunamaz kılar.

Uygulama kuralları:

- Fortran'ın liste yönlendirmeli ve biçimli G/Ç'si zaten locale'den
  bağımsızdır; ek önlem gerekmez.
- Python katmanında sayı ayrıştırma ve yazma için **asla** `locale`
  modülüne dayanılmaz. `float()` ve `repr()`/`format()` varsayılan (C)
  davranışıyla kullanılır.
- C++ katmanında akışlar (streams) açıkça `std::locale::classic()` ile
  kurulur.
- Ekranda gösterim için ayrı bir biçimlendirme fonksiyonu kullanılır ve
  bu fonksiyonun çıktısı **asla dosyaya yazılmaz**.

Aynı ilke tarih ve saat için de geçerlidir: dosyalarda ISO 8601.

### 4. Qt katmanı standart Qt yolunu kullanır

v0.6'daki Qt arayüzü, kendi metinleri için standart `tr()` çağrılarını ve
Qt Linguist `.ts` / `.qm` dosyalarını kullanır. `messages/*.toml`
dosyalarını yeniden uygulamaya çalışmaz.

Gerekçe: Qt'nin çeviri altyapısı olgun, araçları (Qt Linguist) çevirmen
dostu ve çoğullaştırma (pluralization) desteği var. Onu atlayıp kendi
mekanizmamızı Qt widget'larına dayatmak, kazanç sağlamadan sürtünme
yaratır.

İki mekanizma bir arada yaşar: `messages/*.toml` **çekirdek hata
kodlarının** çevirisidir ve tüm ön yüzler (CLI, Python API, Qt) tarafından
paylaşılır; `.ts`/`.qm` ise **yalnızca Qt arayüzünün kendi metinlerini**
(menü, düğme, etiket) taşır.

### 5. Varsayılan dil Türkçe

Varsayılan `tr`. Değiştirme yolu, öncelik sırasıyla:

1. Açık API/CLI parametresi
2. `DES26_LANG` ortam değişkeni (`tr`, `en`)
3. Uygulama ayar dosyası
4. Varsayılan: `tr`

Sistem locale'i **bilinçli olarak kullanılmaz**. Sebep: locale, sayı
biçimini de taşır ve dil seçimini locale'e bağlamak, 3. maddedeki ayrımı
bulanıklaştırır. Dil bir tercih, sayı biçimi bir veri sözleşmesidir; ikisi
ayrı kalır.

Bilinmeyen bir anahtar istendiğinde: önce `en`e düşülür, o da yoksa
anahtarın kendisi ham olarak gösterilir. Boş string döndürülmez — kullanıcı
"bir şey oldu ama ne olduğunu söylemiyor" durumuyla karşılaşmamalıdır.

## Dosya biçimi

TOML. Her hata kodu bir bölüm, her bölümde iki alan:

```toml
[DES_MAT_NONPHYSICAL]
mesaj = "Eleman ters dönmüş (J <= 0)"
oneri = "Yük adımını küçültün veya bu bölgede mesh'i sıklaştırın."
```

`mesaj` **ne olduğunu**, `oneri` **kullanıcının ne yapması gerektiğini**
söyler. İkincisi zorunludur.

Gerekçe: "Malzeme değerlendirmesi başarısız" bir hata mesajı değil, bir
hata bildirimidir. Kullanıcının elinde bir sonraki adım yoksa mesaj işe
yaramamıştır. Bir mühendis "eleman ters dönmüş" cümlesinden ne yapacağını
çıkarabilir, ama çıkarmak zorunda kalmamalıdır.

İngilizce dosyada alan adları da İngilizcedir (`message`, `suggestion`);
anahtarlar (bölüm adları) iki dosyada birebir aynıdır.

## Sonuçlar

**Olumlu**

- Yeni dil eklemek bir dosya kopyalayıp çevirmekten ibaret
- Çekirdek, ön yüzden tamamen bağımsız kalıyor
- Ondalık ayırıcı kuralı, sınıfının en sinsi hatasını baştan kapatıyor
- Hata mesajları "ne yapmalı" bilgisi taşımaya zorlanıyor

**Olumsuz**

- İki çeviri mekanizması bir arada (TOML + Qt `.ts`). Sınırı net tutmak
  disiplin ister; sınır bulanırsa aynı metin iki yerde tanımlanabilir.
- Anahtar–metin eşleşmesi derleme zamanında denetlenmiyor. Bir kod eklenip
  `tr.toml`a satır eklenmezse, kullanıcı ham anahtarı görür. İleride bir
  CI denetimi eklenebilir: çekirdekteki her `DES_*` sabiti için her dil
  dosyasında bir bölüm var mı?
- `en.toml` şu an bir çeviri değil, bir iskelet; gerçek İngilizce metinler
  v0.6'da gözden geçirilecek.
