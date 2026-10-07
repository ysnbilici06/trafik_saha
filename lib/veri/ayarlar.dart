/// Güncel veri dosyalarının yayımlandığı adres (sonunda "/" olmadan).
///
/// Tarayıcı (tarayici/guncelle.py) GitHub Actions ile çalışıp assets/veri klasörünü
/// güncelledikçe uygulama bu adresten yeni veriyi indirir. Örnek:
/// https://raw.githubusercontent.com/KULLANICI/trafik-saha/main/assets/veri
///
/// Boş bırakılırsa uygulama yalnızca kurulumla gelen veriyi kullanır.
const String veriAdresi =
    'https://raw.githubusercontent.com/ysnbilici06/trafik_saha/main/assets/veri';

const String uygulamaAdi = 'Trafik Saha';

const List<String> veriDosyalari = [
  'cezalar_2918.json',
  'cezalar_4925.json',
  'mevzuat_2918.json',
  'mevzuat_4925.json',
  'icerik.json',
  'duyurular.json',
  'haberler.json',
  'kitaplik.json',
];
