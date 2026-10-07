import 'dart:convert';

import 'package:http/http.dart' as http;

/// Uygulama içinden doğrudan haber araması. Asıl haber listesi tarayıcının ürettiği
/// haberler.json dosyasından gelir; bu, veri güncellemesi beklenmeden taze başlık almak içindir.
/// Tarayıcılar bu adreslere doğrudan erişime izin vermediği için web sürümünde kullanılmaz.
const _aramalar = {
  'kaza': 'https://news.google.com/rss/search?q=%22trafik+kazas%C4%B1%22+when:2d&hl=tr&gl=TR&ceid=TR:tr',
  'mevzuat':
      'https://news.google.com/rss/search?q=trafik+(kanun+OR+d%C3%BCzenleme+OR+y%C3%B6netmelik+OR+teklif+OR+%22Resmi+Gazete%22+OR+cezalar%C4%B1)+when:14d&hl=tr&gl=TR&ceid=TR:tr',
};

final _yurtDisi = RegExp(r'kktc|kıbrıs|vietnam|hanoi|hollanda|almanya|fransa|rusya', caseSensitive: false);
final _kazaDegil = RegExp(r'uçak|helikopter|gemi|vapur|tekne|maden|iş kazası', caseSensitive: false);
final _mevzuatDegil = RegExp(r'trafik akış|sigorta|caddesi|bulvarı|kavşa[kğ]', caseSensitive: false);
final _mevzuatKelime = RegExp(
    r'kanun|yasa|yönetmelik|yeni düzenleme|tbmm|meclis|resm[îi] gazete|genelge|yürürlü|zam|yeniden değerleme|cezalar[ıi]',
    caseSensitive: false);

const _varliklar = {'&amp;': '&', '&quot;': '"', '&#39;': "'", '&apos;': "'", '&lt;': '<', '&gt;': '>', '&nbsp;': ' '};

String _temiz(String s) {
  var t = s.replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '');
  _varliklar.forEach((k, v) => t = t.replaceAll(k, v));
  return t.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _alan(String oge, String ad) => RegExp('<$ad\\b[^>]*>(.*?)</$ad>', dotAll: true).firstMatch(oge)?.group(1) ?? '';

/// Haberleri aynı olay için tekilleştirmekte kullanılan anahtar.
String haberAnahtari(String baslik) => baslik.toLowerCase().replaceAll(RegExp(r'[^a-z0-9çğıöşü]+'), '');

/// RSS'teki "Wed, 07 Oct 2026 10:14:46 GMT" biçimini çözer.
DateTime? rssTarihi(String s) {
  final m = RegExp(r'(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) ?([+-]\d{4}|GMT|UTC)?').firstMatch(s);
  if (m == null) return null;
  const aylar = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final ay = aylar.indexOf(m.group(2)!) + 1;
  if (ay == 0) return null;
  var t = DateTime.utc(int.parse(m.group(3)!), ay, int.parse(m.group(1)!), int.parse(m.group(4)!), int.parse(m.group(5)!), int.parse(m.group(6)!));
  final dilim = m.group(7);
  if (dilim != null && dilim.length == 5) {
    final fark = Duration(hours: int.parse(dilim.substring(1, 3)), minutes: int.parse(dilim.substring(3)));
    t = dilim.startsWith('+') ? t.subtract(fark) : t.add(fark);
  }
  return t;
}

