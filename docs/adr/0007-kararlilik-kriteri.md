# ADR 0007 — Kararlılık ölçütü: mod bazlı monotonluk

**Durum:** KABUL EDİLDİ
**Yerini aldığı:** v0.0.1'deki tam tanjant pozitif tanımlılığı (Drucker) ölçütü

Uygulama: [`src/des_material.f90`](../../src/des_material.f90) —
`check_mode_stability`
Doğrulama: VER-031, [`test/check_stability.f90`](../../test/check_stability.f90)

---

## Bağlam

v0.0.1'de malzeme temel sınıfına genel bir kararlılık kontrolü konulmuştu:

> Drucker kararlılığı `dS:dE > 0` ister. `dE = dC/2` ve `dS = (1/2)·CC:dC`
> ile bu koşul, `CC`'nin simetrik ikinci mertebe tensörler uzayında pozitif
> tanımlı olmasına indirgenir. Tanjantı ortonormal Mandel/Kelvin bazında
> 6x6 matrise indirge, Cholesky dene.

Bu, tarif edildiği gibi uygulandı ve matematiksel olarak doğru çalıştı.
Sorun uygulamada değil, **ölçütün kendisindeydi**.

## Karar

Tam tanjant pozitif tanımlılığı ölçütü **kaldırıldı**. Yerine **mod bazlı
monotonluk kontrolü** kondu.

Üç deformasyon modunda, nominal (1. Piola-Kirchhoff) gerilmenin uzama
oranına göre türevi pozitif olmalıdır:

$$\frac{dP}{d\lambda} > 0$$

| Mod | Kinematik | Yanal uzama koşulu |
|---|---|---|
| Tek eksenli | $F = \mathrm{diag}(\lambda, x, x)$ | $\sigma_{22} = 0$ |
| Eşit iki eksenli | $F = \mathrm{diag}(\lambda, \lambda, x)$ | $\sigma_{33} = 0$ |
| Düzlemsel (saf kayma) | $F = \mathrm{diag}(\lambda, 1, x)$ | $\sigma_{33} = 0$ |

Yanal uzamalar ikiye bölme (bisection) ile çözülür. Tarama aralığı
varsayılan olarak $\lambda = 0.5 \ldots 4.0$'dır ve çağıran tarafından
verilebilir. Sonuç, ilk kararsızlığın hangi **modda** ve hangi
**uzamada** başladığını döndürür.

Hacimsel kararlılık ayrıca ve trivial olarak raporlanır: $\kappa_{ref} > 0$.

Bu, ANSYS ve Abaqus'ün hiperelastik kalibrasyonda kullandığı ölçüttür.

---

## Neden tam tanjant pozitif tanımlılığı YANLIŞ ölçüt

### Karşı örnek

**SAĞLIKLI** bir Neo-Hookean, $C_{10} = +0.6 > 0$, $K = 10^3$:

$$F = \mathrm{diag}(1.40,\; 0.85,\; 0.85), \qquad
d\mathbf{C} : \mathbb{C} : d\mathbf{C} = -3.9389 \times 10^{1}$$

Burada $d\mathbf{C}$, Mandel bazının $(2,3)$ kayma yönü
$E_5 = (\mathbf{e}_2\otimes\mathbf{e}_3 + \mathbf{e}_3\otimes\mathbf{e}_2)/\sqrt{2}$'dir.

Bu değer **üç bağımsız yoldan** doğrulanmıştır:

1. Analitik tensör kontraksiyonu
2. Enerjinin sonlu farkla ikinci türevi, $4\,d^2\Psi/dt^2$
3. 6x6 Mandel matrisinin özdeğer ayrıştırması

Bu depoda ölçülen değer: **-3.9388773e+01** — dördüncü bağımsız doğrulama
([`test/check_contract.f90`](../../test/check_contract.f90), 5. bölüm).
Aynı noktadaki Mandel köşegeni:

```
  M(1,1) =  2.6342988E+02      M(4,4) = -1.4519586E+01
  M(2,2) =  1.9424235E+03      M(5,5) = -3.9388773E+01
  M(3,3) =  1.9424235E+03      M(6,6) = -1.4519586E+01
```

Üç kayma köşegeni birden negatiftir.

### Neden bu bir hata değil, fizik

Neo-Hookean serbest enerjisi $\mathbf{C}$ uzayında **konveks değildir**;
**polikonveks**tir. Konvekslik, sonlu şekil değiştirmede zaten fiziksel
olarak istenmeyen bir şarttır — malzeme çerçeve bağımsızlığıyla (objectivity)
çelişir. $\mathbf{S}$, $\mathbf{E}$'nin monoton bir fonksiyonu olmak zorunda
değildir.

Deviatorik altuzaya geçmek de düzeltmez: negatif özdeğer orada da vardır.
Ayrıca izdüşürülmüş $\mathbb{P}:\mathbb{C}:\mathbb{P}$ tensörü hidrostatik
yönde tanımı gereği tekildir; Cholesky her zaman patlar.

### İki ayrı mekanizma, ikisi de ölçüldü

