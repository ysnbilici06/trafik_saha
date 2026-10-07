import 'dart:math' as math;

import 'depo.dart';
import 'hesap.dart';
import 'modeller.dart';

/// Asistanın bir soruya verdiği cevap: açıklama metni ve dokunulabilir kaynaklar.
class Cevap {
  Cevap(this.metin, {this.yorum = '', this.cezalar = const [], this.maddeler = const [], this.kazalar = const []});
  final String metin;

  /// Asistanın kendi değerlendirmesi. Mevzuat bilgisi değildir; ekranda ayrı ve etiketli gösterilir.
  final String yorum;

  /// Kopyalama için cevap ve yorum birlikte.
  String get tamMetin => yorum.isEmpty ? metin : '$metin\n\nYorum: $yorum';
  final List<Ceza> cezalar;
  final List<Madde> maddeler;
  final List<Map<String, dynamic>> kazalar;
}

/// Cihaz içinde çalışan soru-cevap motoru. Soruyu çözümler (hız, alkol, madde, kusur,
/// genel arama) ve cevabı yalnızca uygulamadaki resmî veriden kurar; veri dışında bilgi üretmez.
class Asistan {
  Asistan(this.depo);
  final Depo depo;

  static const _etkisiz = {
    've', 'veya', 'ile', 'icin', 'bir', 'bu', 'su', 'ne', 'nedir', 'kac', 'kadar', 'mi', 'mu', 'midir', 'nasil',
    'olur', 'olursa', 'ceza', 'cezasi', 'cezalar', 'para', 'tl', 'lira', 'var', 'yok', 'ben', 'bana', 'hangi',
    'madde', 'maddesi', 'gore', 'trafik', 'arac', 'araci', 'surucu', 'surucuye', 'yazilir', 'kesilir', 'verilir',
    'ise', 'de', 'da', 'ki', 'en', 'cok', 'daha', 'olan', 'olarak', 'halinde', 'durumunda', 'neler', 'hakkinda',
    'kullanmak', 'kullanma', 'kullanan', 'kullanirsa', 'yapmak', 'yapan', 'etmek', 'eden', 'gidersem', 'giden',
    'olmayan', 'olmayanlar', 'bulunmayan', 'yapmamak', 'atmak', 'atma', 'atan', 'ver', 'verir', 'olmadan', 'almadan', 'olmak', 'sayili', 'kanun', 'kanunu', '2918', '4925',
  };

  /// Günlük dildeki ifadeleri mevzuattaki karşılıklarına bağlar.
  static const _esAnlam = {
    'ehliyetsiz': 'surucu belgesi sahibi olmadan',
    'ehliyet': 'surucu belgesi',
    'kemer': 'emniyet kemeri',
    'telefon': 'cep telefonu haberlesme',
    'makas': 'serit degistirme tehlikeye',
    'drift': 'donus kurallari disinda bilerek',
    'sigorta': 'mali sorumluluk sigortasi',
    'kask': 'koruma basligi',
    'ters yon': 'ters istikamet',
    'sollama': 'gecme gecmek',
    'takip mesafesi': 'guvenli yeterli mesafe izle',
    'cocuk koltugu': 'cocuk koruyucu sistem',
    'sinyal': 'donus isaret isiklari',
    'src': 'mesleki yeterlilik belgesi',
    'korsan': 'calisma izni ruhsat almadan',
    'dur ihtar': 'uyari ve isaretlerine uymayarak',
    'kacmak': 'uyari ve isaretlerine uymayarak',
    'ruhsat': 'tescil belgesi',
    'cam filmi': 'renkli film',
    'egzoz': 'ses gurultu',
    'modifiye': 'teknik degisiklik',
    'yaya gecidi': 'yaya gecitleri ilk gecis hakki',
    'kirmizi': 'kirmizi isik',
    'engelli': 'engellilerin araclari icin ayrilmis park',
    'unut': 'yaninda bulundurmamak',
    'yetki belgesi': 'yetki belgesi almadan',
    'emniyet seridi': 'ariza halleri acil',
  };

  Cevap cevapla(String soru) {
    final q = katla(soru).replaceAll(RegExp(r'[?!]'), ' ').trim();
    if (q.isEmpty) return Cevap('Bir şey yazmadınız galiba. Örneğin "50 sınırında 82 ile gitmenin cezası" diye sorabilirsiniz.');
    return _sohbet(q) ??
        _maddeSorusu(q) ??
        _hizSorusu(q) ??
        _alkolSorusu(q) ??
        _puanSorusu(q) ??
        _odemeSorusu(q) ??
        _kusurSorusu(q) ??
        _genel(q);
  }

