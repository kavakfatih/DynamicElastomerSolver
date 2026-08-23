# Teori 0001 — Sıkıştırılabilir Neo-Hookean hiperelastik malzeme

**Uygulama:** [`src/des_mat_neohookean.f90`](../../src/des_mat_neohookean.f90)
**Doğrulama:** VER-001 (tek eksenli), VER-002 (tanjant) — **ikisi de GEÇTİ**

---

## 1. Kinematik ve gösterim

Deformasyon gradyanı $\mathbf{F}$, sağ Cauchy-Green tensörü ve hacim
oranı:

$$
\mathbf{C} = \mathbf{F}^{T}\mathbf{F}, \qquad
J = \det \mathbf{F} = \sqrt{\det \mathbf{C}}, \qquad
I_1 = \operatorname{tr}\mathbf{C}
$$

Green-Lagrange şekil değiştirmesi $\mathbf{E} = \tfrac{1}{2}(\mathbf{C} -
\mathbf{I})$, dolayısıyla $d\mathbf{E} = \tfrac{1}{2}\, d\mathbf{C}$.

İzokorik (hacim değiştirmeyen) birinci invaryant:

$$
\bar{I}_1 = J^{-2/3} I_1
$$

Diyadik çarpım $(\mathbf{A}\otimes\mathbf{B})_{ijkl} = A_{ij}B_{kl}$.

---

## 2. Serbest enerji

Hacimsel/izokorik ayrışmalı, penaltı formunda:

$$
\boxed{\;\Psi(\mathbf{C}) = C_{10}\,(\bar{I}_1 - 3) \;+\; \frac{K}{2}\,(J-1)^2\;}
$$

$C_{10}$ izokorik katkı parametresi, $K$ hacim modülüdür (penaltı
parametresi olarak da okunabilir).

Küçük şekil değiştirme sınırında bu model, kayma modülü $\mu = 2C_{10}$ ve
hacim modülü $K$ olan izotropik doğrusal elastisiteye indirgenir (§6'da
gösterilecek).

---

## 3. Türev kimlikleri

Türetmede kullanılan dört kimlik:

$$
\frac{\partial I_1}{\partial \mathbf{C}} = \mathbf{I}
\qquad\qquad
\frac{\partial J}{\partial \mathbf{C}} = \tfrac{1}{2} J\, \mathbf{C}^{-1}
$$

$$
\frac{\partial J^{-2/3}}{\partial \mathbf{C}}
= -\tfrac{2}{3} J^{-5/3}\, \frac{\partial J}{\partial \mathbf{C}}
= -\tfrac{1}{3} J^{-2/3}\, \mathbf{C}^{-1}
$$

$$
\frac{\partial C^{-1}_{ij}}{\partial C_{kl}} = -\,\mathbb{I}_{C,ijkl},
\qquad
\mathbb{I}_{C,ijkl} \equiv \tfrac{1}{2}\left(
C^{-1}_{ik} C^{-1}_{jl} + C^{-1}_{il} C^{-1}_{jk}\right)
$$

$\mathbb{I}_C$ tensörü, $\mathbf{C}^{-1}$ ile kurulmuş simetrikleştirilmiş
dördüncü mertebe birim tensördür. Minör simetriktir
($\mathbb{I}_{C,ijkl} = \mathbb{I}_{C,jikl} = \mathbb{I}_{C,ijlk}$) ve
major simetriktir ($\mathbb{I}_{C,ijkl} = \mathbb{I}_{C,klij}$).

---

## 4. İkinci Piola-Kirchhoff gerilmesi

Tanım: $\mathbf{S} = 2\,\partial\Psi/\partial\mathbf{C}$.

### İzokorik kısım

$$
\frac{\partial \Psi_{\text{iso}}}{\partial \mathbf{C}}
= C_{10}\left[
J^{-2/3}\frac{\partial I_1}{\partial \mathbf{C}}
+ I_1 \frac{\partial J^{-2/3}}{\partial \mathbf{C}}
\right]
= C_{10}\, J^{-2/3}\left[\mathbf{I} - \tfrac{1}{3} I_1 \mathbf{C}^{-1}\right]
$$

$$
\boxed{\;\mathbf{S}_{\text{iso}} = 2 C_{10}\, J^{-2/3}
\left[\, \mathbf{I} - \tfrac{1}{3} I_1\, \mathbf{C}^{-1} \right]\;}
$$

### Hacimsel kısım

$$
\frac{\partial \Psi_{\text{vol}}}{\partial \mathbf{C}}
= K(J-1)\,\frac{\partial J}{\partial \mathbf{C}}
= \tfrac{1}{2} K J (J-1)\, \mathbf{C}^{-1}
$$

