---
name: Doğrulama problemi
about: Yeni bir VER-xxx doğrulama problemi. Bağımsız referans ve toleransın gerekçesi zorunlu.
title: '[VER-xxx] '
labels: dogrulama
assignees: ''
---

<!--
ASME V&V 10 çerçevesi. Üç şey ZORUNLUDUR: bağımsız referans, belirtilen
tolerans, ve toleransın GEREKÇESİ. "Geçiyor" bir tolerans gerekçesi
değildir.
-->

## VER numarası

<!--
VER numaraları ASLA yeniden kullanılmaz ve ASLA kaydırılmaz. Yeni problem
listenin SONUNA eklenir. Şu an kullanımda olan en büyük numara için
docs/dogrulama/DOGRULAMA-PLANI.md dosyasına bakınız.
-->

**VER-**

## Ne doğrulanıyor

<!-- Hangi denklem, hangi yordam, hangi davranış. -->

## Bağımsız referans

<!--
"Kendi çıktımıza benziyor" REFERANS DEĞİLDİR. Şunlardan biri olmalı:
  - analitik tam çözüm (kaynak künyesiyle)
  - yakınsama mertebesi
  - başka bir kodun sonucu (FEBio — MIT, okunması ve karşılaştırılması serbest)
  - bağımsız olarak hesaplanmış referans tablo
-->

## Tolerans

**Sayı:**

## Toleransın gerekçesi

<!--
Şu dört kategoriden BİRİNE bağlanmalı:

  - Yuvarlama tabanı — çift hassasiyette ulaşılabilecek en iyi değer
    (örn. merkezi farkta eps/h ~ 1e-10)
  - Kesme hatası — sayısal yöntemin mertebesinden hesaplanan sınır
  - Fiziksel sapma — modelin referanstan BİLEREK ayrıldığı miktar
    (örn. sonlu K'nın sıkıştırılamaz çözümden sapması, mu/K mertebesinde)
  - Mühendislik kabulü — açıkça gerekçelendirilmiş, tasarım kararını
    değiştirmeyecek büyüklük

Referans yuvarlanmış bir tablodan geliyorsa, tablonun kendi gösterim
hassasiyeti de gerekçenin parçasıdır.
-->

## Sürüm

<!-- Bu doğrulamanın hangi sürümün kapısında olduğu. -->

## Bitmiş sayılma koşulu

- [ ] Test `test/` altında, **belirlenimci** (rastgele girdi yok)
- [ ] Test çıktısı "GEÇTİ" değil, **ölçülen değeri ve toleransı** bastırıyor
- [ ] `docs/dogrulama/DOGRULAMA-PLANI.md` içine satır eklendi
- [ ] Geçtiğinde plana ölçülen değer yazıldı
- [ ] `CMakeLists.txt` içinde `des_add_test` ile kayıtlı
