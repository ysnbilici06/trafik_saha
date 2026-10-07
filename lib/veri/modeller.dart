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

/// Gündelik söyleyişlerin rehber metnindeki karşılıkları; ceza aramasında ikisi de denenir.
const _aramaEsAnlam = {
  'ehliyet': 'surucu belgesi',
  'ruhsat': 'tescil belgesi',
  'kask': 'koruma basligi',
};

/// Arama kutusuna yazılanı kelimelere ayırır; her kelime için denenecek yazılışları verir.
List<List<String>> aramaKelimeleri(String arama) => [
      for (final k in katla(arama).split(RegExp(r'\s+')).where((k) => k.isNotEmpty))
        [
          k,
          for (final e in _aramaEsAnlam.entries)
            if (k.startsWith(e.key)) e.value,
        ],
    ];

/// Rehberin "diğer hususlar" sütunundaki paragrafı madde madde okunacak parçalara böler:
/// yıldızla başlayan notlar ve cümleler ayrı madde olur, numaralı alt bentler kendi satırına iner.
List<String> maddelereAyir(String metin) {
  final duz = metin
      .replaceAll('-\n', '-')
      .replaceAll('\n', ' ')
      .replaceAllMapped(RegExp(r'([a-zçğıöşü]{4}\.)\s+(?=[A-ZÇĞİÖŞÜ])'), (m) => '${m[1]}\u0000')
      .replaceAll(RegExp(r'(^|\s)\*\s*'), '\u0000')
      .replaceAll(RegExp(r' (?=\d[-)] )'), '\n');
  return [
    for (final p in duz.split('\u0000'))
      if (p.trim().isNotEmpty) p.trim(),
  ];
}

/// [metin] içinde [terimler]in (katlanmış yazılışlarıyla) geçtiği aralıkları verir; vurgulama içindir.
List<(int, int)> eslesenAraliklar(String metin, Iterable<String> terimler) {
  // katla() bazı karakterleri düşürebildiği için katlanmış konumdan asıl konuma harita tutulur.
  final katli = StringBuffer();
  final konum = <int>[];
  for (var i = 0; i < metin.length; i++) {
    final k = katla(metin[i]);
    katli.write(k);
    for (var j = 0; j < k.length; j++) {
      konum.add(i);
    }
  }
  final s = katli.toString();
  final araliklar = <(int, int)>[];
  for (final t in terimler) {
    if (t.isEmpty) continue;
    for (var i = s.indexOf(t); i >= 0; i = s.indexOf(t, i + t.length)) {
      araliklar.add((konum[i], konum[i + t.length - 1] + 1));
    }
  }
  araliklar.sort((a, b) => a.$1.compareTo(b.$1));
  final birlesik = <(int, int)>[];
  for (final a in araliklar) {
    if (birlesik.isNotEmpty && a.$1 <= birlesik.last.$2) {
      if (a.$2 > birlesik.last.$2) birlesik.last = (birlesik.last.$1, a.$2);
    } else {
      birlesik.add(a);
    }
  }
  return birlesik;
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
    aramaEk = katla('$diger $men'.replaceAll('-\n', '-').replaceAll('\n', ' '));
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

  /// Aramada ikinci sırada bakılan metin: diğer hususlar ve trafikten men açıklaması.
  late final String aramaEk;

  String get anahtar => '$kanun:$id';

  /// Araç trafikten men ediliyor ya da sürücü araç kullanmaktan men ediliyorsa doğru.
  bool get menGerektirir => men.isNotEmpty || kullanmaktanMen.isNotEmpty;

  /// [kelimeler] ([aramaKelimeleri] çıktısı) bu kalemde geçiyorsa bulunan yazılışları verir, yoksa null.
  /// [asil] yalnızca madde no, ihlal tanımı ve muhatap içinde arar.
  List<String>? eslesenler(List<List<String>> kelimeler, {bool asil = false}) {
    final bulunan = <String>[];
    for (final secenekler in kelimeler) {
      final b = secenekler.where((s) => arama.contains(s) || (!asil && aramaEk.contains(s)));
      if (b.isEmpty) return null;
      bulunan.addAll(b);
    }
    return bulunan;
  }

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
        metin = j['metin'] as String? ?? '';

  final String kanun;
  final String id;
  final String no;
  final String baslik;
  final String kisim;
  final String metin;

  /// Arama için katlanmış metin. Kitaplık binlerce madde içerdiğinden ilk kullanımda hesaplanır.
  late final String arama = katla('$no $baslik $metin');

  String get anahtar => '$kanun:$id';
  String get etiket => no.contains(' ') ? '$no. Madde' : 'Madde $no';
}