$$
\boxed{\;\mathbf{S}_{\text{vol}} = K\,J\,(J-1)\, \mathbf{C}^{-1}\;}
$$

Toplam: $\mathbf{S} = \mathbf{S}_{\text{iso}} + \mathbf{S}_{\text{vol}}$.

Deforme olmamış durumda ($\mathbf{C} = \mathbf{I}$, $J = 1$, $I_1 = 3$)
her iki terim de sıfırdır; model gerilmesiz referans durumu doğru
karşılar.

---

## 5. Tutarlı tanjant (consistent tangent)

Tanım: $\mathbb{C} = 2\,\partial\mathbf{S}/\partial\mathbf{C}$, öyle ki
$d\mathbf{S} = \tfrac{1}{2}\,\mathbb{C} : d\mathbf{C} = \mathbb{C} : d\mathbf{E}$.

### İzokorik kısım

$\mathbf{S}_{\text{iso}} = 2C_{10}\left[J^{-2/3}\mathbf{I}
- \tfrac{1}{3}J^{-2/3} I_1 \mathbf{C}^{-1}\right]$ ifadesinin her terimini
$C_{kl}$'ye göre türetip §3 kimliklerini yerine koyunca:

$$
\boxed{
\begin{aligned}
\mathbb{C}_{\text{iso}} = 4 C_{10} J^{-2/3} \Big[
&-\tfrac{1}{3}\big(\mathbf{I}\otimes\mathbf{C}^{-1}
+ \mathbf{C}^{-1}\otimes\mathbf{I}\big) \\
&+\tfrac{1}{9} I_1 \big(\mathbf{C}^{-1}\otimes\mathbf{C}^{-1}\big)
+\tfrac{1}{3} I_1\, \mathbb{I}_{C} \Big]
\end{aligned}}
$$

### Hacimsel kısım

$\mathbf{S}_{\text{vol}} = K(J^2 - J)\mathbf{C}^{-1}$ ifadesinden:

$$
\frac{\partial \mathbf{S}_{\text{vol}}}{\partial C_{kl}}
= K\left[(2J-1)\,\tfrac{1}{2}J\, C^{-1}_{kl}\, \mathbf{C}^{-1}
- (J^2 - J)\, \mathbb{I}_{C}\right]
$$

$$
\boxed{\;\mathbb{C}_{\text{vol}} = K\left[\,
J(2J-1)\,\big(\mathbf{C}^{-1}\otimes\mathbf{C}^{-1}\big)
\;-\; 2J(J-1)\,\mathbb{I}_{C} \right]\;}
$$

Toplam: $\mathbb{C} = \mathbb{C}_{\text{iso}} + \mathbb{C}_{\text{vol}}$.

### Simetriler

$\mathbb{C}$, hem minör hem major simetriktir. Major simetri
($\mathbb{C}_{ijkl} = \mathbb{C}_{klij}$), yukarıdaki ifadelerin her
teriminin $(ij) \leftrightarrow (kl)$ takasına göre bakışımlı olmasından
doğrudan görülür:
$(\mathbf{I}\otimes\mathbf{C}^{-1})_{klij} = (\mathbf{C}^{-1}\otimes\mathbf{I})_{ijkl}$,
ve $\mathbf{C}^{-1}\otimes\mathbf{C}^{-1}$ ile $\mathbb{I}_C$ kendiliğinden
bakışımlıdır.

Bu, hiperelastisitenin bir sonucudur: gerilme bir potansiyelin türevi
olduğu için tanjant simetriktir ve sertlik matrisi simetrik kalır.
VER-002'de major simetri sayısal olarak da denetlenir ve 12 vakanın
8'inde **tam sıfır** çıkar.

---

## 6. Küçük şekil değiştirme sınırı

$\mathbf{C} = \mathbf{I}$'de ($J = 1$, $I_1 = 3$, $\mathbf{C}^{-1} =
\mathbf{I}$, $\mathbb{I}_C = \mathbb{I}^{\text{sym}}$):

$$
\mathbb{C}_{\text{iso}} = 4C_{10}\left[\mathbb{I}^{\text{sym}}
- \tfrac{1}{3}\mathbf{I}\otimes\mathbf{I}\right],
\qquad
\mathbb{C}_{\text{vol}} = K\,\mathbf{I}\otimes\mathbf{I}
$$

Toplam:

$$
\mathbb{C}\big|_{\mathbf{C}=\mathbf{I}} =
2\mu\left[\mathbb{I}^{\text{sym}} - \tfrac{1}{3}\mathbf{I}\otimes\mathbf{I}\right]
+ K\, \mathbf{I}\otimes\mathbf{I},
\qquad \mu = 2C_{10}
$$

Bu, izotropik doğrusal elastisitenin standart biçimidir. Buradan:

$$
\mu = 2C_{10}, \qquad
\kappa = K, \qquad
E = \frac{9K\mu}{3K + \mu}, \qquad
\nu = \frac{3K - 2\mu}{2(3K + \mu)}
$$

Sıkıştırılamaz sınırda ($K \to \infty$): $E \to 3\mu = 6C_{10}$ ve
$\nu \to 1/2$.

**Sayısal karşılığı:** $C_{10} = 0.6$, $K = 10^5$ için
$E = 3.599986$ ve $6C_{10} = 3.600000$. VER-001 her ikisine karşı da
kontrol eder.

---

## 7. Tek eksenli gerilme tam çözümü ve bir tuzak

Sıkıştırılamaz Neo-Hookean için tek eksenli gerilme:

$$
\sigma_{11} = 2C_{10}\left(\lambda^2 - \frac{1}{\lambda}\right)
$$

### Tuzak

$\lambda_2 = \lambda_3 = \lambda^{-1/2}$ **dayatmak tek eksenli gerilme
durumu vermez.** Bu, sıkıştırılamaz malzemenin kinematik cevabıdır; bizim
malzememiz sıkıştırılabilirdir.

Sıkıştırılabilir malzemede yanal uzama bir **bilinmeyendir** ve
$\sigma_{22} = 0$ koşulundan çözülmelidir.

Yanlış yapılırsa elastisite modülü $6C_{10}$ yerine $4C_{10}$ çıkar:
3.6 yerine **2.4**. Bu sayı, kimsenin gözüne batmayacak kadar makul
görünür — doğru mertebede, doğru işaretli, sadece yanlış. VER-001'in asıl
varlık sebebi budur ve test çıktısı bilinçli olarak $4C_{10}$ değerini de
bastırır.

Uygulamada yanal uzama, $\sigma_{22}(\lambda_t)$ monoton arttığı için
ikiye bölme (bisection) ile çözülür. Newton kullanılmaz: bir doğrulama
testi, doğruladığı şeyden daha kırılgan olmamalıdır.

**Ölçülen değerler** ($C_{10} = 0.6$, $K = 10^5$):

| $\lambda$ | $\lambda_{\text{yanal}}$ | $\sigma_{11}$ | tam çözüm | bağıl hata |
|---|---|---|---|---|
| 1.05 | 0.9759004 | 1.801420e-01 | 1.801429e-01 | 4.810e-06 |
| 1.25 | 0.8944286 | 9.149924e-01 | 9.150000e-01 | 8.283e-06 |
| 1.50 | 0.8164992 | 1.899975e+00 | 1.900000e+00 | 1.322e-05 |
| 2.00 | 0.7071117 | 4.199894e+00 | 4.200000e+00 | 2.533e-05 |
| 3.00 | 0.5773603 | 1.039939e+01 | 1.040000e+01 | 5.910e-05 |

Sapmalar **sayısal hata değil, fiziksel sapmadır**: tam çözüm
sıkıştırılamaz malzeme içindir, model sonlu $K$ taşır. Sapma
$\mu/K = 1.2\times 10^{-5}$ mertebesindedir ve uzamayla büyür.

$\lambda = 3$'te ölçülen yanal uzama 0.5773603'tür;
$3^{-1/2} = 0.5773503$. Aradaki 1e-5'lik fark, sıkıştırılabilirliğin
kendisidir — tuzağa düşülmediğinin doğrudan kanıtı.

---

## 8. Penaltı formunun kilitlenme sınırı

Bu model neredeyse sıkıştırılamazlığı bir **penaltı** ile karşılar:
$K$ büyüdükçe $J \to 1$ zorlanır. Bunun iki maliyeti vardır.

### Hacimsel kilitlenme (volumetric locking)

Yer değiştirme tabanlı elemanlarda, $K/\mu$ büyüdükçe eleman hacim
değişimine karşı aşırı katı hâle gelir ve çözüm gerçek cevaba yakınsamaz.
Tam integrasyonlu Q4 elemanında bu, $K/\mu \gtrsim 10^3$'te belirgin olur.
Kauçukta $K/\mu \approx 10^4 \ldots 10^6$'dır — yani kilitlenme kaçınılmazdır
ve bir çare zorunludur.

Çareler yol haritasında: F-bar (v0.1), B-bar ve seçmeli indirgenmiş
integrasyon, karışık formülasyon (mixed u-P) (v0.3). Malzeme arayüzü bu
seçimden habersizdir; formülasyon stratejisi elemanın seçeneğidir.

### Koşullandırma

$K/\mu$ büyüdükçe sertlik matrisinin koşul sayısı $K/\mu$ ile ölçeklenir.
$K/\mu = 10^6$'da çift hassasiyetin yaklaşık altı basamağı bu orana gider.
Bu, karışık u-p formülasyonunun tercih edilmesinin ikinci sebebidir:
basıncı bağımsız bir alan yapmak, penaltıyı ortadan kaldırır.