Bu depoda yapılan tarama, ihlalin **iki bağımsız kaynağı** olduğunu
gösteriyor:

**1. Hacimsel penaltı terimi.** $\mathbb{C}_{vol}$ içindeki
$-2KJ(J-1)\,\mathbb{I}_C$ terimi $J > 1$ için negatiftir ve $K$ ile
ölçeklenir. Kayma bileşenlerinde $\mathbf{C}^{-1}\otimes\mathbf{C}^{-1}$ hiç
katkı vermez, dolayısıyla orada yalnızca negatif terim kalır. Yukarıdaki
karşı örnekte baskın mekanizma budur — aynı $F$'de $K$ taraması:

| K | 0.1 | 1 | 10 | 100 | 1e3 | 1e4 | 1e5 |
|---|---|---|---|---|---|---|---|
| M(5,5) | +5.17 | +5.13 | +4.73 | +0.72 | **−39.4** | **−440** | **−4452** |

**2. İzokorik kısmın kendi konveks olmayışı.** Penaltı tamamen kaldırılsa
bile ($K = 10^{-8}$, saf izokorik $F = \mathrm{diag}(\lambda,
\lambda^{-1/2}, \lambda^{-1/2})$, $J = 1$), $\mathbb{C}_{1111}$ bileşeni
$\lambda \approx 1.58$'den sonra negatife geçer:

| λ | 1.50 | 1.55 | **1.60** | 1.70 | 2.00 | 2.50 |
|---|---|---|---|---|---|---|
| min köşegen | +4.39e-02 | +1.65e-02 | **−4.88e-03** | −3.43e-02 | −6.67e-02 | −6.35e-02 |

Yani sorun yalnızca penaltı formülasyonunun bir yan etkisi değildir; ölçüt
karışık u-p formülasyonuna (v0.3) geçildiğinde de yanlış kalırdı.

### Normalizasyon sorunu

v0.0.1'de marj, $\max|M_{aa}|$ ile normalize ediliyordu. Bu ölçekleme
neredeyse sıkıştırılamaz malzemelerde anlamını yitiriyordu: köşegenin en
büyük elemanı $K$ mertebesindeyken deviatorik özdeğerler $\mu$
mertebesindedir, dolayısıyla normalize marj $\mu/K$ ile sıfıra gidiyordu.
$C = I$'de ölçülen değerler:

| K/C10 | 1.7e1 | 1.7e3 | 1.7e5 |
|---|---|---|---|
| normalize marj | 2.03e-01 | 2.35e-03 | 2.35e-05 |

Yani gerçek kauçuk için ($K/\mu \approx 10^4 \ldots 10^6$) ölçüt zaten
bıçak sırtındaydı. Yeni ölçütte bu sorun ortadan kalkıyor: eğimler
$\mu_{ref}$ ile boyutsuzlaştırılıyor ve normalize edilmiş en küçük eğim
büyük uzamada $\to 1$'e gidiyor (sıkıştırılamaz Neo-Hookean için
$dP/d\lambda \to 2C_{10} = \mu_{ref}$). Ölçülen: **1.000965**.

---

## Doğrulanmış referans değerler

$C_{10} = 0.6$, $K = 10^5$, tek eksenli. "Ölçülen" sütunu bu depodadır.

| λ | P (ref) | P (ölçülen) | dP/dλ (ref) | dP/dλ (ölçülen) |
|---|---|---|---|---|
| 0.50 | −4.19999 | −4.199986 | 20.39992 | 20.399923 |
| 0.70 | −1.60897 | −1.608974 | 8.19706 | 8.197060 |
| 1.00 | 0.00000 | 0.000000 | **3.59999** | **3.599986** |
| 1.50 | +1.26666 | 1.266658 | 1.91109 | 1.911089 |
| 2.00 | +2.09998 | 2.099976 | 1.49996 | 1.499961 |
| 3.00 | +3.46658 | 3.466582 | 1.28880 | 1.288802 |
| 4.00 | +4.72480 | 4.724797 | 1.23735 | 1.237346 |

En büyük sapma 4.3e-06; referans beş ondalık haneye yuvarlanmış olduğu
için tek başına ±5e-6 belirsizlik taşır.

$C_{10} = -0.6$ (fiziksel olmayan malzeme) aynı noktalarda:

| λ | dP/dλ (ref) | dP/dλ (ölçülen) |
|---|---|---|
| 1.00 | −3.60001 | −3.600014 |
| 1.50 | −1.91113 | −1.911134 |
| 2.00 | −1.50004 | −1.500039 |

Test her iki malzemeyi de doğru sınıflandırır.

### Çapraz doğrulama: dP/dλ(1) = E

$\lambda = 1$'deki eğim doğrudan elastisite modülüdür. Bu, kararlılık
kontrolünü VER-001 ile birbirine bağlar:

```
dP/dlambda (lambda = 1)   = 3.599986
E = 9*K*mu/(3*K+mu)       = 3.599986      bagil fark 3.16e-08
```