  /// Selamlaşma, teşekkür gibi mevzuat dışı kısa yazışmalar.
  Cevap? _sohbet(String q) {
    if (q.length > 40) return null;
    final ad = (depo.profil['ad'] as String? ?? '').trim().split(' ').first;
    final hitap = ad.isEmpty ? '' : ' $ad';
    if (RegExp(r'^(merhaba|selam|iyi gunler|iyi aksamlar|iyi geceler|gunaydin|sa|slm|hey)\b').hasMatch(q)) {
      return Cevap('Merhaba$hitap, hoş geldiniz. Aklınıza takılan ne varsa yazın: ceza tutarı, puan, hız ya da alkol hesabı, '
          'bir kazada kimin kusurlu olduğu… Bildiğimi söylerim, üstüne kendi görüşümü de eklerim.');
    }
    if (RegExp(r'nasilsin|naber|ne haber|keyifler').hasMatch(q)) {
      return Cevap('İyiyim$hitap, sağ olun. Benim işim hep mevzuat, sıkılmıyorum. Sizde durum nasıl, sahada bir şey mi çıktı?');
    }
    if (RegExp(r'tesekkur|sagol|sag ol|eyvallah|eline saglik').hasMatch(q)) {
      return Cevap(_sec(q, ['Rica ederim$hitap, kolay gelsin.', 'Ne demek, her zaman. İyi görevler$hitap.', 'Rica ederim. Başka bir şey olursa buradayım.']));
    }
    if (RegExp(r'kolay gelsin|iyi gorevler|hayirli (isler|gorevler)').hasMatch(q)) {
      return Cevap('Sağ olun$hitap, size de kolay gelsin. Dikkatli olun sahada.');
    }
    if (RegExp(r'gorusuruz|hosca ?kal|bay bay|iyi calismalar').hasMatch(q)) {
      return Cevap('Görüşürüz$hitap, iyi görevler.');
    }
    if (RegExp(r'kimsin|nesin|adin ne|insan misin|robot|yapay zeka mi|ne yapabilirsin|ne is yapar|neler sorabilirim').hasMatch(q)) {
      return Cevap('Ben Trafik Saha\'nın asistanıyım. Açık konuşayım: karşınızda bir insan yok, internete de bağlanmıyorum; '
          'cevaplarımı uygulamadaki ceza rehberinden, kanun metinlerinden ve kaza örneklerinden kuruyorum.\n\n'
          'Ceza tutarı, ceza puanı, hız ve alkol hesabı, ödeme süresi ya da "şu kazada kim kusurlu" gibi şeyler sorabilirsiniz. '
          'Rakamları kaynaktan veririm, altına da kendi yorumumu ayrı olarak yazarım.');
    }
    return null;
  }

  /// Aynı soruya hep aynı, farklı sorulara farklı giriş cümlesi seçer.
  static String _sec(String q, List<String> secenekler) => secenekler[q.codeUnits.fold(0, (a, b) => a + b) % secenekler.length];

  Cevap? _odemeSorusu(String q) {
    if (!RegExp(r'\boden|\bodeme|indirim|faiz|taksit|kac gun').hasMatch(q)) return null;
    final m = depo.madde('2918', '115');
    if (m == null) return null;
    return Cevap(
        'Kısaca şöyle: ceza hemen ödenmezse, tutanağın tebliğ tarihinden itibaren bir ay içinde ödenmesi gerekiyor (md. 115).\n\n'
        '• Ceza rehberinde her kalem için %25 indirimli tutar ayrıca gösterilir.\n'
        '• Bir ay içinde ödenmeyen cezaya her ay %5 faiz uygulanır; ay kesirleri tam ay sayılır.\n'
        '• Faizle bulunacak tutar cezanın iki katını geçemez.\n\n'
        'Tutarı kuruşu kuruşuna görmek isterseniz Araçlar > "İndirim ve gecikme faizi" hesaplayıcısı bunu yapıyor.',
        yorum: 'Bence işin püf noktası süreyi kaçırmamak. Aylık %5 küçük görünüyor ama üst üste binince ceza iki katına kadar '
            'çıkabiliyor; beklemenin kimseye bir faydası yok.',
        maddeler: [m]);
  }