### Kararlılık kontrolüne etkisi

Penaltı terimi, Drucker kararlılık kontrolünü de bozar: $J > 1$ olduğunda
$\mathbb{C}_{\text{vol}}$ içindeki $-2KJ(J-1)\mathbb{I}_C$ terimi kayma
bileşenlerini negatif yapar ve tanjant pozitif tanımlılığını yitirir.
Bu, ölçülmüş ve belgelenmiştir:
[ADR 0007](../adr/0007-kararlilik-kriteri.md).

---

## 9. Doğrulama durumu

| Kimlik | Ne doğrulanıyor | Yöntem | Tolerans | Ölçülen | Durum |
|---|---|---|---|---|---|
| VER-001 | $\sigma_{11}(\lambda)$ | Analitik tam çözüm | $\lambda$'ya göre 1e-5 … 1.2e-4 | 4.81e-06 … 5.91e-05 | **GEÇTİ** |
| VER-001 | $E$ vs $6C_{10}$ | Analitik | 1e-4 | 3.98e-06 | **GEÇTİ** |
| VER-001 | $E$ vs $9K\mu/(3K{+}\mu)$ | Analitik | 1e-6 | 2.16e-08 | **GEÇTİ** |
| VER-001 | $\sigma_{22} = 0$ artığı | — | 1e-14 | 8.52e-17 | **GEÇTİ** |
| VER-002 | $\mathbb{C}$ vs merkezi fark | Sonlu fark, $h = 10^{-6}$ | 1e-8 | 1.87e-11 … 1.04e-10 | **GEÇTİ** |
| VER-002 | Major simetri | — | 1e-12 | 0.0 … 1.48e-16 | **GEÇTİ** |

VER-002, altı belirlenimci deformasyon gradyanında (çekme, basma, saf
kayma, $\lambda = 3$, birleşik kayma+uzama, hacimsel) ve iki
sıkıştırılabilirlik oranında ($K/C_{10} = 1.7\times10^3$ ve
$1.7\times10^5$) çalışır.

### Sayısal tanjantın kurulumu

$\mathbb{C} = 2\,\partial\mathbf{S}/\partial\mathbf{C}$ tanımı, simetrik
bir $\mathbf{M}$ yönü için:

$$
\mathbf{S}(\mathbf{C} + h\mathbf{M}) - \mathbf{S}(\mathbf{C} - h\mathbf{M})
= h\, \mathbb{C}:\mathbf{M} + O(h^3)
$$

Köşegen yön $\mathbf{M} = \mathbf{e}_k\otimes\mathbf{e}_k$ için
$\mathbb{C}:\mathbf{M} = \mathbb{C}_{ijkk}$; kayma yönü
$\mathbf{M} = \mathbf{e}_k\otimes\mathbf{e}_l + \mathbf{e}_l\otimes\mathbf{e}_k$
($k \neq l$) için minör simetri nedeniyle
$\mathbb{C}:\mathbf{M} = 2\,\mathbb{C}_{ijkl}$.

Pertürbasyonun **simetrik** olması şarttır: tek bir bileşeni oynatmak,
$\mathbf{S}$'nin tanım kümesi dışına çıkmak demektir.

$h = 10^{-6}$ seçimi, $O(h^2)$ kesme hatası ile $O(\epsilon/h)$ yuvarlama
hatasının dengelendiği bölgedir; çift hassasiyette elde edilebilecek en
iyi bağıl hata yaklaşık $10^{-10}$'dur ve ölçülen değer budur.

---

## 10. Kaynaklar

- **Bonet, J. & Wood, R. D.** (2008), *Nonlinear Continuum Mechanics for
  Finite Element Analysis*, 2. baskı, Cambridge University Press, bölüm 6.
  Hacimsel/izokorik ayrışma ve tutarlı tanjantın standart sunumu.
- **Holzapfel, G. A.** (2000), *Nonlinear Solid Mechanics: A Continuum
  Approach for Engineering*, Wiley, §6.4. İzokorik ayrışmanın
  termodinamik gerekçesi.
- **Simo, J. C. & Taylor, R. L.** (1991), "Quasi-incompressible finite
  elasticity in principal stretches. Continuum basis and numerical
  algorithms", *Computer Methods in Applied Mechanics and Engineering*,
  **85**(3), 273–310. Penaltı ve karışık formülasyonların tanjant
  tutarlılığı.
- **Ogden, R. W.** (1997), *Non-Linear Elastic Deformations*, Dover, §6.2.
  Akustik tensör ve yerel kararlılık — ADR 0007 tartışması için.
