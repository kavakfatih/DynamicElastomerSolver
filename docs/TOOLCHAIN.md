# Araç Zinciri

Bu belge, DES/26'nın hangi derleyici ve araçlarla kurulduğunu, hangi
uyarıların gerçek hata sayıldığını ve platforma özgü kurulum ayrıntılarını
anlatır.

---

## Sıfır uyarı kuralı

Depo **sıfır uyarı** ile derlenir. Bu kural **iki** aracı birden kapsar:

1. **Derleyici** — `-std=f2018 -Wall -Wextra -fimplicit-none`
2. **fortls** — Fortran dil sunucusu (language server)

İkisinden birinin ürettiği yeni bir uyarı regresyondur.

### Neden fortls de sayılıyor

gfortran'ın yakalamadığı gerçek bir hata sınıfını fortls yakalıyor:
**host değişkeni maskeleme**.

Fortran'da `contains` altındaki iç prosedürler, host'un değişkenlerini
görür (host association). İç prosedür aynı isimde kendi değişkenini
tanımlarsa host'unkini maskeler. Bu yasaldır ama tehlikelidir: host
değişkenini değiştirdiğinizi sanırken yerel bir kopyayı değiştirirsiniz.

Çökme üretmez. Sayıyı biraz yanlış yapar. Bu projede en pahalı hata
sınıfı budur.

`-Wall -Wextra` bunu yakalamaz; fortls yakalar. **fortls haklıdır.**

Örnek: `check_material_tangent.f90` içindeki `diag3(a, b, c)` fonksiyonunun
`c` kukla argümanı, host kapsamındaki `C(3,3)` sağ Cauchy-Green tensörünü
maskeliyordu. Argümanlar `d11/d22/d33` olarak yeniden adlandırıldı.

### Yerelde çalıştırma

```sh
pip install fortls

for f in src/*.f90 test/*.f90 app/*.f90; do
  fortls --debug_rootpath . --debug_filepath "$f" --debug_diagnostics \
    | grep -E "^[[:space:]]*[0-9]+:(WARNING|ERROR)" && echo "  ^ $f"
done
```

> **Desendeki incelik.** fortls temiz bir dosya için `No errors or
> warnings` yazar. Büyük/küçük harfe duyarsız bir `warning` araması bu
> satırla eşleşir ve denetim her zaman kırmızıya döner. Gerçek tanı
> satırları `  151:WARNING  ...` biçimindedir; desen bu yüzden satır
> numarası önekini arar ve harfe duyarlıdır.

CI'da `fortls-denetimi` işi bunu her push'ta yapar.

---

## Derleyiciler

| Derleyici | Sürüm | Durum |
|---|---|---|
| gfortran | 13+ | Birincil. CI'da üç platformda da bu kullanılıyor. |
| Intel ifx | 2024+ | Destekleniyor, CI'da denenmiyor. Windows'ta hata ayıklama için. |

Geliştirmede kullanılan sürüm: gfortran 16.2 (Homebrew), macOS arm64.

### Bayraklar

Ortak: `-std=f2018 -Wall -Wextra -fimplicit-none`

Debug: `-O0 -g -fcheck=all -fbacktrace` ve destekleniyorsa
`-ffpe-trap=invalid,zero,overflow`

Release: `-O2`

`-ffpe-trap` her platformda desteklenmez. `CMakeLists.txt` bunu
`check_fortran_compiler_flag` ile sınar ve desteklenmiyorsa sessizce atlar.

---

## UTF-8

Fortran kaynaklarında Türkçe karakterler (ç ğ ı ö ş ü) **yorumlarda**
serbestçe kullanılır. gfortran bunun için **ek bayrak gerektirmez**.

`-finput-charset` seçeneği gfortran'da Fortran için **geçersizdir**:

```
f951: Warning: command-line option '-finput-charset=UTF-8' is valid for
      C/C++/ObjC/ObjC++ but not for Fortran
```

Bu yüzden bilinçli olarak eklenmemiştir.

### Yorumlarda `/` ve `*` yan yana yazılmaz

Ninja üreticisi, modül bağımlılık grafiğini çıkarmak için kaynakları C ön
işlemcisinden geçirir (`gfortran -cpp -E`). Ön işlemci bu diziyi C blok
yorumu başlangıcı sanar ve `Error: unterminated comment` verir.

Bu tuzak **Makefile üreticisinde sessizce çalışır**; yalnızca Ninja ile
ortaya çıkar. CI'daki `kaynak-denetimi` işi bunu denetler.

---

## Yapı sistemleri

İki yapı sistemi paralel tutulur; ikisi de CI'da sınanır.

### CMake (birincil)

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

### fpm (ikincil)

```sh
fpm build --build-dir build-fpm
fpm test  --build-dir build-fpm
```