  // ---------------------------------------------------------------- yorum
  /// İhlalin konusuna göre asistanın kendi görüşü. Bilerek rakam ve hüküm içermez; onlar veriden gelir.
  static const _konuYorumlari = [
    ('alkol', 'Alkolde "az içtim" savunmasına hiç itibar etmem; içen direksiyona geçmesin, konu orada biter.'),
    ('kirmizi isik', 'Kırmızı ışık bence "bir şey olmaz" denilen ama sonucu en ağır olabilen ihlallerden; kavşakta yandan gelen aracı durduracak hiçbir şey yok.'),
    ('emniyet kemeri', 'Kemer benim gözümde tartışmaya en az değen konu: takması iki saniye, takmamanın bedeli ise ceza tutarıyla ölçülmüyor.'),
    ('telefon', 'Açıkçası telefona bakılan o birkaç saniyede araç onlarca metre kör gidiyor; ceza bence işin en hafif tarafı.'),
    ('surucu belgesi sahibi olmadan', 'Ehliyetsiz sürücüde ben yalnızca kullanana değil, aracı kimin verdiğine de bakarım; iş çoğu zaman orada başlıyor.'),
    ('hiz sinir', 'Hızda ceza kademesinden çok durma mesafesini düşünürüm; hız arttıkça mesafe hızın karesiyle uzuyor.'),
    ('koruma basligi', 'Kask, motosiklette kemerin karşılığı; takılmadığında en basit düşme bile ağır bitebiliyor.'),
    ('muayene', 'Muayenesiz araç bence kâğıt eksiği değil; freni, lastiği uzun süredir kimsenin kontrol etmediği araç demek.'),
    ('sigorta', 'Sigortasız araç kazaya karıştığında iş herkes için uzuyor ve zorlaşıyor; o yüzden bu kalemi hafife almam.'),
    ('yaya', 'Yaya konusunda benim ölçüm basit: tereddüt varsa dururum, yol veririm.'),
    ('mesafe', 'Takip mesafesi sahada en çok ihmal edilen kurallardan bence; arkadan çarpmalarda ilk baktığım şey bu olur.'),
    ('takograf', 'Takografta mesele kâğıt değil yorgunluk; dinlenmemiş sürücü bence yoldaki en büyük risklerden.'),
    ('park', 'Park ihlali küçük görünür ama görüşü kapattığı yerde kazaya davetiye; kavşak ve yaya geçidi yakınında daha sıkı bakarım.'),
  ];

  /// Bir ceza kalemi için yorum: konuya özel görüş ve kalemin kendi verisinden çıkan değerlendirmeler.
  String cezaYorumu(Ceza c) {
    final parcalar = <String>[];
    for (final (anahtar, gorus) in _konuYorumlari) {
      if (c.arama.contains(anahtar)) {
        parcalar.add(gorus);
        break;
      }
    }
    final veri = <String>[];
    if (c.belge.isNotEmpty || c.mahkeme.isNotEmpty) {
      veri.add('Para bir yana, bu kalemin sürücü belgesine uzanan bir yaptırımı da var; bence asıl caydırıcı olan o.');
    } else if (c.men.isNotEmpty || c.kullanmaktanMen.isNotEmpty) {
      veri.add('İş cezayla bitmiyor, men yaptırımı da var; yolda kalmak çoğu zaman paradan daha çok dokunuyor.');
    }
    if (c.puan != null && c.puan! > 0) {
      veri.add('${c.puan} puan tek başına az görünür, ama bir yıl içinde bu ihlalden ${(100 / c.puan!).ceil()} tane 100 puan sınırını dolduruyor.');
    }
    if (c.tutar != null) {
      final tutarlar = [for (final d in depo.cezalar) if (d.kanun == c.kanun && d.tutar != null) d.tutar!];
      final sira = tutarlar.where((t) => t < c.tutar!).length / tutarlar.length;
      if (sira >= 0.85) {
        veri.add('Tutar olarak da ${c.kanun} sayılı Kanun\'un en ağır cezaları arasında.');
      } else if (sira <= 0.25 && veri.isEmpty && c.kanun == '2918') {
        veri.add('Para olarak rehberin hafif kalemlerinden; yine de tekrarlandıkça can sıkar.');
      }
      if (c.kanun == '2918' && !c.kademeli) veri.add('İndirimli ödenirse aradaki fark ${para(c.tutar! - c.indirimli!)}.');
    }
    parcalar.addAll(veri.take(parcalar.isEmpty ? 3 : 2));
    if (c.kanun == '4925' && parcalar.length < 2) {
      parcalar.add('Taşıma tarafında işler genelde belge üzerinden yürüyor; ben olsam evrakı yola çıkmadan eksiksiz tutarım.');
    }
    return parcalar.join(' ');
  }

  /// Tek bir ceza kalemini gündelik bir girişle ve yorumla anlatır.
  Cevap _cezaCevabi(Ceza c, String q, {String? giris, String ekYorum = '', List<Ceza> digerleri = const [], List<Madde> maddeler = const []}) {
    final b = StringBuffer(giris ??
        _sec(q, ['Buna rehberde şu kalem karşılık geliyor:', 'Hemen söyleyeyim, karşılığı şu:', 'Baktım, durum şöyle:', 'Bunun cevabı net:']));
    b.write('\n\n${cezaOzeti(c)}');
    if (digerleri.isNotEmpty) b.write('\n\nSorunuzla ilgili olabilecek başka kalemler de buldum, aşağıya bıraktım.');
    return Cevap(b.toString(),
        yorum: [ekYorum, cezaYorumu(c)].where((s) => s.isNotEmpty).join(' '), cezalar: [c, ...digerleri], maddeler: maddeler);
  }

