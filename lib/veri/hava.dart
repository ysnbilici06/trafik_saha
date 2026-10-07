import 'dart:convert';

import 'package:http/http.dart' as http;

/// Open-Meteo'dan alınan anlık hava durumu ve önümüzdeki saatlerin tahmini.
class Hava {
  Hava.fromJson(Map<String, dynamic> j)
      : zaman = DateTime.parse((j['current'] as Map<String, dynamic>)['time'] as String),
        sicaklik = _s(j, 'temperature_2m'),
        hissedilen = _s(j, 'apparent_temperature'),
        yagis = _s(j, 'precipitation'),
        kod = _s(j, 'weather_code').round(),
        ruzgar = _s(j, 'wind_speed_10m'),
        hamle = _s(j, 'wind_gusts_10m'),
        gorus = _s(j, 'visibility'),
        nem = _s(j, 'relative_humidity_2m').round(),
        gunduz = _s(j, 'is_day') == 1 {
    final h = j['hourly'] as Map<String, dynamic>?;
    if (h != null) {
      final saatler = (h['time'] as List<dynamic>).cast<String>();
      for (var i = 1; i < saatler.length; i++) {
        saatlik.add((
          saatler[i].substring(11, 16),
          (h['temperature_2m'] as List<dynamic>)[i] as num,
          ((h['weather_code'] as List<dynamic>)[i] as num).round(),
          (((h['precipitation_probability'] as List<dynamic>)[i] as num?) ?? 0).round(),
        ));
      }
    }
  }

  static double _s(Map<String, dynamic> j, String ad) =>
      (((j['current'] as Map<String, dynamic>)[ad] as num?) ?? 0).toDouble();

  final DateTime zaman;
  final double sicaklik;
  final double hissedilen;

  /// Son 15 dakikadaki yağış (mm).
  final double yagis;

  /// WMO hava durumu kodu.
  final int kod;
  final double ruzgar;
  final double hamle;

  /// Görüş mesafesi (metre).
  final double gorus;
  final int nem;
  final bool gunduz;

  /// (saat, sıcaklık, WMO kodu, yağış olasılığı %)
  final List<(String, num, int, int)> saatlik = [];

  String get durum => havaAciklamasi(kod);
}

String havaAciklamasi(int kod) => switch (kod) {
      0 => 'Açık',
      1 => 'Az bulutlu',
      2 => 'Parçalı bulutlu',
      3 => 'Kapalı',
      45 || 48 => 'Sisli',
      51 || 53 || 55 => 'Çisenti',
      56 || 57 => 'Donan çisenti',
      61 || 63 || 65 => 'Yağmurlu',
      66 || 67 => 'Donan yağmur',
      71 || 73 || 75 || 77 => 'Kar yağışlı',
      80 || 81 || 82 => 'Sağanak yağışlı',
      85 || 86 => 'Kar sağanağı',
      95 => 'Gök gürültülü fırtına',
      96 || 99 => 'Dolulu fırtına',
      _ => 'Bilinmiyor',
    };

bool _kar(int k) => const {71, 73, 75, 77, 85, 86}.contains(k);
bool _don(int k) => const {56, 57, 66, 67}.contains(k);
bool _yagmur(int k) => const {51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 99}.contains(k);

/// Hava koşullarının yol ve denetim açısından anlamı. Boş liste: olumsuz koşul yok.
List<String> yolUyarilari(Hava h) {
  final u = <String>[];
  if (_kar(h.kod)) u.add('Kar yağışı: yol kaygan; kış lastiği ve zincir denetimi gündemde.');
  if (_don(h.kod) || h.sicaklik <= 1) u.add('Buzlanma riski (${h.sicaklik.toStringAsFixed(0)}°C): köprü, viyadük ve gölge kesimlere dikkat.');
  if (_yagmur(h.kod) || h.yagis > 0) u.add('Yağış: zemin ıslak; durma mesafesi uzar, hız ve takip mesafesi denetimi önemli.');
  if (h.kod == 45 || h.kod == 48 || h.gorus < 1000) u.add('Görüş mesafesi düşük (${h.gorus.round()} m): sis ışığı kullanımı ve hız.');
  if (h.hamle >= 50) u.add('Kuvvetli rüzgâr (hamle ${h.hamle.round()} km/s): yüksek ve yüklü araçlarda devrilme riski.');
  return u;
}

