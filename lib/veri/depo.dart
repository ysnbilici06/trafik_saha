import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ayarlar.dart';
import 'haberler.dart';
import 'hava.dart';
import 'modeller.dart';

/// Uygulamanın tüm verisini (mevzuat, cezalar, içerik) ve kullanıcıya özel durumu
/// (profil, sık kullanılanlar, notlar, quiz ilerlemesi) tutar. Her şey cihazda saklanır.
class Depo extends ChangeNotifier {
  Depo._();
  static final Depo i = Depo._();

  late SharedPreferences _prefs;

  List<Ceza> cezalar = [];
  List<Madde> maddeler = [];

  /// Mevzuat kitaplığının dizini (kitaplik.json): her metnin kodu, adı, türü, Resmî Gazete künyesi,
  /// kaynağı ve dosyası. Metinlerin kendisi [mevzuatMaddeleri] ile ilk istendiğinde yüklenir.
  List<Map<String, dynamic>> kitaplik = [];
  final _kitaplikMaddeleri = <String, Future<List<Madde>>>{};
  /// Araç sınıfı ve yol türüne göre yasal hız sınırları: {'yollar': [...], 'araclar': [{'ad', 'sinirlar'}]}.
  Map<String, dynamic> hizSinirlari = {};

  List<String> get hizYollari => ((hizSinirlari['yollar'] as List<dynamic>?) ?? []).cast<String>();
  List<Map<String, dynamic>> get hizAraclari =>
      ((hizSinirlari['araclar'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();

  /// Yasal sınır (km/s); araç o yola giremiyorsa null.
  int? yasalHizSiniri(Map<String, dynamic> arac, int yol, {bool otoyolUstSinir = false}) {
    if (otoyolUstSinir && yol == 3 && arac['otoyolUst'] != null) return arac['otoyolUst'] as int;
    return (arac['sinirlar'] as List<dynamic>)[yol] as int?;
  }

  List<Map<String, dynamic>> sorular = [];
  List<Map<String, dynamic>> kazalar = [];
  List<Map<String, dynamic>> kararlar = [];
  List<Map<String, dynamic>> listeler = [];
  List<Map<String, dynamic>> duyurular = [];
  Map<String, dynamic> surum = {};

  /// Kullanıcıya özel, kalıcı durum.
  Map<String, dynamic> durum = {};

  bool guncelleniyor = false;

  Future<void> baslat() async {
    _prefs = await SharedPreferences.getInstance();
    final ham = _prefs.getString('durum');
    durum = ham == null ? {} : jsonDecode(ham) as Map<String, dynamic>;
    _havaOnbellektenYukle();
    await _veriYukle();
  }

  Future<String> _dosya(String ad) async =>
      _prefs.getString('veri:$ad') ?? await rootBundle.loadString('assets/veri/$ad');

  Future<void> _veriYukle() async {
    List<dynamic> liste(String s) => jsonDecode(s) as List<dynamic>;
    List<Map<String, dynamic>> haritalar(dynamic l) =>
        (l as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    cezalar = [
      for (final j in liste(await _dosya('cezalar_2918.json'))) Ceza('2918', j as Map<String, dynamic>),
      for (final j in liste(await _dosya('cezalar_4925.json'))) Ceza('4925', j as Map<String, dynamic>),
    ];
    maddeler = [
      for (final j in liste(await _dosya('mevzuat_2918.json'))) Madde('2918', j as Map<String, dynamic>),
      for (final j in liste(await _dosya('mevzuat_4925.json'))) Madde('4925', j as Map<String, dynamic>),
    ];
    kitaplik = haritalar(liste(await _dosya('kitaplik.json')));
    _kitaplikMaddeleri.clear();
    final icerik = jsonDecode(await _dosya('icerik.json')) as Map<String, dynamic>;
    hizSinirlari = (icerik['hizSinirlari'] as Map<String, dynamic>?) ?? {};
    sorular = haritalar(icerik['quiz']);
    kazalar = haritalar(icerik['kazalar']);
    kararlar = haritalar(icerik['kararlar']);
    listeler = haritalar(icerik['listeler']);
    duyurular = haritalar(liste(await _dosya('duyurular.json')));
    final onbellek = _prefs.getString('haberOnbellek');
    haberler = haberleriSinirla(haberleriBirlestir(
      haritalar(liste(await _dosya('haberler.json'))),
      onbellek == null ? [] : haritalar(jsonDecode(onbellek)),
    ));
    final yerelSurum = _prefs.getString('veri:surum.json') ?? await rootBundle.loadString('assets/veri/surum.json');
    surum = jsonDecode(yerelSurum) as Map<String, dynamic>;
    _cezaDizini = {for (final c in cezalar) c.anahtar: c};
  }

  Map<String, Ceza> _cezaDizini = {};

  Ceza? ceza(String anahtar) => _cezaDizini[anahtar];

  /// Güncellenmiş kitaplık metinleri tarayıcının küçük ayar alanına sığmadığı için ayrı bir kutuda tutulur;
  /// hangi dosyaların orada olduğu 'kitaplikGuncel' listesinde yazılıdır.
  Future<Box<String>> _kitaplikKutusu() async {
    await Hive.initFlutter();
    return Hive.openBox<String>('kitaplik_verisi');
  }

  /// [kod]lu mevzuatın maddeleri; 2918 ve 4925 açılışta yüklü olduğundan doğrudan verilir.
  Future<List<Madde>> mevzuatMaddeleri(String kod) => _kitaplikMaddeleri[kod] ??= () async {
        if (kod == '2918' || kod == '4925') return maddeler.where((m) => m.kanun == kod).toList();
        final ad = 'mevzuat_$kod.json';
        try {
          final guncel = (_prefs.getStringList('kitaplikGuncel') ?? const []).contains(ad);
          final ham = (guncel ? (await _kitaplikKutusu()).get(ad) : null) ?? await rootBundle.loadString('assets/veri/$ad');
          return [for (final j in jsonDecode(ham) as List<dynamic>) Madde(kod, j as Map<String, dynamic>)];
        } catch (_) {
          return <Madde>[];
        }
      }();

  /// Kitaplıktaki bütün metinleri yükler; tüm mevzuatta arama bunu bekler.
  Future<Map<String, List<Madde>>> kitaplikYukle() async =>
      {for (final k in kitaplik) k['kod'] as String: await mevzuatMaddeleri(k['kod'] as String)};

  Map<String, dynamic>? mevzuatBilgisi(String kod) {
    for (final k in kitaplik) {
      if (k['kod'] == kod) return k;
    }
    return null;
  }

  /// Mevzuatın tam adı; dizinde yoksa kanun numarası olarak yazılır.
  String mevzuatAdi(String kod) => mevzuatBilgisi(kod)?['ad'] as String? ?? '$kod sayılı Kanun';

  Madde? madde(String kanun, String no) {
    for (final m in maddeler) {
      if (m.kanun == kanun && m.no == no) return m;
    }
    return null;
  }

  DateTime? get veriTarihi => DateTime.tryParse(surum['guncelleme'] as String? ?? '')?.toLocal();
  DateTime? get sonKontrol => DateTime.tryParse(durum['sonKontrol'] as String? ?? '')?.toLocal();

  /// Yayımlanan veriyi denetler; değişen dosyaları indirir, özetini doğrular ve kaydeder.
  /// Kullanıcıya gösterilecek sonucu döndürür.
  Future<String> guncelle() async {
    if (veriAdresi.isEmpty) {
      return 'Otomatik güncelleme adresi henüz tanımlanmadı. Kurulumla gelen veri kullanılıyor.';
    }
    if (guncelleniyor) return 'Güncelleme sürüyor…';
    guncelleniyor = true;
    notifyListeners();
    try {
      final damga = DateTime.now().millisecondsSinceEpoch;
      final yanit = await http.get(Uri.parse('$veriAdresi/surum.json?t=$damga')).timeout(const Duration(seconds: 20));
      if (yanit.statusCode != 200) return 'Sunucuya ulaşılamadı (${yanit.statusCode}).';
      final yeniSurum = jsonDecode(utf8.decode(yanit.bodyBytes)) as Map<String, dynamic>;
      final yeniDosyalar = yeniSurum['dosyalar'] as Map<String, dynamic>;
      final eskiDosyalar = surum['dosyalar'] as Map<String, dynamic>? ?? {};
      final indirilen = <String, String>{};
      for (final ad in veriDosyalari) {
        final ozet = (yeniDosyalar[ad] as Map<String, dynamic>?)?['sha256'] as String?;
        if (ozet == null || ozet == (eskiDosyalar[ad] as Map<String, dynamic>?)?['sha256']) continue;
        final d = await http.get(Uri.parse('$veriAdresi/$ad?t=$damga')).timeout(const Duration(seconds: 40));
        if (d.statusCode != 200 || sha256.convert(d.bodyBytes).toString() != ozet) {
          return 'İndirilen veri doğrulanamadı ($ad). Mevcut veri korunuyor.';
        }
        indirilen[ad] = utf8.decode(d.bodyBytes);
      }
      // Kitaplık metinleri: dizindeki (yeni dizin indiyse ondaki) her dosya için aynı denetim.
      final dizin = jsonDecode(indirilen['kitaplik.json'] ?? await _dosya('kitaplik.json')) as List<dynamic>;
      final kitaplikIndirilen = <String, String>{};
      for (final k in dizin) {
        final ad = (k as Map<String, dynamic>)['dosya'] as String;
        if (veriDosyalari.contains(ad)) continue;
        final ozet = (yeniDosyalar[ad] as Map<String, dynamic>?)?['sha256'] as String?;
        if (ozet == null || ozet == (eskiDosyalar[ad] as Map<String, dynamic>?)?['sha256']) continue;
        final d = await http.get(Uri.parse('$veriAdresi/$ad?t=$damga')).timeout(const Duration(seconds: 60));
        if (d.statusCode != 200 || sha256.convert(d.bodyBytes).toString() != ozet) {
          return 'İndirilen veri doğrulanamadı ($ad). Mevcut veri korunuyor.';
        }
        kitaplikIndirilen[ad] = utf8.decode(d.bodyBytes);
      }
      durum['sonKontrol'] = DateTime.now().toUtc().toIso8601String();
      if (indirilen.isEmpty && kitaplikIndirilen.isEmpty) {
        await _durumKaydet();
        return 'Veriler güncel.';
      }
      if (kitaplikIndirilen.isNotEmpty) {
        await (await _kitaplikKutusu()).putAll(kitaplikIndirilen);
        await _prefs.setStringList('kitaplikGuncel', {...?_prefs.getStringList('kitaplikGuncel'), ...kitaplikIndirilen.keys}.toList());
      }
      indirilen.addAll(kitaplikIndirilen.map((ad, _) => MapEntry(ad, '')));
      for (final e in indirilen.entries) {
        if (kitaplikIndirilen.containsKey(e.key)) continue;
        await _prefs.setString('veri:${e.key}', e.value);
      }
      await _prefs.setString('veri:surum.json', jsonEncode(yeniSurum));
      await _veriYukle();
      await _durumKaydet();
      return '${indirilen.length} veri dosyası güncellendi.';
    } catch (_) {
      return 'Güncelleme denetlenemedi. İnternet bağlantınızı kontrol edin.';
    } finally {
      guncelleniyor = false;
      notifyListeners();
    }
  }

  Future<void> _durumKaydet() async {
    await _prefs.setString('durum', jsonEncode(durum));
    notifyListeners();
  }

  // ---------------------------------------------------------------- profil
  Map<String, dynamic> get profil => (durum['profil'] as Map<String, dynamic>?) ?? {};
  bool get profilVar => (profil['ad'] as String? ?? '').isNotEmpty;

  Future<void> profilKaydet(String ad, String gorev, String birim) {
    durum['profil'] = {'ad': ad.trim(), 'gorev': gorev.trim(), 'birim': birim.trim()};
    durum['karsilandi'] = true;
    return _durumKaydet();
  }

  bool get karsilandi => durum['karsilandi'] == true;

  Future<void> karsilamayiGec() {
    durum['karsilandi'] = true;
    return _durumKaydet();
  }

  // ---------------------------------------------------------------- sık kullanılanlar / geçmiş
  List<String> _dizi(String ad) => ((durum[ad] as List<dynamic>?) ?? []).cast<String>();

  List<String> get favoriler => _dizi('favoriler');
  List<String> get sonBakilanlar => _dizi('sonBakilanlar');
  List<String> get yerImleri => _dizi('yerImleri');

  bool favoriMi(String anahtar) => favoriler.contains(anahtar);

  Future<void> _degistir(String ad, String deger) {
    final l = _dizi(ad).toList();
    l.contains(deger) ? l.remove(deger) : l.insert(0, deger);
    durum[ad] = l;
    return _durumKaydet();
  }

  Future<void> favoriDegistir(String anahtar) => _degistir('favoriler', anahtar);
  Future<void> yerImiDegistir(String anahtar) => _degistir('yerImleri', anahtar);

  Future<void> bakildi(String anahtar) {
    final l = sonBakilanlar.toList()
      ..remove(anahtar)
      ..insert(0, anahtar);
    durum['sonBakilanlar'] = l.take(12).toList();
    return _durumKaydet();
  }

  // ---------------------------------------------------------------- notlar
  List<Map<String, dynamic>> get notlar => ((durum['notlar'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();

  Future<void> notKaydet(String? id, String baslik, String metin) {
    final l = notlar.toList();
    final simdi = DateTime.now().toIso8601String();
    final i = l.indexWhere((n) => n['id'] == id);
    if (i >= 0) {
      l[i] = {...l[i], 'baslik': baslik, 'metin': metin, 'tarih': simdi};
    } else {
      l.insert(0, {'id': simdi, 'baslik': baslik, 'metin': metin, 'tarih': simdi});
    }
    durum['notlar'] = l;
    return _durumKaydet();
  }

  Future<void> notSil(String id) {
    durum['notlar'] = notlar.where((n) => n['id'] != id).toList();
    return _durumKaydet();
  }

  // ---------------------------------------------------------------- işlem kayıtları
  /// Kullanıcının sahada uyguladığı işlemler, en yeni başta. Madde, konu ve tutar kayıt anındaki
  /// hâliyle saklanır; sonradan gelen veri güncellemesi geçmiş kayıtları değiştirmez.
  List<Map<String, dynamic>> get islemler => ((durum['islemler'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();

  Future<void> islemEkle(Ceza c, {String plaka = '', String aciklama = '', DateTime? zaman}) {
    final t = (zaman ?? DateTime.now()).toIso8601String();
    durum['islemler'] = [
      {
        'id': '$t-${c.anahtar}',
        'tarih': t,
        'anahtar': c.anahtar,
        'kanun': c.kanun,
        'madde': c.madde,
        'konu': c.konu,
        'tutar': c.tutar,
        'plaka': plaka.trim().toUpperCase(),
        'aciklama': aciklama.trim(),
      },
      ...islemler,
    ];
    return _durumKaydet();
  }

  Future<void> islemSil(String id) {
    durum['islemler'] = islemler.where((i) => i['id'] != id).toList();
    return _durumKaydet();
  }

  // ---------------------------------------------------------------- kaza kayıtları
  List<Map<String, dynamic>> get kazaKayitlari =>
      ((durum['kazaKayitlari'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();

  /// [kayit] içinde 'id' varsa günceller, yoksa yeni kayıt olarak başa ekler.
  Future<void> kazaKaydet(Map<String, dynamic> kayit) {
    final l = kazaKayitlari.toList();
    final i = l.indexWhere((k) => k['id'] == kayit['id']);
    if (i >= 0) {
      l[i] = kayit;
    } else {
      l.insert(0, {...kayit, 'id': DateTime.now().toIso8601String()});
    }
    durum['kazaKayitlari'] = l;
    return _durumKaydet();
  }

  Future<void> kazaKaydiSil(String id) {
    durum['kazaKayitlari'] = kazaKayitlari.where((k) => k['id'] != id).toList();
    return _durumKaydet();
  }

  // ---------------------------------------------------------------- hava durumu
  /// Hava durumu için seçilen yer: {'ad', 'enlem', 'boylam'}.
  Map<String, dynamic>? get havaYeri => durum['havaYeri'] as Map<String, dynamic>?;

  Hava? hava;
  bool havaYukleniyor = false;
  String? havaHatasi;

  DateTime? get havaZamani => DateTime.tryParse(durum['havaZamani'] as String? ?? '');

  void _havaOnbellektenYukle() {
    final ham = durum['hava'] as Map<String, dynamic>?;
    if (ham == null) return;
    try {
      hava = Hava.fromJson(ham);
    } catch (_) {
      hava = null;
    }
  }

  /// Yeni yer seçildi ama koordinatı henüz bulunmadıysa seçilen ad; kart bunu hemen gösterir.
  String? havaYeriBekleyen;

  /// Her indirme isteğinin sırası; yer değişince eski isteğin geç gelen yanıtı yok sayılır.
  int _havaIstegi = 0;

  void havaYeriSeciliyor(String? ad) {
    havaYeriBekleyen = ad;
    notifyListeners();
  }

  Future<void> havaYeriKaydet(String ad, double enlem, double boylam) async {
    durum['havaYeri'] = {'ad': ad, 'enlem': enlem, 'boylam': boylam};
    havaYeriBekleyen = null;
    hava = null;
    durum.remove('hava');
    durum.remove('havaZamani');
    await _durumKaydet();
    await havaYenile(zorla: true);
  }

  /// Seçili yerin hava durumunu indirir. Son indirme 20 dakikadan yeniyse ve [zorla] değilse atlar.
  Future<void> havaYenile({bool zorla = false}) async {
    final yer = havaYeri;
    if (yer == null || (havaYukleniyor && !zorla)) return;
    final son = havaZamani;
    if (!zorla && hava != null && son != null && DateTime.now().difference(son).inMinutes < 20) return;
    final istek = ++_havaIstegi;
    havaYukleniyor = true;
    havaHatasi = null;
    notifyListeners();
    try {
      final ham = await havaIndir((yer['enlem'] as num).toDouble(), (yer['boylam'] as num).toDouble());
      if (istek != _havaIstegi) return;
      hava = Hava.fromJson(ham);
      durum['hava'] = ham;
      durum['havaZamani'] = DateTime.now().toIso8601String();
    } catch (_) {
      if (istek == _havaIstegi) havaHatasi = 'Hava durumu alınamadı. İnternet bağlantınızı kontrol edin.';
    } finally {
      if (istek == _havaIstegi) {
        havaYukleniyor = false;
        await _durumKaydet();
      }
    }
  }

  // ---------------------------------------------------------------- kontrol listeleri
  List<int> isaretliler(String listeId) =>
      (((durum['isaretler'] as Map<String, dynamic>?) ?? {})[listeId] as List<dynamic>? ?? []).cast<int>();

  Future<void> isaretDegistir(String listeId, int sira) {
    final hepsi = Map<String, dynamic>.from((durum['isaretler'] as Map<String, dynamic>?) ?? {});
    final l = isaretliler(listeId).toList();
    l.contains(sira) ? l.remove(sira) : l.add(sira);
    hepsi[listeId] = l;
    durum['isaretler'] = hepsi;
    return _durumKaydet();
  }

  Future<void> isaretleriTemizle(String listeId) {
    final hepsi = Map<String, dynamic>.from((durum['isaretler'] as Map<String, dynamic>?) ?? {});
    hepsi.remove(listeId);
    durum['isaretler'] = hepsi;
    return _durumKaydet();
  }

  // ---------------------------------------------------------------- haberler
  /// Trafik kazası ve trafik mevzuatı haberleri (başlık, kaynak, bağlantı), en yeni başta.
  List<Map<String, dynamic>> haberler = [];
  bool haberYukleniyor = false;

  int get okunmamisHaber {
    final okunan = durum['haberOkundu'] as String? ?? '';
    return haberler.where((h) => (h['tarih'] as String).compareTo(okunan) > 0).length;
  }

  Future<void> haberleriOkunduIsaretle() {
    if (haberler.isEmpty) return Future.value();
    durum['haberOkundu'] = haberler.first['tarih'];
    return _durumKaydet();
  }

  /// Haber listesinin en son yenilendiği an: cihazdaki doğrudan arama ya da veri dosyasının toplanma zamanı.
  DateTime? get haberZamani {
    final cihaz = DateTime.tryParse(_prefs.getString('haberZamani') ?? '');
    final dosya = DateTime.tryParse(surum['haberZamani'] as String? ?? '')?.toLocal();
    if (cihaz == null || dosya == null) return cihaz ?? dosya;
    return cihaz.isAfter(dosya) ? cihaz : dosya;
  }

  /// Günde bir kez, sabah 06:00'dan sonraki ilk fırsatta veriyi ve haberleri yeniler.
  /// Açılışta ve uygulama açıkken her dakika çağrılır; o günün yenilemesi yapıldıysa hiçbir şey yapmaz.
  Future<void> sabahYenilemesi({DateTime? simdi}) async {
    final an = simdi ?? DateTime.now();
    final son = DateTime.tryParse(_prefs.getString('sabahYenileme') ?? '');
    if (son == null || son.isBefore(sonSabahAlti(an))) {
      await _prefs.setString('sabahYenileme', an.toIso8601String());
      await guncelle();
    }
    // Kendi içinde denetler: o sabah başarıyla yenilendiyse atlar, bağlantı yoktuysa yeniden dener.
    await haberleriYenile();
  }

  /// Taze başlıkları doğrudan arar ve mevcut listeyle birleştirir. O sabah 06:00'dan sonra zaten
  /// yenilendiyse [zorla] verilmedikçe atlar. Web sürümünde tarayıcı kısıtı nedeniyle çalışmaz;
  /// orada haberler veri güncellemesiyle gelir.
  Future<void> haberleriYenile({bool zorla = false}) async {
    if (kIsWeb || haberYukleniyor) return;
    final son = DateTime.tryParse(_prefs.getString('haberZamani') ?? '');
    if (!zorla && son != null && !son.isBefore(sonSabahAlti(DateTime.now()))) return;
    haberYukleniyor = true;
    notifyListeners();
    try {
      haberler = haberleriSinirla(haberleriBirlestir(haberler, await haberleriIndir()));
      await _prefs.setString('haberOnbellek', jsonEncode(haberler));
      await _prefs.setString('haberZamani', DateTime.now().toIso8601String());
    } catch (_) {
      // Bağlantı yoksa mevcut liste gösterilmeye devam eder.
    } finally {
      haberYukleniyor = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- duyurular
  int get okunmamisDuyuru {
    final okunan = durum['duyuruOkundu'] as String? ?? '';
    return duyurular.where((d) => (d['tarih'] as String? ?? '').compareTo(okunan) > 0).length;
  }

  Future<void> duyurulariOkunduIsaretle() {
    if (duyurular.isEmpty) return Future.value();
    durum['duyuruOkundu'] = duyurular.map((d) => d['tarih'] as String? ?? '').reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    return _durumKaydet();
  }

  // ---------------------------------------------------------------- quiz ilerlemesi
  Map<String, dynamic> get quiz => (durum['quiz'] as Map<String, dynamic>?) ?? {};
  int get xp => quiz['xp'] as int? ?? 0;

  static const dereceler = [
    (0, 'Aday'),
    (100, 'Devriye'),
    (300, 'Uzman'),
    (700, 'Kıdemli Uzman'),
    (1500, 'Usta'),
    (3000, 'Üstat'),
  ];

  int get dereceSirasi => dereceler.lastIndexWhere((d) => xp >= d.$1);
  String get derece => dereceler[dereceSirasi].$2;

  /// Bir sonraki dereceye ilerleme oranı (0-1).
  double get dereceIlerleme {
    final s = dereceSirasi;
    if (s == dereceler.length - 1) return 1;
    return (xp - dereceler[s].$1) / (dereceler[s + 1].$1 - dereceler[s].$1);
  }

  /// Kategori bazında [doğru, toplam] sayıları.
  Map<String, List<int>> get kategoriBasarisi => {
        for (final e in ((quiz['kategori'] as Map<String, dynamic>?) ?? {}).entries)
          e.key: (e.value as List<dynamic>).cast<int>(),
      };

  /// Biten bir quiz turunu işler ve kazanılan puanı döndürür.
  Future<int> turBitti(Map<String, List<int>> kategoriSonuclari, int enUzunSeri) async {
    final q = Map<String, dynamic>.from(quiz);
    final kat = Map<String, dynamic>.from((q['kategori'] as Map<String, dynamic>?) ?? {});
    var dogru = 0, toplam = 0;
    kategoriSonuclari.forEach((k, v) {
      final eski = (kat[k] as List<dynamic>?)?.cast<int>() ?? [0, 0];
      kat[k] = [eski[0] + v[0], eski[1] + v[1]];
      dogru += v[0];
      toplam += v[1];
    });
    final hatasiz = toplam > 0 && dogru == toplam;
    final kazanilan = dogru * 10 + (hatasiz ? 30 : 0);
    final bugun = tarihYaz(DateTime.now());
    final dun = tarihYaz(DateTime.now().subtract(const Duration(days: 1)));
    final sonGun = q['sonGun'] as String?;
    if (sonGun != bugun) {
      q['gunSerisi'] = sonGun == dun ? (q['gunSerisi'] as int? ?? 0) + 1 : 1;
      q['sonGun'] = bugun;
    }
    q['kategori'] = kat;
    q['xp'] = xp + kazanilan;
    q['dogru'] = (q['dogru'] as int? ?? 0) + dogru;
    q['toplam'] = (q['toplam'] as int? ?? 0) + toplam;
    q['tur'] = (q['tur'] as int? ?? 0) + 1;
    q['hatasizTur'] = (q['hatasizTur'] as int? ?? 0) + (hatasiz ? 1 : 0);
    if (enUzunSeri > (q['seri'] as int? ?? 0)) q['seri'] = enUzunSeri;
    durum['quiz'] = q;
    await _durumKaydet();
    return kazanilan;
  }

  /// (ad, açıklama, kazanıldı mı) üçlüleri.
  List<(String, String, bool)> get rozetler {
    final q = quiz;
    int s(String ad) => q[ad] as int? ?? 0;
    final kat = kategoriBasarisi;
    return [
      ('İlk Adım', 'İlk quiz turunu tamamla', s('tur') >= 1),
      ('Hatasız', 'Bir turu hiç yanlış yapmadan bitir', s('hatasizTur') >= 1),
      ('Seri 10', 'Art arda 10 doğru cevap ver', s('seri') >= 10),
      ('Yüzlük', 'Toplam 100 doğru cevaba ulaş', s('dogru') >= 100),
      ('İstikrarlı', '7 gün üst üste quiz çöz', s('gunSerisi') >= 7),
      ('Çok Yönlü', '5 farklı kategoride soru çöz', kat.length >= 5),
      ('Keskin', 'En az 50 soruda %90 başarı', s('toplam') >= 50 && s('dogru') / s('toplam') >= 0.9),
      ('Usta', 'Usta derecesine ulaş', xp >= 1500),
    ];
  }

  Future<void> ilerlemeyiSifirla() {
    durum.remove('quiz');
    return _durumKaydet();
  }
}