`--build-dir` **zorunludur**: fpm de varsayılan olarak `build/` kullanır
ve CMake ile aynı dizini paylaşırlarsa iki çıktı ağacı iç içe girer.
Kalıcı çözüm için `export FPM_BUILD_DIR=build-fpm`.

### Üreticiler (generator)

| Platform | Üretici | Not |
|---|---|---|
| Linux, macOS | Ninja (CI), Unix Makefiles (yerel varsayılan) | ikisi de çalışır |
| Windows | **Ninja — zorunlu** | aşağıya bakınız |

**Windows'ta Ninja zorunludur.** CMake orada varsayılan olarak Visual
Studio üreticisini seçer ve **VS üreticisi Fortran'ı hiç desteklemez**:

```
-- Building for: Visual Studio 18 2026
-- The Fortran compiler identification is unknown
CMake Error: CMAKE_Fortran_COMPILER gfortran is not a full path...
```

CI üç platformda da Ninja kullanır; matris böylece tekdüzedir ve C ön
işlemci tuzağı (yukarıya bakınız) her platformda yakalanır.

---

## Windows'ta Visual Studio ile hata ayıklama

Intel Fortran ile Visual Studio hata ayıklayıcısını kullanmak isterseniz
proje dosyalarını **CMake üretir**:

```sh
cmake -B build-vs -G "Visual Studio 17 2022" -DCMAKE_Fortran_COMPILER=ifx
```

> **Çıktı COMMIT EDİLMEZ.** `build-vs/`, `*.sln`, `*.vcxproj`, `*.vfproj`
> ve `.vs/` `.gitignore` içindedir.

### Neden elle tutulan bir `.sln` yok, olmayacak

- **CMake istendiğinde üretir.** Elle bakım gerektirmez.
- **Elle tutulan bir `.sln`, `CMakeLists.txt`'den ayrışır.** İki dosya
  arasında hangisinin doğru olduğu sorusu ortaya çıkar; ikinci bir
  doğruluk kaynağı, bir doğruluk kaynağından kötüdür.
- **Windows'a özeldir.** macOS bir gönderim (shipping) hedefidir; yalnızca
  bir platformda çalışan bir yapı tanımı, diğerinde sessizce bayatlar.

### "No solution file in the workspace" uyarısı

Bu uyarı Fortran'la ilgisizdir; bir C#/.NET eklentisinden gelir. Bu depoda
`.sln` **yoktur ve olmayacaktır**. Uyarıyı susturmak için ilgili eklentiyi
bu çalışma alanı (workspace) için devre dışı bırakınız — eklenti
`.vscode/extensions.json` içinde `unwantedRecommendations` listesindedir,
ama VS Code bu listeyi yalnızca öneri olarak kullanır; zaten kurulu bir
eklentiyi kendiliğinden kapatmaz.

VS Code'da: Extensions panelinde eklentiyi bulun → dişli simgesi →
**Disable (Workspace)**.

---

## AGENTS.md ve CLAUDE.md

Kural seti `AGENTS.md` dosyasındadır. `CLAUDE.md`, ona bağlı bir
**symlink**tir (git'te mod `120000`).

> **Windows uyarısı.** Git for Windows, `core.symlinks=true` ayarlı
> DEĞİLSE symlink'i düz bir metin dosyası olarak açar; `CLAUDE.md`
> içeriği tek satırlık `AGENTS.md` metni olur. Bu bir bozulma değildir
> ama kafa karıştırıcıdır. Windows'ta çalışıyorsanız:
>
> ```sh
> git config --global core.symlinks true
> ```
>
> (Geliştirici Modu veya yönetici hakkı gerekir.) Ayar yoksa doğrudan
> `AGENTS.md` dosyasını okuyunuz — bağlayıcı olan odur.

---

## Sürekli tümleştirme

`.github/workflows/ci.yml` yedi iş çalıştırır:

| İş | Ne denetler |
|---|---|
| `build-test` | 3 platform × 2 yapı türü, Ninja ile derleme ve ctest |
| `fpm` | ikinci yapı sisteminin çalıştığı |
| `uyari-denetimi` | sıfır derleyici uyarısı (Makefile üreticisiyle) |
| `fortls-denetimi` | sıfır fortls uyarısı, host maskeleme dâhil |
| `kaynak-denetimi` | Fortran yorumlarında C blok yorumu dizisi yok |
| `lisans-denetimi` | `src/` altında copyleft metni yok, `LICENSE` bütün |
| `mesaj-denetimi` | her `DES_*` kodunun her dil dosyasında karşılığı var |

`uyari-denetimi` bilinçli olarak varsayılan (Makefile) üreticiyi kullanır;
matris Ninja kullanır. Böylece iki üretici de her push'ta sınanmış olur.