/// RSS metnindeki öğeleri haber kayıtlarına çevirir; kategoriye uymayanları eler.
List<Map<String, dynamic>> rssCoz(String xml, String kategori) {
  final sonuc = <Map<String, dynamic>>[];
  for (final e in RegExp(r'<item\b.*?</item>', dotAll: true).allMatches(xml)) {
    final oge = e.group(0)!;
    final tam = _temiz(_alan(oge, 'title'));
    final kaynak = _temiz(_alan(oge, 'source'));
    final baslik = kaynak.isNotEmpty && tam.endsWith(' - $kaynak') ? tam.substring(0, tam.length - kaynak.length - 3) : tam;
    final tarih = rssTarihi(_alan(oge, 'pubDate'));
    final url = _temiz(_alan(oge, 'link'));
    if (baslik.isEmpty || url.isEmpty || tarih == null || _yurtDisi.hasMatch(baslik)) continue;
    final uygun = kategori == 'kaza'
        ? baslik.toLowerCase().contains('kaza') && !_kazaDegil.hasMatch(baslik)
        : _mevzuatKelime.hasMatch(baslik) && !_mevzuatDegil.hasMatch(baslik) && !baslik.toLowerCase().contains('trafik kazas');
    if (!uygun) continue;
    sonuc.add({
      'id': haberAnahtari(baslik),
      'kategori': kategori,
      'baslik': baslik,
      'kaynak': kaynak,
      'tarih': tarih.toIso8601String(),
      'url': url,
      'ozet': '',
      'gorsel': '',
    });
  }
  return sonuc;
}

Future<List<Map<String, dynamic>>> haberleriIndir() async {
  final sonuc = <Map<String, dynamic>>[];
  for (final a in _aramalar.entries) {
    final yanit = await http.get(Uri.parse(a.value)).timeout(const Duration(seconds: 20));
    if (yanit.statusCode == 200) sonuc.addAll(rssCoz(utf8.decode(yanit.bodyBytes, allowMalformed: true), a.key));
  }
  return sonuc;
}

/// İki haber listesini birleştirir: aynı başlık bir kez yer alır, görselli/özetli olan korunur,
/// en yeni haber başa gelir.
List<Map<String, dynamic>> haberleriBirlestir(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b, {int sinir = 120}) {
  final tekil = <String, Map<String, dynamic>>{};
  for (final h in [...a, ...b]) {
    final anahtar = haberAnahtari(h['baslik'] as String);
    final onceki = tekil[anahtar];
    if (onceki == null || ((onceki['gorsel'] as String? ?? '').isEmpty && (h['gorsel'] as String? ?? '').isNotEmpty)) {
      tekil[anahtar] = h;
    }
  }
  final liste = tekil.values.toList()..sort((x, y) => (y['tarih'] as String).compareTo(x['tarih'] as String));
  return liste.take(sinir).toList();
}

/// Her başlık (kaza, mevzuat) altında gösterilen en fazla haber sayısı.
const haberSiniri = 5;

/// Listeyi her kategoriden en yeni [sinir] haberle sınırlar; sıra korunur.
List<Map<String, dynamic>> haberleriSinirla(List<Map<String, dynamic>> haberler, {int sinir = haberSiniri}) {
  final sayac = <String, int>{};
  return [
    for (final h in haberler)
      if ((sayac[h['kategori'] as String] = (sayac[h['kategori'] as String] ?? 0) + 1) <= sinir) h,
  ];
}

/// Haberlerin günlük yenilenme saati (cihaz saatiyle).
const haberYenilemeSaati = 6;

/// [simdi]den önceki en son sabah 06:00. Son yenileme bundan eskiyse liste yenilenir.
DateTime sonSabahAlti(DateTime simdi) {
  final bugun = DateTime(simdi.year, simdi.month, simdi.day, haberYenilemeSaati);
  return simdi.isBefore(bugun) ? DateTime(simdi.year, simdi.month, simdi.day - 1, haberYenilemeSaati) : bugun;
}

/// "3 sa önce", "2 gün önce" gibi göreli zaman.
String neZaman(DateTime t, {DateTime? simdi}) {
  final fark = (simdi ?? DateTime.now()).difference(t);
  if (fark.inMinutes < 1) return 'az önce';
  if (fark.inMinutes < 60) return '${fark.inMinutes} dk önce';
  if (fark.inHours < 24) return '${fark.inHours} sa önce';
  if (fark.inDays < 30) return '${fark.inDays} gün önce';
  return '${fark.inDays ~/ 30} ay önce';
}
