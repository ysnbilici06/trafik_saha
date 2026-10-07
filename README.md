# Trafik Saha

Trafik personeli için saha rehberi: 2918 ve 4925 sayılı kanunların ceza rehberi ve tam metni,
soru-cevap asistanı, hesaplayıcılar, kontrol listeleri, quiz, kaza örnekleri ve emsal kararlar.
Flutter ile yazılmıştır (Android, iOS, web).

## Çalıştırma

Kullanıcı klasörünün adındaki Türkçe karakterler Dart ve Android araçlarını bozduğu için
komutlar projeye açılan ASCII bağlantı yolundan çalıştırılmalıdır:

```powershell
$env:Path = "C:\src\flutter\bin;C:\Program Files\Git\cmd;" + $env:Path
cd C:\src\trafik_saha          # Desktop\Deneme klasörüne bağlantı
flutter run -d chrome           # tarayıcıda dene
flutter test                    # testler
flutter build apk               # Android paketi (Android SDK kurulduktan sonra)
```

## Yapı

| Klasör | İçerik |
| --- | --- |
| `lib/veri/` | Veri deposu, hesap motoru, asistan motoru |
| `lib/ekranlar/` | Ekranlar |
| `assets/veri/` | Uygulamayla gelen veri (tarayıcı üretir; `icerik.json` elle yazılır) |
| `tarayici/` | Resmî kaynakları indirip veriye çeviren Python betikleri |
| `.github/workflows/` | Tarayıcıyı saatte bir çalıştıran iş akışı |

## Veri ve otomatik güncelleme

`python tarayici/guncelle.py` şu kaynakları indirir, ayrıştırır ve `assets/veri` klasörünü yeniler:

- EGM Trafik Başkanlığı – Trafik İdari Para Ceza Rehberi (2918 cezaları)
- mevzuat.gov.tr – 2918 ve 4925 sayılı Kanun metinleri
- Ulaştırma ve Altyapı Bakanlığı – 4925 md. 26 ceza tablosu
- Resmî Gazete – günlük fihristte trafik mevzuatına değinen yayınlar (duyuru olarak)

Değişiklikler `duyurular.json` dosyasına madde madde yazılır ve uygulamada duyuru olarak görünür.

Telefonlardaki uygulamanın güncel veriyi alması için:

1. Projeyi bir GitHub deposuna gönderin; iş akışı saatte bir çalışıp veriyi günceller.
2. `lib/veri/ayarlar.dart` içindeki `veriAdresi` değerini deponun ham adresine ayarlayın
   (`https://raw.githubusercontent.com/KULLANICI/DEPO/main/assets/veri`).

Adres boşken uygulama kurulumla gelen veriyi kullanır.

## İçerik ekleme

Quiz soruları, kaza örnekleri, kararlar ve kontrol listeleri `assets/veri/icerik.json` dosyasındadır.
Kaza örneklerindeki `ihlaller` ve listelerdeki `ceza` alanları ceza kalemi kimliklerine bağlanır;
`flutter test` kırık bağlantıları yakalar.