  // ---------------------------------------------------------------- niyetler
  Cevap? _maddeSorusu(String q) {
    final m = RegExp(r'(?:madde|md\.?|m\.)\s*(\d{1,3})((?:/[a-z0-9]+)?(?:-[a-z0-9]+)*)').firstMatch(q) ??
        RegExp(r'^(\d{1,3})((?:/[a-z0-9]+)?(?:-[a-z0-9]+)*)$').firstMatch(q) ??
        RegExp(r'\b(\d{1,3})(/[a-z0-9]+(?:-[a-z0-9]+)*)').firstMatch(q);
    if (m == null) return null;
    final kanun = q.contains('4925') || q.contains('tasima kanun') ? '4925' : '2918';
    final no = m.group(1)!;
    final alt = m.group(2) ?? '';
    final madde = depo.madde(kanun, no);
    final ilgili = depo.cezalar.where((c) => c.kanun == kanun && c.anaMadde == no).toList();
    if (madde == null && ilgili.isEmpty) return null;
    if (alt.isNotEmpty) {
      final tam = katla('$no$alt');
      final kalem = ilgili.where((c) => katla(c.madde).replaceAll(' ', '') == tam).toList();
      if (kalem.isNotEmpty) {
        return _cezaCevabi(kalem.first, q, digerleri: kalem.skip(1).toList(), maddeler: [?madde]);
      }
    }
    final b = StringBuffer('$kanun sayılı Kanun ${madde?.etiket ?? 'madde $no'}');
    if (madde != null && madde.baslik.isNotEmpty) b.write(' – ${madde.baslik}');
    if (madde != null) b.write('. Özetle şunu söylüyor:\n\n${_kisalt(madde.metin, 420)}');
    if (ilgili.isNotEmpty) b.write('\n\nBu maddeye bağlı ${ilgili.length} ceza kalemi var, aşağıda:');
    var yorum = 'Bence maddenin tamamını bir kez baştan sona okumak, kalemleri tek tek ezberlemekten daha çok işe yarıyor.';
    final tutarli = ilgili.where((c) => c.tutar != null).toList()..sort((a, b) => b.tutar!.compareTo(a.tutar!));
    if (tutarli.length > 1) {
      yorum = 'Bu maddenin kalemleri içinde en ağırı ${para(tutarli.first.tutar)} ile md. ${tutarli.first.madde}; ben önce ona bakardım. $yorum';
    }
    return Cevap(b.toString(), yorum: yorum, cezalar: ilgili.take(8).toList(), maddeler: [?madde]);
  }

  /// Hız aşımını durma mesafesi üzerinden yorumlar (kuru asfalt, 1 sn tepki süresi varsayımıyla).
  String _hizYorumu(int sinir, int olculen, Ceza? kalem) {
    double dur(int hiz) => durmaMesafesi(hizKmS: hiz.toDouble(), reaksiyonSn: 1, surtunme: 0.7).toplam;
    final b = StringBuffer('Benim gözümde asıl mesele ceza değil mesafe: kuru asfaltta $sinir km/s ile giden araç kabaca '
        '${dur(sinir).round()} metrede dururken, $olculen km/s ile giden ${dur(olculen).round()} metrede duruyor '
        '(1 saniye tepki süresiyle, yaklaşık hesap).');
    if (kalem == null) {
      b.write(' Ceza çıkmıyor diye bunu serbest pay gibi düşünmem; sınır yine de aşılmış.');
    } else if (kalem.belge.isNotEmpty || kalem.mahkeme.isNotEmpty) {
      b.write(' Bu kademede iş paradan çıkıp sürücü belgesine uzanıyor; bence asıl caydırıcı olan o.');
    }
    return b.toString();
  }

