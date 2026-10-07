import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../veri/depo.dart';
import '../veri/hesap.dart';
import '../veri/modeller.dart';
import 'araclar.dart';
import 'ayarlar_ekrani.dart';
import 'egitim.dart';
import 'islemler.dart';
import 'kaza_kaydi.dart';
import 'mevzuat.dart';
import 'ortak.dart';

// ---------------------------------------------------------------- yaş hesabı
class YasHesabi extends StatefulWidget {
  const YasHesabi({super.key});

  @override
  State<YasHesabi> createState() => _YasHesabiState();
}

class _YasHesabiState extends State<YasHesabi> {
  DateTime? _dogum;
  DateTime _tarih = DateTime.now();

  /// Doldurulduğu tarih ayrıca gösterilen yaşlar; yalnızca takvim hesabıdır.
  static const _yaslar = [16, 17, 18, 20, 21, 22, 24, 26, 65];

  Future<void> _sec(bool dogum) async {
    final t = await showDatePicker(
      context: context,
      initialDate: dogum ? (_dogum ?? DateTime(2000)) : _tarih,
      firstDate: DateTime(1920),
      lastDate: DateTime(2100),
      helpText: dogum ? 'Doğum tarihi' : 'Hesap tarihi',
    );
    if (t != null) setState(() => dogum ? _dogum = t : _tarih = t);
  }

  @override
  Widget build(BuildContext context) {
    final dogum = _dogum;
    final gecerli = dogum != null && !dogum.isAfter(_tarih);
    return HesapSayfasi(
      baslik: 'Yaş hesabı',
      cocuklar: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.cake_outlined),
            title: const Text('Doğum tarihi'),
            subtitle: Text(dogum == null ? 'Seçmek için dokunun' : tarihYaz(dogum)),
            onTap: () => _sec(true),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Hesap tarihi (olay günü)'),
            subtitle: Text(tarihYaz(_tarih)),
            trailing: TextButton(onPressed: () => setState(() => _tarih = DateTime.now()), child: const Text('Bugün')),
            onTap: () => _sec(false),
          ),
        ),
        const SizedBox(height: 14),
        if (dogum != null && !gecerli) const Uyari('Doğum tarihi hesap tarihinden sonra olamaz.'),
        if (gecerli) ...[
          () {
            final (yil, ay, gun) = yasHesapla(dogum, _tarih);
            return SonucKarti([
              BilgiSatiri('Yaş', '$yil yaş, $ay ay, $gun gün', vurgu: true),
              BilgiSatiri('Bitirdiği yaş', '$yil'),
              BilgiSatiri('Toplam gün', '${DateUtils.dateOnly(_tarih).difference(DateUtils.dateOnly(dogum)).inDays}'),
            ]);
          }(),
          const Bolum('Yaşı doldurduğu tarihler'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (final y in _yaslar)
                    () {
                      final t = yasDoldurma(dogum, y);
                      final doldu = !t.isAfter(DateUtils.dateOnly(_tarih));
                      return BilgiSatiri('$y yaş', '${tarihYaz(t)}  ·  ${doldu ? 'doldurmuş' : 'doldurmamış'}', renk: doldu ? Renkler.yesil : Renkler.kirmizi);
                    }(),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Uyari('Takvim hesabıdır. Bir işlem için hangi yaşın arandığını ilgili mevzuat maddesinden doğrulayın.'),
      ],
    );
  }
}

// ---------------------------------------------------------------- arşiv
/// Kullanıcının kendi kayıtlarının tek yerden görüldüğü ekran. Hepsi yalnızca cihazda durur.
class ArsivEkrani extends StatelessWidget {
  const ArsivEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        Widget satir(IconData ikon, Color renk, String ad, String alt, Widget ekran) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: RenkliIkon(ikon, renk, boyut: 40),
                  title: Text(ad, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(alt),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => git(context, ekran),
                ),
              ),
            );
        final bugun = IslemOzeti(donemKayitlari(depo.islemler, 1));
        return Scaffold(
          appBar: AppBar(title: const Text('Arşivim')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const AracBasligi('Arşivim'),
              const Bolum('Kayıtlarım'),
              satir(Icons.fact_check, Renkler.yesil, 'İcraat (işlem kayıtları)', '${depo.islemler.length} kayıt · bugün ${bugun.adet}', const IslemlerEkrani()),
              satir(Icons.add_location_alt, Renkler.kirmizi, 'Kaza kayıtlarım', '${depo.kazaKayitlari.length} kayıt', const KazaKayitlariEkrani()),
              satir(Icons.draw, Renkler.lacivert, 'Krokilerim', '${depo.krokiler.length} kroki', const KrokilerEkrani()),
              const Bolum('Notlarım'),
              for (final tur in notTurleri)
                satir(notTuruIkonu(tur), Renkler.turuncu, tur, '${depo.notlar.where((n) => notTuru(n) == tur).length} not', NotlarEkrani(tur: tur)),
              const Bolum('İşaretlediklerim'),
              satir(Icons.bookmark, Renkler.turkuaz, 'Yer imli maddeler', '${depo.yerImleri.length} madde', const _YerImleri()),
              satir(Icons.star, Renkler.mor, 'Sık kullandığım cezalar', '${depo.favoriler.length} kalem', const AyarlarEkrani()),
              const SizedBox(height: 8),
              const Uyari('Arşivdeki her şey yalnızca bu cihazda saklanır; hiçbir yere gönderilmez.', ikon: Icons.lock_outline),
            ],
          ),
        );
      },
    );
  }
}

