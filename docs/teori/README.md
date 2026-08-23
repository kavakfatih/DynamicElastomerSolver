# Teori Notları

Bu dizin, DES/26'da uygulanan modellerin **tam türetmelerini** tutar.

## Neden bu dizin var

Bir hiperelastik malzemenin tanjantı yanlış yazıldığında, çözücü çökmez.
Newton daha yavaş yakınsar, bazen hiç yakınsamaz, ama gerilme sonuçları
makul görünmeye devam eder — çünkü gerilme doğru, yalnızca türevi
yanlıştır. Bu tür bir hatanın yakalanmasının tek yolu, formülün yazıldığı
yerin izlenebilir olmasıdır.

Bu yüzden her model için:

- Serbest enerjiden başlayan tam türetme
- Kullanılan her türev kimliği açıkça yazılmış
- Küçük şekil değiştirme sınırının kontrolü
- Bilinen tuzaklar ve sayısal sınırlar
- Doğrulama durumu tablosu — hangi test, hangi tolerans, hangi ölçülen değer
- Kaynak künyeleri

Türetme ile kod arasında bir uyuşmazlık varsa, **kod yanlıştır** — ya da
türetme güncellenmemiştir. Her iki durumda da düzeltilecek bir şey vardır.

## Doğrulama ile ilişkisi

Bu dizindeki her belge, `docs/dogrulama/DOGRULAMA-PLANI.md` içindeki bir
veya birkaç VER-xxx problemine bağlıdır. Teori belgesi "formül bu" der,
doğrulama planı "bu formülün doğru uygulandığı şöyle gösterilir" der.

## Notlar

| No | Başlık | Uygulama | Durum |
|---|---|---|---|
| [0001](0001-hiperelastik-neo-hookean.md) | Sıkıştırılabilir Neo-Hookean | `des_mat_neohookean.f90` | Doğrulandı (VER-001, VER-002) |

## Planlanan

| Konu | Sürüm |
|---|---|
| Ogden modeli, asal uzamalarda | v0.4 |
| Prony serisi viskoelastisite ve WLF kaydırması | v0.4 |
| Mullins etkisi (sözde-elastik hasar) | v0.4 |
| F-bar formülasyonu ve hacimsel kilitlenme | v0.1 |
| Karışık u-p formülasyonu ve LBB koşulu | v0.3 |
| Eksenel simetrik + burulma kinematiği | v0.2 |

## Gösterim kuralları

- $\mathbf{F}$ deformasyon gradyanı, $\mathbf{C} = \mathbf{F}^T\mathbf{F}$
  sağ Cauchy-Green tensörü, $J = \det\mathbf{F}$
- $\mathbf{S}$ ikinci Piola-Kirchhoff gerilmesi,
  $\boldsymbol{\sigma}$ Cauchy gerilmesi
- $\mathbb{C} = 2\,\partial\mathbf{S}/\partial\mathbf{C}$ malzeme tanjantı
- $(\mathbf{A}\otimes\mathbf{B})_{ijkl} = A_{ij}B_{kl}$ diyadik çarpım
- Üzeri çizgili nicelikler izokorik: $\bar{I}_1 = J^{-2/3} I_1$

LaTeX gösterimi GitHub tarafından işlenir; matematik `$...$` ve `$$...$$`
sınırlayıcılarıyla yazılır.