  Cevap? _hizSorusu(String q) {
    final ilgili = RegExp(r'\bhiz|radar|km\b|km/s|kmh|surat|\bsinir|limit|\bgid').hasMatch(q);
    if (!ilgili) return null;
    final sayilar = RegExp(r'\b(\d{2,3})\b')
        .allMatches(q)
        .map((m) => int.parse(m.group(1)!))
        .where((n) => n >= 10 && n <= 300)
        .toList();
    final disi = RegExp(r'disi|otoyol|sehirlerarasi|bolunmus|otoban|cift yon').hasMatch(q);
    // Soruda araç sınıfı geçiyorsa yasal sınır tablodan bulunur ("otoyolda kamyon 110 ile giderse").
    final yol = RegExp(r'otoyol|otoban').hasMatch(q)
        ? 3
        : (q.contains('bolunmus') ? 2 : (RegExp(r'sehirlerarasi|cift yon|yerlesim (yeri )?disi').hasMatch(q) ? 1 : 0));
    Map<String, dynamic>? arac;
    for (final a in depo.hizAraclari) {
      final anahtar = a['anahtar'] as String? ?? '';
      // En uzun eşleşen ad kazanır: "kamyonet" sorusu "kamyon" satırına düşmesin.
      if (anahtar.isNotEmpty && q.contains(anahtar) && anahtar.length > ((arac?['anahtar'] as String?)?.length ?? 0)) arac = a;
    }
    if (arac != null && sayilar.length <= 1) {
      final sinir = depo.yasalHizSiniri(arac, yol);
      final yolAdi = depo.hizYollari[yol];
      if (sinir == null) {
        return Cevap('${arac['ad']} sınıfı araçlar ${yolAdi.toLowerCase()} kesimine giremez; yani orada hız sınırından önce '
            'aracın o yolda ne aradığı sorulur.');
      }
      if (sayilar.isEmpty) {
        final s = arac['sinirlar'] as List<dynamic>;
        final b = StringBuffer('${arac['ad']} için yasal hız sınırları şöyle:\n');
        for (var i = 0; i < s.length; i++) {
          b.write('\n• ${depo.hizYollari[i]}: ${s[i] == null ? 'giremez' : '${s[i]} km/s'}');
        }
        if ((arac['aciklama'] as String? ?? '').isNotEmpty) b.write('\n\n${arac['aciklama']}');
        b.write('\n\nKaynak: ${depo.hizSinirlari['kaynak']}');
        return Cevap(b.toString(),
            yorum: 'Bunlar levha olmayan yerler için geçerli üst sınırlar. Yolda levha varsa ben her zaman levhaya bakarım; '
                'bir de sınır "bu hızla gidilir" demek değil, yağışta ve siste daha aşağısı gerekir.');
      }
      final s = hizHesapla(depo.cezalar, yerlesimIci: yol == 0, sinir: sinir, olculen: sayilar.single);
      final giris = 'Hesapladım. ${arac['ad']}, $yolAdi: yasal sınır $sinir km/s, ölçülen hız ${sayilar.single} km/s, aşım ${s.asim} km/s.';
      if (s.asim <= 0) return Cevap('$giris\n\nHız sınırı aşılmamış, işlem gerektiren bir durum yok.');
      if (s.kalem == null) {
        return Cevap('$giris\n\nBu aşım ceza kademelerinin alt eşiğinin altında kalıyor, yani ceza çıkmıyor.',
            yorum: _hizYorumu(sinir, sayilar.single, null));
      }
      return Cevap('$giris\n\n${cezaOzeti(s.kalem!)}', yorum: _hizYorumu(sinir, sayilar.single, s.kalem), cezalar: [s.kalem!]);
    }
    if (sayilar.length >= 2) {
      final sinir = sayilar.reduce(math.min);
      final olculen = sayilar.reduce(math.max);
      final s = hizHesapla(depo.cezalar, yerlesimIci: !disi, sinir: sinir, olculen: olculen);
      final yer = disi ? 'yerleşim yeri dışında' : 'yerleşim yeri içinde';
      if (s.kalem == null) {
        return Cevap(
            'Hesapladım. Hız sınırı $sinir km/s, ölçülen hız $olculen km/s: aşım ${s.asim} km/s. '
            'Bu aşım $yer ceza kademelerinin alt eşiğinin altında kalıyor, yani ceza çıkmıyor.\n\n'
            'Not: Soruda "yerleşim dışı / otoyol" geçmediği için yerleşim yeri içi kabul ettim.',
            yorum: _hizYorumu(sinir, olculen, null));
      }
      return Cevap(
          'Hesapladım. Hız sınırı $sinir km/s, ölçülen hız $olculen km/s: aşım ${s.asim} km/s ($yer).\n\n${cezaOzeti(s.kalem!)}',
          yorum: _hizYorumu(sinir, olculen, s.kalem),
          cezalar: [s.kalem!]);
    }
    if (!RegExp(r'\bhiz|radar|surat').hasMatch(q)) return null;
    final kademeler = depo.cezalar.where((c) => c.id.startsWith(disi ? '51-2-b-' : '51-2-a-')).toList();
    final tutarlar = [for (final c in kademeler) ?c.tutar]..sort();
    final b = StringBuffer('Hız ihlalinde ceza, sınırın ne kadar aşıldığına göre kademe kademe artıyor '
        '(${disi ? 'yerleşim yeri dışı' : 'yerleşim yeri içi'}):\n');
    for (final c in kademeler) {
      final a = RegExp(r"(\d+\s*-\s*\d+|\d+)\s*km/s[^,]*").firstMatch(c.konu)?.group(0) ?? c.konu;
      b.write('\n• $a: ${para(c.tutar)}${c.belge.isEmpty ? '' : ' + belge ${c.belge}'}');
    }
    b.write('\n\nHız sınırını ve ölçülen hızı birlikte yazarsanız (ör. "50 sınırında 82") tam kademeyi ben bulurum.');
    return Cevap(b.toString(),
        yorum: tutarlar.length < 2
            ? ''
            : 'Dikkat ederseniz en üst kademe en alttakinin yaklaşık ${(tutarlar.last / tutarlar.first).round()} katı. '
                'Bence bu tablo şunu söylüyor: birkaç kilometrelik aşım hata sayılıyor, büyük aşım ise bilinçli tercih.',
        cezalar: kademeler);
  }

