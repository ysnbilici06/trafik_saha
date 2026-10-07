/// Türkçe karakterleri sadeleştirip küçük harfe çevirir; arama eşleştirmesinde kullanılır.
String katla(String s) {
  const kaynak = 'İIıŞşĞğÜüÖöÇçÂâÎîÛû';
  const hedef = 'iiissgguuooccaaiiuu';
  final b = StringBuffer();
  for (final r in s.runes) {
    final k = String.fromCharCode(r);
    final i = kaynak.indexOf(k);
    b.write(i >= 0 ? hedef[i] : k.toLowerCase());
  }
  return b.toString().replaceAll('̇', '');
}

String para(num? v) {
  if (v == null) return '-';
  final kurus = (v * 100).round();
  final tam = (kurus ~/ 100).toString();
  final b = StringBuffer();
  for (var i = 0; i < tam.length; i++) {
    if (i > 0 && (tam.length - i) % 3 == 0) b.write('.');
    b.write(tam[i]);
  }
  final k = kurus % 100;
  return '${b.toString()}${k == 0 ? '' : ',${k.toString().padLeft(2, '0')}'} TL';
}

String tarihYaz(DateTime t, {bool saat = false}) {
  String iki(int n) => n.toString().padLeft(2, '0');
  final gun = '${iki(t.day)}.${iki(t.month)}.${t.year}';
  return saat ? '$gun ${iki(t.hour)}:${iki(t.minute)}' : gun;
}

/// "7 Ekim 2026 Çarşamba" biçiminde uzun tarih.
String uzunTarih(DateTime t) {
  const aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
  const gunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
  return '${t.day} ${aylar[t.month - 1]} ${t.year} ${gunler[t.weekday - 1]}';
}

class Ceza {
  Ceza(this.kanun, Map<String, dynamic> j)
      : id = j['id'] as String,
        madde = j['madde'] as String,
        konu = j['konu'] as String? ?? '',
        kime = j['kime'] as String? ?? '',
        tutar = (j['tutar'] as num?)?.toDouble(),
        kademeli = j['kademeli'] as bool? ?? false,
        cezaMetin = j['cezaMetin'] as String? ?? '',
        puan = j['puan'] as int?,
        belge = j['belge'] as String? ?? '',
        mahkeme = j['mahkeme'] as String? ?? '',
        men = j['men'] as String? ?? '',
        kullanmaktanMen = j['kullanmaktanMen'] as String? ?? '',
        mulkiAmir = j['mulkiAmir'] as String? ?? '',
        diger = j['diger'] as String? ?? '',
        cumle = j['cumle'] as String? ?? '',
        altSinir = (j['altSinir'] as num?)?.toDouble(),
        ustSinir = (j['ustSinir'] as num?)?.toDouble() {
    arama = katla('$madde $konu $kime');
  }

  final String kanun;
  final String id;
  final String madde;
  final String konu;
  final String kime;
  final double? tutar;
  final bool kademeli;
  final String cezaMetin;
  final int? puan;
  final String belge;
  final String mahkeme;
  final String men;
  final String kullanmaktanMen;
  final String mulkiAmir;
  final String diger;
  final String cumle;
  final double? altSinir;
  final double? ustSinir;
  late final String arama;

  String get anahtar => '$kanun:$id';

  /// Maddenin ana numarası (ör. "47/1-b" için "47").
  String get anaMadde => madde.split('/').first.trim();

  double? get indirimli => tutar == null ? null : tutar! * 0.75;

  /// Listelerde gösterilecek kısa tutar yazısı.
  String get tutarYazisi {
    if (tutar != null) return kademeli ? '${para(tutar)}+' : para(tutar);
    if (mulkiAmir.isNotEmpty) return 'Mülki amir';
    if (belge.isNotEmpty || mahkeme.isNotEmpty) return 'Belge işlemi';
    return '-';
  }
}

class Madde {
  Madde(this.kanun, Map<String, dynamic> j)
      : id = j['id'] as String,
        no = j['no'] as String,
        baslik = j['baslik'] as String? ?? '',
        kisim = j['kisim'] as String? ?? '',
        metin = j['metin'] as String? ?? '' {
    arama = katla('$no $baslik $metin');
  }

  final String kanun;
  final String id;
  final String no;
  final String baslik;
  final String kisim;
  final String metin;
  late final String arama;

  String get anahtar => '$kanun:$id';
  String get etiket => no.contains(' ') ? '$no. Madde' : 'Madde $no';
}