/// Kaza kaydına yazılacak kısa hava özeti.
String havaOzeti(Hava h) => '${h.durum}, ${h.sicaklik.toStringAsFixed(0)}°C, rüzgâr ${h.ruzgar.round()} km/s, '
    'görüş ${h.gorus >= 10000 ? '10 km+' : '${h.gorus.round()} m'}';

/// Koordinat, konum gizliliği için yaklaşık 1 km duyarlığa yuvarlanarak gönderilir.
Future<Map<String, dynamic>> havaIndir(double enlem, double boylam) async {
  final adres = Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': enlem.toStringAsFixed(2),
    'longitude': boylam.toStringAsFixed(2),
    'current': 'temperature_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_gusts_10m,visibility,relative_humidity_2m,is_day',
    'hourly': 'temperature_2m,weather_code,precipitation_probability',
    'forecast_hours': '7',
    'timezone': 'auto',
  });
  final yanit = await http.get(adres).timeout(const Duration(seconds: 15));
  if (yanit.statusCode != 200) throw Exception('Hava servisi ${yanit.statusCode}');
  return jsonDecode(utf8.decode(yanit.bodyBytes)) as Map<String, dynamic>;
}

/// Karayolları bölge müdürlüklerinin tamamını (ya da büyük kısmını) kapsadığı iller.
/// Kaynak: KGM bölge müdürlüğü sayfalarındaki "Genel Bilgi" metinleri (kgm.gov.tr, Ekim 2026).
const _kgmBolgeleri = {
  1: 'istanbul edirne kirklareli tekirdag kocaeli sakarya',
  2: 'izmir aydin denizli manisa mugla usak',
  3: 'konya karaman afyonkarahisar aksaray',
  4: 'ankara bolu eskisehir duzce kirikkale',
  5: 'mersin adana gaziantep hatay kahramanmaras kilis osmaniye',
  6: 'kayseri kirsehir nevsehir nigde yozgat',
  7: 'samsun ordu sinop amasya tokat corum',
  8: 'elazig malatya adiyaman bingol tunceli',
  9: 'diyarbakir siirt batman sirnak mardin sanliurfa',
  10: 'trabzon rize giresun artvin gumushane bayburt',
  11: 'van bitlis mus hakkari',
  12: 'erzurum agri',
  13: 'antalya isparta burdur',
  14: 'bursa bilecik balikesir canakkale kutahya yalova',
  15: 'kastamonu bartin karabuk cankiri zonguldak',
  16: 'sivas erzincan',
  18: 'kars ardahan igdir',
};

/// İlin bağlı olduğu Karayolları bölge müdürlüğü numarası. [il] sadeleştirilmiş (katla) yazılmalıdır.
int? kgmBolgesi(String il) {
  for (final b in _kgmBolgeleri.entries) {
    if (b.value.split(' ').contains(il)) return b.key;
  }
  return null;
}

/// Çalışma yapılan yollar: il biliniyorsa o ilin bölge sayfası, bilinmiyorsa bölge listesi.
String calismaYollariAdresi(String il) {
  const taban = 'https://www.kgm.gov.tr/Sayfalar/KGM/SiteTr/YolDanisma';
  final bolge = kgmBolgesi(il);
  return bolge == null ? '$taban/CalismaYapilanYollar.aspx' : '$taban/CalismaYapilanYollarYeni.aspx?Bolge=$bolge';
}

/// İl adından merkez koordinatını bulur.
Future<(double, double)?> ilKonumu(String il) async {
  final adres = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
    'name': il,
    'count': '1',
    'language': 'tr',
    'countryCode': 'TR',
  });
  final yanit = await http.get(adres).timeout(const Duration(seconds: 15));
  if (yanit.statusCode != 200) return null;
  final sonuclar = (jsonDecode(utf8.decode(yanit.bodyBytes)) as Map<String, dynamic>)['results'] as List<dynamic>?;
  if (sonuclar == null || sonuclar.isEmpty) return null;
  final s = sonuclar.first as Map<String, dynamic>;
  return ((s['latitude'] as num).toDouble(), (s['longitude'] as num).toDouble());
}