  Cevap? _alkolSorusu(String q) {
    if (!RegExp(r'promil|alkol|icki|sarhos').hasMatch(q)) return null;
    final kalem = depo.ceza('2918:48-5');
    if (kalem == null) return null;
    final red = RegExp(r'ufleme|reddet|yaptirma|kabul etme').hasMatch(q);
    if (red) {
      final r = depo.ceza('2918:48-9');
      if (r != null) {
        final kat = r.tutar != null && kalem.tutar != null && r.tutar! > kalem.tutar!
            ? 'Açıkçası ölçümü reddetmek kimseyi kurtarmıyor: cezası, alkollü araç kullanmanın ilk cezasının yaklaşık '
                '${(r.tutar! / kalem.tutar!).round()} katı.'
            : '';
        return _cezaCevabi(r, q, giris: 'Ölçüm yaptırmayan sürücü için ayrı bir kalem var:', ekYorum: kat);
      }
    }
    final m = RegExp(r'(\d)[.,](\d{1,2})').firstMatch(q);
    final ticari = RegExp(r'ticari|kamyon|otobus|taksi|minibus|motosiklet|cekici|servis').hasMatch(q);
    if (m != null) {
      final promil = double.parse('${m.group(1)}.${m.group(2)}');
      final kacinci = RegExp(r'ikinci|2\.').hasMatch(q) ? 2 : (RegExp(r'ucuncu|3\.').hasMatch(q) ? 3 : 1);
      final s = alkolHesapla(kalem, hususiOtomobil: !ticari, promil: promil, kacinci: kacinci);
      final tur = ticari ? 'hususi otomobil dışındaki araç' : 'hususi otomobil';
      if (!s.ihlal) {
        return Cevap('${promil.toStringAsFixed(2)} promil, $tur için sınır olan '
            '${s.sinir.toStringAsFixed(2)} promilin üzerinde değil; md. 48/5 kapsamında idari para cezası uygulanmaz.',
            yorum: 'Ceza çıkmıyor, ama sınırın altında kalmak bence "güvenli" demek değil. Ben olsam içtiysem hiç kullanmam.',
            cezalar: [kalem]);
      }
      final b = StringBuffer('Burada ihlal var. ${promil.toStringAsFixed(2)} promil, $tur için sınırın '
          '(${s.sinir.toStringAsFixed(2)}) üzerinde.\n\n$kacinci. ihlal için ceza: ${para(s.tutar)}');
      if (s.tutar != null) b.write(' (indirimli ${para(s.tutar! * 0.75)})');
      b.write('\nSürücü belgesi: ${kalem.belge}');
      if (s.tckUygulanir) b.write('\n\n1,00 promilin üzerinde olduğundan ayrıca TCK md. 179 kapsamında işlem yapılır.');
      return Cevap(b.toString(),
          yorum: '${_konuYorumlari.first.$2} Parayı bir şekilde ödersiniz, ama bence asıl can yakan belgenin gitmesi.'
              '${s.tckUygulanir ? ' Bir promilin üstünde iş idari cezayla da kapanmıyor, adli tarafa geçiyor; o ayrı bir dert.' : ''}',
          cezalar: [kalem]);
    }
    return _cezaCevabi(kalem, q, giris: 'Alkolde temel kalem şu:', digerleri: [?depo.ceza('2918:48-9'), ?depo.ceza('2918:48-8')]);
  }

  Cevap? _puanSorusu(String q) {
    if (!(q.contains('100 puan') || (q.contains('puan') && RegExp(r'dol|asim|asar|toplam|sinir').hasMatch(q)))) {
      return null;
    }
    final k = depo.ceza('2918:118');
    if (k == null) return null;
    final enYuksek = depo.cezalar.map((c) => c.puan ?? 0).fold(0, math.max);
    return Cevap(
        'Kısaca: geriye doğru bir yıl içinde 100 ceza puanını dolduran sürücünün belgesi geri alınır.\n\n'
        '• Trafik kolluğunca: ${k.belge}\n• Mahkemece: ${k.mahkeme}\n\n${_kisalt(k.diger, 500)}',
        yorum: enYuksek == 0
            ? ''
            : '100 puan uzak gibi durur ama değil: en yüksek puanlı ihlaller $enYuksek puan, yani bunlardan '
                '${(100 / enYuksek).ceil()} tanesi bir yılda sınırı dolduruyor. Bence puanını takip etmeyen sürücü bunu ancak belgesi gidince fark ediyor.',
        cezalar: [k]);
  }

