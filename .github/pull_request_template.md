<!--
AGENTS.md §8 "Bitmiş sayılma" listesi. Kutuları işaretlemeden önce
gerçekten çalıştırın; bu liste bir tören değil, bir kapıdır.
-->

## Ne değişti ve neden

<!-- Bir paragraf. Neyi çözüyor. -->

## Sayılar

<!--
ctest çıktısı. DEĞİŞEN ve DEĞİŞMEYEN sayıları ayrı ayrı yazın.
Sayısal bir değişiklik yaptıysanız ve sayı değişmediyse, bunu AÇIKÇA
söyleyin — "değişmedi" bir bulgudur.
-->

```
```

**VER-001 / VER-002 / VER-031 değişti mi?**
<!-- Değiştiyse SEBEBİNİ yazın. Bu üçü referans değerlerdir. -->

## Bitmiş sayılma

- [ ] Debug derleniyor, **sıfır derleyici uyarısı**
- [ ] Release derleniyor, **sıfır derleyici uyarısı**
- [ ] **Sıfır fortls uyarısı** (host maskeleme dâhil)
- [ ] `ctest` geçiyor, çıktı yukarıda
- [ ] Yeni malzeme varsa: kararlılık **ve** tanjant testini geçiyor
- [ ] Yeni eleman varsa: yama testini (patch test) geçiyor
- [ ] `CHANGELOG.md` güncel
- [ ] Yeni bağımlılık varsa `THIRD_PARTY.md` güncel ve lisansı izin listesinde
- [ ] Yeni model varsa `docs/teori/` altında türetme notu var

## Sözleşme ve ADR

- [ ] Dondurulmuş sözleşmelere **dokunulmadı**

<!-- Dokunulduysa ilgili ADR bağlantısı — ADR ÖNCE yazılır, kod sonra: -->

## Sahiplik

- [ ] Yalnızca sahibi olduğum dizinlerde değişiklik yaptım (AGENTS.md §2)

<!-- Başka dizine dokunulduysa hangisi ve neden: -->

## Kontrol edilmedi / bilinen sınırlar

<!--
Dürüst olun. Atlanan bir adım varsa burada söyleyin; CI'da ortaya
çıkmasından iyidir.
-->
