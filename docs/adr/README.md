# Mimari Karar Kayıtları (ADR)

Bu dizin, DES/26'nın geri dönüşü pahalı kararlarını ve **gerekçelerini**
tutar.

Bir ADR'nin asıl değeri kararın kendisinde değil, reddedilen
alternatiflerdedir. Altı ay sonra "neden böyle yapmışız, şunu yapsak daha
iyi olmaz mıydı?" diye soran kişi büyük ihtimalle kararı veren kişidir ve
o soruya cevap verebilmesi gerekir.

---

## Biçim

Her ADR şu bölümleri içerir:

- **Durum** — ÖNERİLDİ · KABUL EDİLDİ · REDDEDİLDİ · YERİNİ ALDI (0000)
- **Bağlam** — hangi soruyu cevaplıyoruz, hangi kısıtlar altında
- **Karar** — ne yapıyoruz
- **Gerekçe** — neden
- **Sonuçlar** — bu kararın bize maliyeti ne, neyi kolaylaştırdı
- **Değerlendirilen alternatifler** — ve neden reddedildikleri

Dosya adı: `NNNN-kisa-baslik.md`, sıfır dolgulu dört haneli numara.

---

## Kayıtlar

| No | Başlık | Durum |
|---|---|---|
| [0001](0001-fortran-hesaplama-cekirdegi.md) | Hesaplama çekirdeği Fortran 2018 | KABUL EDİLDİ |
| [0002](0002-c-abi-siniri.md) | C ABI sınırı, katman 3 ile 4 arasında | KABUL EDİLDİ |
| [0003](0003-lisanslama.md) | Business Source License 1.1 | KABUL EDİLDİ |
| [0004](0004-copyleft-bagimlilik-yok.md) | Copyleft bağımlılık yok — kaynak okumak dahil | KABUL EDİLDİ |
| [0005](0005-temas-ertelendi.md) | Temas v1.x'e ertelendi | KABUL EDİLDİ |
| [0006](0006-malzeme-sozlesmesi.md) | Malzeme sözleşmesi donduruldu | KABUL EDİLDİ |
| [0007](0007-kararlilik-kriteri.md) | Kararlılık ölçütü: mod bazlı monotonluk | KABUL EDİLDİ |
| [0008](0008-cok-dillilik.md) | Çok dillilik ve ondalık ayırıcı | KABUL EDİLDİ |
| [0009](0009-eleman-sozlesmesi.md) | Eleman sözleşmesi | KABUL EDİLDİ |

---

## Ne zaman ADR yazılır

- Dört dondurulmuş sözleşmeden birine dokunulduğunda (zorunlu)
- Yeni bir bağımlılık eklendiğinde, koşullu lisans listesindeyse (zorunlu)
- Kapsam sınırı değiştiğinde (zorunlu)
- Geri dönüşü pahalı herhangi bir teknik seçimde (önerilir)

Bir toleransın değişmesi ADR gerektirmez ama gerekçesinin
[doğrulama planına](../dogrulama/DOGRULAMA-PLANI.md) yazılmasını gerektirir.