  Cevap? _kusurSorusu(String q) {
    if (!RegExp(r'kusur|kaza|carp|sucl|hakli|haksiz').hasMatch(q)) return null;
    final sirali = _sirala<Map<String, dynamic>>(
        depo.kazalar,
        q,
        (k) => katla('${k['baslik']} ${k['anlatim']} ${k['asliKusur']} '
            '${(k['taraflar'] as List<dynamic>).map((t) => '${t['durum']} ${t['gerekce']}').join(' ')}'),
        baslik: (k) => katla(k['baslik'] as String));
    if (sirali.isEmpty || sirali.first.$2 < 2.2) {
      if (q.contains('asli kusur')) {
        final m = depo.madde('2918', '84');
        if (m != null) return Cevap('Asli kusur sayılan haller (md. 84):\n\n${m.metin}', maddeler: [m]);
      }
      return null;
    }
    final k = sirali.first.$1;
    final b = StringBuffer('Anlattığınıza en çok benzeyen örnek şu: ${k['baslik']}\n\n${k['anlatim']}\n');
    for (final t in (k['taraflar'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      b.write('\n• ${t['ad']}: ${t['durum']} – ${t['gerekce']}');
    }
    b.write('\n\nDayanak: ${k['asliKusur']}');
    final ihlaller = [for (final id in (k['ihlaller'] as List<dynamic>)) ?depo.ceza('2918:$id')];
    return Cevap(b.toString(),
        yorum: 'Benim okumam: bu tür kazada tabloyu belirleyen yukarıdaki kural. Ama bu bir eğitim örneği; sahada her kaza kendine özgü. '
            'İz, hasar yeri, tanık anlatımı ve kamera kaydı kusur dağılımını değiştirebilir, o yüzden örneği birebir şablon gibi kullanmam.',
        cezalar: ihlaller, maddeler: [?depo.madde('2918', '84')], kazalar: sirali.take(3).map((e) => e.$1).toList());
  }

  Cevap _genel(String q) {
    // Soruda kanun numarası geçiyorsa arama o kanunla sınırlanır.
    final kanun = q.contains('4925') ? '4925' : (q.contains('2918') ? '2918' : null);
    final cezalar = _sirala<Ceza>(depo.cezalar.where((c) => kanun == null || c.kanun == kanun).toList(), q, (c) => c.arama);
    final maddeler = _sirala<Madde>(
        depo.maddeler.where((m) => kanun == null || m.kanun == kanun).toList(), q, (m) => m.arama,
        baslik: (m) => katla(m.baslik));
    final enIyiCeza = cezalar.isEmpty ? 0.0 : cezalar.first.$2;
    final enIyiMadde = maddeler.isEmpty ? 0.0 : maddeler.first.$2;
    if (enIyiCeza < 1.8 && enIyiMadde < 1.8) {
      return Cevap('Açık konuşayım, buna elimdeki mevzuat verisiyle güvenilir bir cevap bulamadım; uydurmak da istemem. '
          'Soruyu ihlalin adıyla (ör. "emniyet kemeri", "kırmızı ışık", "muayenesiz araç") veya '
          'madde numarasıyla (ör. "madde 47") yazarsanız bir daha bakayım.');
    }
    // Sahada asıl aranan ceza kalemidir; kanun maddesi yalnızca belirgin biçimde daha iyi eşleşirse öne geçer.
    if (enIyiCeza >= 1.8 && enIyiCeza >= enIyiMadde * 0.4) {
      final ilk = cezalar.first.$1;
      final digerleri = cezalar.skip(1).where((e) => e.$2 >= enIyiCeza * 0.55).take(5).map((e) => e.$1).toList();
      return _cezaCevabi(ilk, q, digerleri: digerleri, maddeler: [?depo.madde(ilk.kanun, ilk.anaMadde)]);
    }
    final m = maddeler.first.$1;
    return Cevap(
        'Buna doğrudan bir ceza kalemi çıkmadı, ama kanunda en yakın yer şurası: ${m.kanun} sayılı Kanun ${m.etiket}'
        '${m.baslik.isEmpty ? '' : ' – ${m.baslik}'}\n\n${_kisalt(m.metin, 600)}',
        yorum: 'Ben burada metnin kendisine güvenirim; soruyu ihlalin adıyla yazarsanız ceza kalemini de bulup üstüne ne düşündüğümü söylerim.',
        maddeler: maddeler.take(3).map((e) => e.$1).toList(),
        cezalar: cezalar.where((e) => e.$2 >= 1.8).take(3).map((e) => e.$1).toList());
  }

  // ---------------------------------------------------------------- yardımcılar
  /// Türkçe ekleri kabaca atar: "çarpan", "çarpma", "çarpmış" aynı köke ("carp") iner.
  static String _kok(String k) => k.length >= 7 ? k.substring(0, 5) : (k.length >= 5 ? k.substring(0, 4) : k);

  static Set<String> _kokler(String metin, {bool etkisizleriAt = true}) => {
        for (final k in metin.split(RegExp(r'[^a-z0-9]+')))
          if (k.length >= 3 && !(etkisizleriAt && _etkisiz.contains(k))) _kok(k),
      };

  /// Belgeleri soruyla eşleşme gücüne göre sıralar: nadir geçen kelimeler daha ağır basar.
  /// Sorudaki anlamlı kelimelerin en az yarısını karşılamayan belge hiç dönmez; böylece
  /// konu dışı sorularda tek bir tesadüfi kelime yüzünden cevap uydurulmaz.
  List<(T, double)> _sirala<T>(List<T> belgeler, String q, String Function(T) metin, {String Function(T)? baslik}) {
    final asil = _kokler(q);
    if (asil.isEmpty) return [];
    // Eş anlamlısı bulunan günlük kelimeler, mevzuattaki karşılığı eşleştiğinde karşılanmış sayılır.
    final ek = <String>{};
    final esAnlamli = <String>{};
    final kaliplar = <String>[];
    _esAnlam.forEach((k, v) {
      if (RegExp('\\b$k').hasMatch(q)) {
        // Mevzuat karşılığı bilinçli seçildiği için içindeki genel kelimeler de eşleşmeye katılır.
        ek.addAll(_kokler(v, etkisizleriAt: false));
        kaliplar.add(v);
        esAnlamli.addAll(asil.where((a) => k.split(' ').any((p) => a.startsWith(_kok(p)) || _kok(p).startsWith(a))));
      }
    });
    final metinler = [for (final b in belgeler) ' ${metin(b)}'];
    final agirlik = <String, double>{};
    for (final k in {...asil, ...ek}) {
      final df = metinler.where((m) => m.contains(' $k')).length;
      if (df > 0) agirlik[k] = math.log(belgeler.length / df) + 1;
    }
    final sonuc = <(T, double)>[];
    for (var i = 0; i < belgeler.length; i++) {
      var puan = 0.0;
      final eslesen = <String>{};
      agirlik.forEach((k, a) {
        if (metinler[i].contains(' $k')) {
          puan += a;
          eslesen.add(k);
          if (baslik != null && ' ${baslik(belgeler[i])}'.contains(' $k')) puan += a;
        }
      });
      if (eslesen.isEmpty) continue;
      final ekEslesti = eslesen.any(ek.contains);
      final karsilanan = asil.where((a) => eslesen.contains(a) || (ekEslesti && esAnlamli.contains(a))).length;
      final kapsama = karsilanan / asil.length;
      // Bilinen bir trafik terimi (eş anlamlı sözlüğünden) tutmuşsa, sorudaki günlük dolgu kelimeleri hoş görülür.
      final alanTerimi = ekEslesti && esAnlamli.isNotEmpty;
      if (alanTerimi ? kapsama < 0.3 : (asil.length == 1 ? kapsama < 1 : kapsama <= 0.5)) continue;
      puan *= 0.5 + 0.5 * kapsama;
      if (q.length > 5 && metinler[i].contains(q)) puan += 6;
      if (kaliplar.any(metinler[i].contains)) puan += 4;
      // Eşit eşleşmede kısa ve öz belge, aynı kelimeleri tesadüfen içeren uzun belgenin önüne geçsin.
      puan -= metinler[i].length * 0.0008;
      sonuc.add((belgeler[i], puan));
    }
    sonuc.sort((a, b) => b.$2.compareTo(a.$2));
    return sonuc;
  }
  static String _kisalt(String s, int uzunluk) => s.length <= uzunluk ? s : '${s.substring(0, uzunluk).trimRight()}…';

  static String cezaOzeti(Ceza c) {
    final b = StringBuffer('${c.kanun} sayılı Kanun md. ${c.madde}\n${c.konu}\n');
    if (c.kademeli) {
      b.write('\nCeza (kademeli):\n${c.cezaMetin}');
    } else if (c.tutar != null) {
      b.write('\n• Ceza: ${para(c.tutar)}');
      if (c.kanun == '2918') b.write(' (%25 indirimli ${para(c.indirimli)})');
      if (c.ustSinir != null) b.write('\n• Alt/üst sınır: ${para(c.altSinir)} – ${para(c.ustSinir)}');
    }
    if (c.mulkiAmir.isNotEmpty) b.write('\n• Mülki amirce: ${c.mulkiAmir}');
    if (c.puan != null) b.write('\n• Ceza puanı: ${c.puan}');
    if (c.kime.isNotEmpty) b.write('\n• Kime: ${c.kime}');
    if (c.belge.isNotEmpty) b.write('\n• Sürücü belgesi: ${c.belge}');
    if (c.mahkeme.isNotEmpty) b.write('\n• Mahkemece: ${c.mahkeme}');
    if (c.men.isNotEmpty) b.write('\n• Trafikten men: ${c.men}');
    if (c.kullanmaktanMen.isNotEmpty) b.write('\n• Araç kullanmaktan men: ${c.kullanmaktanMen}');
    return b.toString();
  }
}