İkisinden biri bozulursa ikisi birden kırmızıya döner. Bu, bedava gelen
bir tutarlılık kilididir.

---

## Arayüz değişikliği

`eval` imzasına **dokunulmadı**. Değişen yalnızca kararlılık kontrolü:

```fortran
! ÖNCE (v0.0.1)
subroutine check_stability(this, C, pt, state_n, state_np1, stat, margin)

! SONRA
subroutine check_stability(this, pt, state_n, state_np1, rng, res)
   type(stability_range_t),  intent(in)  :: rng   ! aralık + mod listesi
   type(stability_result_t), intent(out) :: res   ! (mod, lambda) + eğimler
```

Tek bir $\mathbf{C}$ almak yerine bir uzama aralığı ve mod listesi alır;
ilk kararsızlığın (mod, λ) çiftini döndürür. Bu, kalibrasyon modülünün
(v0.4) doğrudan kullanacağı arayüzdür — kullanıcıya "Ogden katsayılarınız
düzlemsel modda λ = 2.7'den sonra kararsız" cümlesi kurulabilmelidir.

`material_t`'ye iki referans modül eklendi:

- `mu_ref` — referans kayma modülü (Neo-Hookean için $2C_{10}$).
  Normalizasyon ve raporlama.
- `kappa_ref` — referans hacim modülü. Spesifikasyon yalnızca `mu_ref`
  istiyordu; hacimsel kararlılığı ($\kappa > 0$) temel sınıftan
  raporlayabilmek için ikincisi de gerekti.

---

## Sonuçlar

**Olumlu**

- Sağlıklı kauçuk artık "kararsız" diye reddedilmiyor
- Kullanıcının anladığı ve deney verisiyle doğrudan karşılaştırabildiği ölçüt
- İlk kararsızlığın modu ve uzaması raporlanıyor — kalibrasyon için gereken bilgi
- VER-001 ile çapraz doğrulama bedava geliyor
- Hâlâ yalnızca `eval`e dayanıyor: bütün malzemeler bedava alıyor

**Olumsuz**

- Tek bir $\mathbf{C}$ için "bu noktada kararlı mı" sorusu artık
  sorulamıyor. Ölçüt bir tarama, nokta kontrolü değil. Newton döngüsü
  içinde çağrılacak bir şey değildir; kalibrasyon ve model doğrulama
  zamanındadır.
- Maliyeti yüksek: mod × örnek × 2 (merkezi fark) × bisection. Varsayılan
  ayarlarda ~26 bin `eval` çağrısı. Kalibrasyonda kabul edilebilir,
  çözüm döngüsünde değil.
- Ölçüt yalnızca üç kanonik modu tarar. Bu modların dışında kalan bir
  kararsızlığı yakalamaz.

## Gelecek seçenek: kuvvetli eliptiklik

Matematiksel olarak daha titiz alternatif **kuvvetli eliptiklik
(Legendre-Hadamard)** koşuludur; iyi-konumlanmışlığı (well-posedness)
garanti eden gerçek şart odur ve Neo-Hookean $C_{10} > 0$ için her yerde
sağlanır:

$$Q_{ik}(\mathbf{n}) = A_{AiBk}\, n_A n_B \succ 0 \quad \forall\, \mathbf{n},
\qquad A_{AiBk} = F_{iJ}F_{kL}\,\mathbb{C}_{AJBL} + S_{AB}\delta_{ik}$$

**Şimdi uygulanmıyor.** Kalibrasyon için mod bazlı kontrol hem yeterli hem
de kullanıcının anladığı şey. Eliptiklik, gerçek malzeme kararsızlığının
(lokalizasyon, kayma bandı) fiilen mümkün hâle geldiği v0.4'te — Ogden ve
Mullins ile birlikte — yeniden değerlendirilecektir.

## Değerlendirilen alternatifler

**Deviatorik altuzayda pozitif tanımlılık.** Reddedildi: negatif özdeğer
orada da var, ve izdüşürülmüş tensör hidrostatik yönde tekil olduğu için
Cholesky her zaman patlar.

**Ölçütü tutup yalnızca yeniden adlandırmak** (`check_tangent_pd`).
Reddedildi: dürüst olurdu ama kullanıcı anlamlı bir kararlılık
kontrolünden yoksun kalırdı.

**Doğrudan kuvvetli eliptikliğe geçmek.** Ertelendi: yukarıya bakınız.

## Kaynaklar

- Truesdell & Noll, *The Non-Linear Field Theories of Mechanics*, §52 —
  Drucker koşulunun aşırı kısıtlayıcılığı
- Marsden & Hughes, *Mathematical Foundations of Elasticity*, böl. 6 —
  kuvvetli eliptiklik ve polikonvekslik
- Ball, J. M. (1976), "Convexity conditions and existence theorems in
  nonlinear elasticity", *Arch. Ration. Mech. Anal.* **63**, 337–403 —
  polikonvekslik
- Ogden, *Non-Linear Elastic Deformations*, §6.2 — akustik tensör
- Bonet & Wood (2008), böl. 6 — hacimsel/izokorik ayrışmalı tanjant