class _YerImleri extends StatelessWidget {
  const _YerImleri();

  @override
  Widget build(BuildContext context) => const MevzuatEkrani(yalnizYerImleri: true);
}

// ---------------------------------------------------------------- kaza krokisi
const _yolTipleri = {'duz': 'İki yönlü', 'tekyon': 'Çok şeritli', 'bolunmus': 'Bölünmüş', 'kavsak': 'Kavşak', 'dar': 'Dar yol'};
const _aracTurleri = {'otomobil': 'Otomobil', 'kamyon': 'Kamyon / otobüs', 'motosiklet': 'Motosiklet'};
const _aracAdlari = ['A', 'B', 'C', 'D'];

Map<String, dynamic> _bosSahne() => {
      'yol': 'kavsak',
      'araclar': [
        {'ad': 'A', 'x': 0.57, 'y': 0.85, 'yon': 0},
        {'ad': 'B', 'x': 0.15, 'y': 0.57, 'yon': 90},
      ],
    };

class KrokilerEkrani extends StatelessWidget {
  const KrokilerEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Kaza krokisi')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => git(context, const KrokiDuzenle(null)),
          icon: const Icon(Icons.draw),
          label: const Text('Yeni kroki'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            const AracBasligi('Kaza krokisi'),
            if (depo.krokiler.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('Henüz kroki yok.\nYol tipini seçin, araçları sürükleyip döndürün, hareket oklarını ve fren izini çizin.', textAlign: TextAlign.center),
              ),
            for (final k in depo.krokiler)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => git(context, KrokiDuzenle(k)),
                    child: Row(
                      children: [
                        SizedBox(width: 96, height: 96, child: CustomPaint(painter: SahneRessami(k['sahne'] as Map<String, dynamic>, kucuk: true))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((k['baslik'] as String? ?? '').isEmpty ? 'Adsız kroki' : k['baslik'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(tarihYaz(DateTime.parse(k['tarih'] as String), saat: true), style: const TextStyle(fontSize: 12)),
                              if ((k['aciklama'] as String? ?? '').isNotEmpty) Text(k['aciklama'] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kroki çizim ekranı. [kayitIcin] doğruysa kroki arşive yazılmaz; çizilen sahne geri döndürülür
/// (kaza kaydına eklemek için).
class KrokiDuzenle extends StatefulWidget {
  const KrokiDuzenle(this.kroki, {super.key, this.kayitIcin = false});
  final Map<String, dynamic>? kroki;
  final bool kayitIcin;

  @override
  State<KrokiDuzenle> createState() => _KrokiDuzenleState();
}

class _KrokiDuzenleState extends State<KrokiDuzenle> {
  late Map<String, dynamic> _sahne = _kopya((widget.kroki?['sahne'] as Map<String, dynamic>?) ?? _bosSahne());
  late final _baslik = TextEditingController(text: widget.kroki?['baslik'] as String? ?? '');
  late final _aciklama = TextEditingController(text: widget.kroki?['aciklama'] as String? ?? '');
  bool _ciziyor = false;
  int _secili = 0;

  /// Sürüklenen nesne: ('arac' | 'hedef', sıra) ya da ('carpisma' | 'yaya' | 'levha', -1).
  (String, int)? _tutulan;

  static Map<String, dynamic> _kopya(Map<String, dynamic> s) => {
        ...s,
        'araclar': [for (final a in s['araclar'] as List<dynamic>) {...a as Map<String, dynamic>}],
        'cizgiler': [for (final c in (s['cizgiler'] as List<dynamic>?) ?? const []) [...c as List<dynamic>]],
      };

  List<Map<String, dynamic>> get _araclar => (_sahne['araclar'] as List<dynamic>).cast<Map<String, dynamic>>();
  List<List<dynamic>> get _cizgiler => (_sahne['cizgiler'] as List<dynamic>).cast<List<dynamic>>();

  @override
  void dispose() {
    _baslik.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  /// Ressam sahnenin değiştiğini nesne kimliğinden anladığı için her değişiklikte yeni harita kurulur.
  void _degistir(VoidCallback islem) => setState(() {
        islem();
        _sahne = {..._sahne};
      });

  static double _sinirla(double v) => (v.clamp(0.03, 0.97) * 1000).round() / 1000;

  void _basla(Offset p) {
    if (_ciziyor) {
      _degistir(() => _cizgiler.add([_sinirla(p.dx), _sinirla(p.dy)]));
      return;
    }
    (String, int)? enYakin;
    var mesafe = 0.09;
    void dene(String tur, int i, dynamic nokta) {
      if (nokta is! List) return;
      final d = (Offset((nokta[0] as num).toDouble(), (nokta[1] as num).toDouble()) - p).distance;
      if (d < mesafe) {
        mesafe = d;
        enYakin = (tur, i);
      }
    }

    for (final (i, a) in _araclar.indexed) {
      dene('arac', i, [a['x'], a['y']]);
      dene('hedef', i, a['hedef']);
    }
    for (final tur in ['carpisma', 'yaya', 'levha']) {
      dene(tur, -1, _sahne[tur]);
    }
    _tutulan = enYakin;
    if (enYakin != null && enYakin!.$2 >= 0) setState(() => _secili = enYakin!.$2);
  }

  void _surukle(Offset p) {
    final x = _sinirla(p.dx), y = _sinirla(p.dy);
    if (_ciziyor) {
      if (_cizgiler.isNotEmpty) _degistir(() => _cizgiler.last.addAll([x, y]));
      return;
    }
    final t = _tutulan;
    if (t == null) return;
    _degistir(() {
      switch (t.$1) {
        case 'arac':
          _araclar[t.$2]
            ..['x'] = x
            ..['y'] = y;
        case 'hedef':
          _araclar[t.$2]['hedef'] = [x, y];
        default:
          _sahne[t.$1] = [x, y];
      }
    });
  }

  void _noktaDegistir(String ad, List<double> varsayilan, bool acik) => _degistir(() => acik ? _sahne[ad] = varsayilan : _sahne.remove(ad));

  Future<void> _kaydet() async {
    if (widget.kayitIcin) {
      Navigator.pop(context, _sahne);
      return;
    }
    await Depo.i.krokiKaydet({
      ...?widget.kroki,
      'baslik': _baslik.text.trim(),
      'aciklama': _aciklama.text.trim(),
      'sahne': _sahne,
      'tarih': DateTime.now().toIso8601String(),
    });
    if (mounted) {
      bildir(context, 'Kroki kaydedildi');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final id = widget.kroki?['id'] as String?;
    final arac = _secili < _araclar.length ? _araclar[_secili] : null;
    Widget anahtar(String ad, bool deger, ValueChanged<bool> degisti) => FilterChip(label: Text(ad), selected: deger, onSelected: degisti, visualDensity: VisualDensity.compact);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kayitIcin ? 'Kaza krokisi' : (id == null ? 'Yeni kroki' : 'Kroki')),
        actions: [
          if (id != null && !widget.kayitIcin)
            IconButton(
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await Depo.i.krokiSil(id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          IconButton(tooltip: 'Kaydet', icon: const Icon(Icons.check), onPressed: _kaydet),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: LayoutBuilder(
                    builder: (context, kutu) {
                      Offset oran(Offset p) => Offset(p.dx / kutu.maxWidth, p.dy / kutu.maxHeight);
                      return GestureDetector(
                        onPanStart: (d) => _basla(oran(d.localPosition)),
                        onPanUpdate: (d) => _surukle(oran(d.localPosition)),
                        onPanEnd: (_) => _tutulan = null,
                        child: CustomPaint(painter: SahneRessami(_sahne), size: Size.infinite),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.open_with), label: Text('Taşı')),
                    ButtonSegment(value: true, icon: Icon(Icons.gesture), label: Text('Fren izi çiz')),
                  ],
                  selected: {_ciziyor},
                  onSelectionChanged: (s) => setState(() => _ciziyor = s.first),
                ),
              ),
              IconButton(
                tooltip: 'Son çizgiyi geri al',
                icon: const Icon(Icons.undo),
                onPressed: _cizgiler.isEmpty ? null : () => _degistir(() => _cizgiler.removeLast()),
              ),
            ],
          ),
          Text(
            _ciziyor ? 'Parmağınızla fren ya da savrulma izini çizin.' : 'Araçları, ok uçlarını ve işaretleri sürükleyerek yerleştirin.',
            style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant),
          ),
          const Bolum('Yol'),
          Wrap(
            spacing: 8,
            children: [
              for (final y in _yolTipleri.entries)
                ChoiceChip(label: Text(y.value), selected: _sahne['yol'] == y.key, onSelected: (_) => _degistir(() => _sahne['yol'] = y.key)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              anahtar('Trafik ışığı', _sahne['isik'] == true, (v) => _degistir(() => v ? _sahne['isik'] = true : _sahne.remove('isik'))),
              anahtar('Yaya geçidi', _sahne['gecit'] != null, (v) => _degistir(() => v ? _sahne['gecit'] = 0.7 : _sahne.remove('gecit'))),
              anahtar('DUR levhası', _sahne['levha'] != null, (v) => _noktaDegistir('levha', [0.72, 0.72], v)),
              anahtar('Yaya', _sahne['yaya'] != null, (v) => _noktaDegistir('yaya', [0.3, 0.5], v)),
              anahtar('Çarpışma noktası', _sahne['carpisma'] != null, (v) => _noktaDegistir('carpisma', [0.5, 0.5], v)),
            ],
          ),
          const Bolum('Araçlar'),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (i, a) in _araclar.indexed)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: SahneRessami.aracRengi(a['ad'] as String)),
                  label: Text('${a['ad']} aracı'),
                  selected: _secili == i,
                  onSelected: (_) => setState(() => _secili = i),
                ),
              if (_araclar.length < _aracAdlari.length)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Araç ekle'),
                  onPressed: () => _degistir(() {
                    final ad = _aracAdlari.firstWhere((x) => _araclar.every((a) => a['ad'] != x));
                    _araclar.add({'ad': ad, 'x': 0.5, 'y': 0.2, 'yon': 180});
                    _secili = _araclar.length - 1;
                  }),
                ),
            ],
          ),
          if (arac != null) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final t in _aracTurleri.entries)
                          ChoiceChip(
                            label: Text(t.value),
                            selected: (arac['tur'] ?? 'otomobil') == t.key,
                            onSelected: (_) => _degistir(() => arac['tur'] = t.key),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Yön'),
                        for (final (aci, ikon) in [(-45, Icons.rotate_left), (-15, Icons.undo), (15, Icons.redo), (45, Icons.rotate_right)])
                          IconButton(
                            tooltip: '${aci > 0 ? '+' : ''}$aci°',
                            icon: Icon(ikon),
                            onPressed: () => _degistir(() => arac['yon'] = ((arac['yon'] as num) + aci) % 360),
                          ),
                        Text('${(arac['yon'] as num).round()}°', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        anahtar('Hareket oku', arac['hedef'] != null, (v) => _degistir(() {
                              if (!v) {
                                arac.remove('hedef');
                                return;
                              }
                              // Ok, aracın baktığı yönde biraz ileriye konur; ucu sürüklenerek düzeltilir.
                              final r = (arac['yon'] as num) * math.pi / 180;
                              arac['hedef'] = [_sinirla((arac['x'] as num) + math.sin(r) * 0.25), _sinirla((arac['y'] as num) - math.cos(r) * 0.25)];
                            })),
                        anahtar('Park hâlinde', arac['park'] == true, (v) => _degistir(() => v ? arac['park'] = true : arac.remove('park'))),
                        if (_araclar.length > 1)
                          ActionChip(
                            avatar: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Aracı sil'),
                            onPressed: () => _degistir(() {
                              _araclar.removeAt(_secili);
                              _secili = 0;
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!widget.kayitIcin) ...[
            const SizedBox(height: 14),
            TextField(controller: _baslik, decoration: const InputDecoration(labelText: 'Başlık (ör. yer, tarih)')),
            const SizedBox(height: 12),
            TextField(controller: _aciklama, minLines: 2, maxLines: 6, decoration: const InputDecoration(labelText: 'Açıklama')),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(icon: const Icon(Icons.save), label: Padding(padding: const EdgeInsets.all(10), child: Text(widget.kayitIcin ? 'Krokiyi kayda ekle' : 'Kaydet')), onPressed: _kaydet),
          const SizedBox(height: 12),
          const Uyari('Kroki ölçekli değildir ve resmî kaza tespit tutanağındaki krokinin yerine geçmez. Yalnızca bu cihazda saklanır.', ikon: Icons.lock_outline),
        ],
      ),
    );
  }
}
