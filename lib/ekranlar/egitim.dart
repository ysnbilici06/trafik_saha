import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'ortak.dart';

const _puanKategorisi = 'İhlal Puanları';
const _tutarKategorisi = 'Ceza Tutarları';

const _carkRenkleri = [Renkler.mor, Renkler.turuncu, Renkler.kirmizi, Renkler.mavi, Renkler.yesil, Renkler.turkuaz, Renkler.lacivert];

/// Yazılı soruları ve güncel ceza verisinden üretilen soruları birleştirip bir tur hazırlar.
/// Üretilen sorular veriden okunduğu için tutarlar değiştiğinde kendiliğinden güncellenir.
List<Map<String, dynamic>> turHazirla(Depo depo, String? kategori, {int adet = 10, math.Random? rastgele}) {
  final r = rastgele ?? math.Random();
  final havuz = <Map<String, dynamic>>[
    for (final s in depo.sorular)
      if (kategori == null || s['kategori'] == kategori) s,
  ];
  final uygun = depo.cezalar.where((c) => c.kanun == '2918' && c.konu.length < 150).toList();
  if (kategori == null || kategori == _puanKategorisi) {
    const secenekler = ['5', '10', '15', '20'];
    for (final c in uygun.where((c) => c.puan != null && secenekler.contains('${c.puan}'))) {
      havuz.add({
        'id': 'p:${c.id}',
        'kategori': _puanKategorisi,
        'soru': '"${c.konu}" ihlalinin ceza puanı kaçtır?',
        'secenekler': secenekler,
        'dogru': secenekler.indexOf('${c.puan}'),
        'aciklama': 'Md. ${c.madde}: ${c.puan} ceza puanı.',
        'madde': c.anaMadde,
      });
    }
  }
  if (kategori == null || kategori == _tutarKategorisi) {
    final tutarli = uygun.where((c) => c.tutar != null && !c.kademeli).toList();
    final tumTutarlar = tutarli.map((c) => c.tutar!).toSet().toList();
    for (final c in tutarli) {
      final digerleri = (tumTutarlar.where((t) => t != c.tutar).toList()..shuffle(r)).take(3);
      final secenekler = [c.tutar!, ...digerleri]..shuffle(r);
      havuz.add({
        'id': 't:${c.id}',
        'kategori': _tutarKategorisi,
        'soru': '"${c.konu}" ihlalinin idari para cezası ne kadardır?',
        'secenekler': secenekler.map(para).toList(),
        'dogru': secenekler.indexOf(c.tutar!),
        'aciklama': 'Md. ${c.madde}: ${para(c.tutar)} (%25 indirimli ${para(c.indirimli)}).',
        'madde': c.anaMadde,
      });
    }
  }
  havuz.shuffle(r);
  if (kategori != null) return havuz.take(adet).toList();
  // Karışık turda veriden üretilen çok sayıdaki soru, yazılı soruları bastırmasın.
  final yazili = havuz.where((s) => !(s['id'] as String).contains(':')).take(adet ~/ 2);
  final uretilen = havuz.where((s) => (s['id'] as String).contains(':')).take(adet - yazili.length);
  return [...yazili, ...uretilen]..shuffle(r);
}

class EgitimEkrani extends StatelessWidget {
  const EgitimEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final t = Theme.of(context);
        final renk = t.colorScheme;
        final kategoriler = [...{for (final s in depo.sorular) s['kategori'] as String}, _puanKategorisi, _tutarKategorisi];
        final basari = depo.kategoriBasarisi;
        final sira = depo.dereceSirasi;
        final sonraki = sira < Depo.dereceler.length - 1 ? Depo.dereceler[sira + 1] : null;
        return Scaffold(
          appBar: AppBar(title: const Text('Eğitim')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: renk.primaryContainer, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    _Cark(deger: depo.dereceIlerleme, boyut: 92, kalinlik: 10, renk: renk.primary, zemin: renk.surface,
                        orta: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.military_tech, color: renk.primary),
                          Text('${depo.xp}', style: TextStyle(fontWeight: FontWeight.w800, color: renk.onPrimaryContainer)),
                        ])),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Derece', style: TextStyle(fontSize: 12, color: renk.onPrimaryContainer)),
                          Text(depo.derece, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: renk.onPrimaryContainer)),
                          Text(sonraki == null ? 'En üst derecedesiniz' : '${sonraki.$2} için ${sonraki.$1 - depo.xp} puan kaldı',
                              style: TextStyle(color: renk.onPrimaryContainer)),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Karışık quiz başlat'),
                            onPressed: () => git(context, const QuizEkrani(null)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Bolum('Başarı çarkları'),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.78,
                children: [
                  for (final (sira, k) in kategoriler.indexed)
                    Material(
                      color: _carkRenkleri[sira % _carkRenkleri.length].withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => git(context, QuizEkrani(k)),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Cark(
                                deger: basari[k] == null || basari[k]![1] == 0 ? 0 : basari[k]![0] / basari[k]![1],
                                boyut: 58,
                                kalinlik: 7,
                                renk: _carkRenkleri[sira % _carkRenkleri.length],
                                zemin: renk.surfaceContainerHighest,
                                orta: Text(basari[k] == null ? '–' : '%${(basari[k]![0] / basari[k]![1] * 100).round()}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              ),
                              const SizedBox(height: 8),
                              Text(k, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('${basari[k]?[1] ?? 0} soru', style: TextStyle(fontSize: 11, color: renk.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const Bolum('Rozetler'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in depo.rozetler)
                    Tooltip(
                      message: r.$2,
                      triggerMode: TooltipTriggerMode.tap,
                      child: Chip(
                        avatar: Icon(r.$3 ? Icons.emoji_events : Icons.lock_outline, size: 18, color: r.$3 ? renk.onTertiaryContainer : renk.outline),
                        label: Text(r.$1),
                        backgroundColor: r.$3 ? renk.tertiaryContainer : renk.surfaceContainerLow,
                        side: BorderSide.none,
                      ),
                    ),
                ],
              ),
              const Bolum('Kaza ve kusur'),
              Card(
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Icon(Icons.car_crash, color: renk.primary),
                  title: const Text('Şemalı kaza örnekleri', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${depo.kazalar.length} örnek · kusur durumu ve dayanak madde'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => git(context, const KazalarEkrani()),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Icon(Icons.gavel, color: renk.primary),
                  title: const Text('Emsal Yargıtay kararları', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${depo.kararlar.length} karar · bilirkişi ve kusur değerlendirmesi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => git(context, const KararlarEkrani()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Ortasında içerik taşıyan dairesel ilerleme göstergesi.
class _Cark extends StatelessWidget {
  const _Cark({required this.deger, required this.boyut, required this.kalinlik, required this.renk, required this.zemin, required this.orta});
  final double deger;
  final double boyut;
  final double kalinlik;
  final Color renk;
  final Color zemin;
  final Widget orta;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: boyut,
      height: boyut,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: deger.clamp(0, 1).toDouble()),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) =>
                  CircularProgressIndicator(value: v, strokeWidth: kalinlik, color: renk, backgroundColor: zemin, strokeCap: StrokeCap.round),
            ),
          ),
          orta,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- quiz
class QuizEkrani extends StatefulWidget {
  const QuizEkrani(this.kategori, {super.key});
  final String? kategori;

  @override
  State<QuizEkrani> createState() => _QuizEkraniState();
}

class _QuizEkraniState extends State<QuizEkrani> {
  late final List<Map<String, dynamic>> _sorular = turHazirla(Depo.i, widget.kategori);
  final Map<String, List<int>> _sonuclar = {};
  int _sira = 0;
  int? _secim;
  int _seri = 0;
  int _enUzunSeri = 0;
  int _dogru = 0;
  int? _kazanilan;

  void _sec(int i) {
    if (_secim != null) return;
    final s = _sorular[_sira];
    final dogruMu = i == s['dogru'];
    final k = _sonuclar.putIfAbsent(s['kategori'] as String, () => [0, 0]);
    setState(() {
      _secim = i;
      k[1]++;
      if (dogruMu) {
        k[0]++;
        _dogru++;
        _seri++;
        _enUzunSeri = math.max(_enUzunSeri, _seri);
      } else {
        _seri = 0;
      }
    });
  }

  Future<void> _ileri() async {
    if (_sira < _sorular.length - 1) {
      setState(() {
        _sira++;
        _secim = null;
      });
      return;
    }
    final kazanilan = await Depo.i.turBitti(_sonuclar, _enUzunSeri);
    if (mounted) setState(() => _kazanilan = kazanilan);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final renk = t.colorScheme;
    if (_sorular.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Bu kategoride soru bulunamadı')));
    }
    if (_kazanilan != null) {
      final oran = _dogru / _sorular.length;
      return Scaffold(
        appBar: AppBar(title: const Text('Sonuç')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Cark(deger: oran, boyut: 150, kalinlik: 14, renk: renk.primary, zemin: renk.surfaceContainerHighest,
                    orta: Text('$_dogru / ${_sorular.length}', style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
                const SizedBox(height: 24),
                Text(oran == 1 ? 'Hatasız tur!' : oran >= 0.7 ? 'İyi iş' : 'Tekrar etmekte fayda var',
                    style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('+$_kazanilan puan · Derece: ${Depo.i.derece}', style: TextStyle(color: renk.onSurfaceVariant)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.replay),
                  label: const Text('Yeni tur'),
                  onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => QuizEkrani(widget.kategori))),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
              ],
            ),
          ),
        ),
      );
    }
    final s = _sorular[_sira];
    final secenekler = (s['secenekler'] as List<dynamic>).cast<String>();
    final dogru = s['dogru'] as int;
    return Scaffold(
      appBar: AppBar(title: Text(widget.kategori ?? 'Karışık quiz')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              Expanded(child: LinearProgressIndicator(value: (_sira + 1) / _sorular.length, minHeight: 8, borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 12),
              Text('${_sira + 1}/${_sorular.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Etiket(s['kategori'] as String, renk.secondaryContainer, renk.onSecondaryContainer),
          const SizedBox(height: 10),
          Text(s['soru'] as String, style: t.textTheme.titleMedium?.copyWith(height: 1.4, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          for (var i = 0; i < secenekler.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: _secim == null
                    ? renk.surfaceContainerLow
                    : i == dogru
                        ? Colors.green.withValues(alpha: 0.22)
                        : i == _secim
                            ? renk.errorContainer
                            : renk.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _sec(i),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 14, backgroundColor: renk.surface, child: Text('ABCD'[i], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(secenekler[i])),
                        if (_secim != null && i == dogru) const Icon(Icons.check_circle, color: Colors.green),
                        if (_secim == i && i != dogru) Icon(Icons.cancel, color: renk.error),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_secim != null) ...[
            Uyari(s['aciklama'] as String, ikon: Icons.lightbulb_outline),
            const SizedBox(height: 16),
            FilledButton(onPressed: _ileri, child: Text(_sira < _sorular.length - 1 ? 'Sonraki soru' : 'Turu bitir')),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- kaza örnekleri
class KazalarEkrani extends StatelessWidget {
  const KazalarEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final kazalar = Depo.i.kazalar;
    return Scaffold(
      appBar: AppBar(title: const Text('Kaza örnekleri')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SayfaBasligi(Icons.car_crash, Renkler.turuncu, 'Kaza örnekleri', 'Sık görülen kaza türleri, krokisi ve asli kusur maddesi'),
          const Uyari('Örnekler eğitim amaçlıdır ve sadeleştirilmiştir. Kusur değerlendirmesi her olayda somut '
              'delillere göre yapılır; birden fazla ihlal varsa oran yönetmelikteki esaslara göre belirlenir.'),
          const SizedBox(height: 12),
          for (final k in kazalar)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => git(context, KazaDetay(k)),
                  child: Row(
                    children: [
                      SizedBox(width: 96, height: 96, child: CustomPaint(painter: SahneRessami(k['sahne'] as Map<String, dynamic>, kucuk: true))),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(k['baslik'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(k['asliKusur'] as String, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class KazaDetay extends StatelessWidget {
  const KazaDetay(this.kaza, {super.key});
  final Map<String, dynamic> kaza;

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    final t = Theme.of(context);
    final renk = t.colorScheme;
    final taraflar = (kaza['taraflar'] as List<dynamic>).cast<Map<String, dynamic>>();
    final ihlaller = [for (final id in kaza['ihlaller'] as List<dynamic>) ?depo.ceza('2918:$id')];
    final md84 = depo.madde('2918', '84');
    return Scaffold(
      appBar: AppBar(title: const Text('Kaza örneği')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(kaza['baslik'] as String, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(aspectRatio: 1.25, child: CustomPaint(painter: SahneRessami(kaza['sahne'] as Map<String, dynamic>))),
          ),
          const SizedBox(height: 14),
          Text(kaza['anlatim'] as String, style: const TextStyle(height: 1.5, fontSize: 15)),
          const Bolum('Kusur durumu'),
          for (final tr in taraflar)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: SahneRessami.aracRengi(tr['ad'] as String),
                        child: Text((tr['ad'] as String).characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${tr['ad']}: ${tr['durum']}',
                                style: TextStyle(fontWeight: FontWeight.w800, color: (tr['durum'] as String).contains('atfedilemez') ? Colors.green.shade700 : renk.error)),
                            const SizedBox(height: 2),
                            Text(tr['gerekce'] as String),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Bolum('Dayanak'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: renk.primaryContainer, borderRadius: BorderRadius.circular(14)),
            child: Text(kaza['asliKusur'] as String, style: TextStyle(fontWeight: FontWeight.w600, color: renk.onPrimaryContainer, height: 1.4)),
          ),
          if (md84 != null) ...[const SizedBox(height: 8), MaddeSatiri(md84)],
          if (ihlaller.isNotEmpty) ...[
            const Bolum('İlgili ihlal ve cezalar'),
            for (final c in ihlaller) Padding(padding: const EdgeInsets.only(bottom: 8), child: CezaSatiri(c)),
          ],
        ],
      ),
    );
  }
}

/// Kaza sahnesini veri dosyasındaki tarifle çizer: yol tipi, araçlar, hareket okları, çarpışma noktası.
/// Koordinatlar 0-1 aralığında; yön derece cinsinden (0 yukarı, 90 sağ).
class SahneRessami extends CustomPainter {
  SahneRessami(this.sahne, {this.kucuk = false});
  final Map<String, dynamic> sahne;
  final bool kucuk;

  static Color aracRengi(String ad) => switch (ad) {
        'A' => const Color(0xFFD32F2F),
        'B' => const Color(0xFF1565C0),
        'C' => const Color(0xFF6D4C41),
        _ => const Color(0xFF00796B),
      };

  @override
  void paint(Canvas canvas, Size b) {
    Offset n(num x, num y) => Offset(x * b.width, y * b.height);
    final zemin = Paint()..color = const Color(0xFF7CB342);
    final asfalt = Paint()..color = const Color(0xFF455A64);
    final cizgi = Paint()
      ..color = Colors.white
      ..strokeWidth = math.max(1.5, b.width * 0.008);
    canvas.drawRect(Offset.zero & b, zemin);

    void kesikli(Offset a, Offset c) {
      final uzunluk = (c - a).distance;
      final yon = (c - a) / uzunluk;
      final adim = b.height * 0.06;
      for (var d = 0.0; d < uzunluk; d += adim) {
        canvas.drawLine(a + yon * d, a + yon * math.min(d + adim * 0.55, uzunluk), cizgi);
      }
    }

    final yol = sahne['yol'] as String;
    switch (yol) {
      case 'kavsak':
        canvas.drawRect(Rect.fromLTRB(b.width * 0.36, 0, b.width * 0.64, b.height), asfalt);
        canvas.drawRect(Rect.fromLTRB(0, b.height * 0.36, b.width, b.height * 0.64), asfalt);
        kesikli(n(0.5, 0), n(0.5, 0.36));
        kesikli(n(0.5, 0.64), n(0.5, 1));
        kesikli(n(0, 0.5), n(0.36, 0.5));
        kesikli(n(0.64, 0.5), n(1, 0.5));
      case 'bolunmus':
        canvas.drawRect(Rect.fromLTRB(b.width * 0.14, 0, b.width * 0.46, b.height), asfalt);
        canvas.drawRect(Rect.fromLTRB(b.width * 0.54, 0, b.width * 0.86, b.height), asfalt);
        kesikli(n(0.3, 0), n(0.3, 1));
        kesikli(n(0.7, 0), n(0.7, 1));
      case 'dar':
        canvas.drawRect(Rect.fromLTRB(b.width * 0.4, 0, b.width * 0.6, b.height), asfalt);
      default:
        canvas.drawRect(Rect.fromLTRB(b.width * 0.3, 0, b.width * (yol == 'tekyon' ? 0.82 : 0.7), b.height), asfalt);
        if (yol == 'tekyon') {
          canvas.drawLine(n(0.7, 0), n(0.7, 1), cizgi);
          kesikli(n(0.5, 0), n(0.5, 1));
        } else {
          canvas.drawLine(n(0.5, 0), n(0.5, 1), cizgi..strokeWidth = cizgi.strokeWidth * 1.2);
        }
    }

    final gecit = sahne['gecit'] as num?;
    if (gecit != null) {
      for (var x = 0.32; x < 0.69; x += 0.05) {
        canvas.drawRect(Rect.fromLTWH(b.width * x, b.height * (gecit - 0.04), b.width * 0.028, b.height * 0.08), Paint()..color = Colors.white);
      }
    }
    if (sahne['isik'] == true) {
      final m = n(0.7, 0.72);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: m, width: b.width * 0.05, height: b.height * 0.13), const Radius.circular(4)), Paint()..color = Colors.black87);
      canvas.drawCircle(m.translate(0, -b.height * 0.035), b.width * 0.016, Paint()..color = Colors.red);
      canvas.drawCircle(m.translate(0, b.height * 0.035), b.width * 0.016, Paint()..color = Colors.green.shade900);
    }
    final levha = sahne['levha'] as List<dynamic>?;
    if (levha != null) {
      final m = n(levha[0] as num, levha[1] as num);
      canvas.drawCircle(m, b.width * 0.045, Paint()..color = Colors.red.shade700);
      if (!kucuk) _yazi(canvas, 'DUR', m, b.width * 0.03, Colors.white);
    }

    // Kullanıcının çizdiği fren ve savrulma izleri: [x0, y0, x1, y1, …] noktalarından oluşan çizgiler.
    for (final c in (sahne['cizgiler'] as List<dynamic>?) ?? const []) {
      final noktalar = (c as List<dynamic>).cast<num>();
      if (noktalar.length < 4) continue;
      final iz = Path()..moveTo(noktalar[0] * b.width, noktalar[1] * b.height);
      for (var i = 2; i + 1 < noktalar.length; i += 2) {
        iz.lineTo(noktalar[i] * b.width, noktalar[i + 1] * b.height);
      }
      canvas.drawPath(
          iz,
          Paint()
            ..color = Colors.black87
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.5, b.width * 0.014)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
    }

    final araclar = (sahne['araclar'] as List<dynamic>).cast<Map<String, dynamic>>();
    for (final a in araclar) {
      final hedef = a['hedef'] as List<dynamic>?;
      if (hedef == null) continue;
      final renk = aracRengi(a['ad'] as String);
      final kalem = Paint()
        ..color = renk.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, b.width * 0.012)
        ..strokeCap = StrokeCap.round;
      final bas = n(a['x'] as num, a['y'] as num);
      final ara = a['ara'] as List<dynamic>?;
      final son = n(hedef[0] as num, hedef[1] as num);
      final onceki = ara == null ? bas : n(ara[0] as num, ara[1] as num);
      final yolCizgisi = Path()..moveTo(bas.dx, bas.dy);
      if (ara != null) yolCizgisi.lineTo(onceki.dx, onceki.dy);
      yolCizgisi.lineTo(son.dx, son.dy);
      canvas.drawPath(yolCizgisi, kalem);
      final aci = math.atan2(son.dy - onceki.dy, son.dx - onceki.dx);
      final uc = b.width * 0.035;
      for (final s in [-1, 1]) {
        canvas.drawLine(son, son - Offset(math.cos(aci + s * 0.5), math.sin(aci + s * 0.5)) * uc, kalem);
      }
    }

    for (final a in araclar) {
      final ad = a['ad'] as String;
      final m = n(a['x'] as num, a['y'] as num);
      canvas.save();
      canvas.translate(m.dx, m.dy);
      canvas.rotate((a['yon'] as num) * math.pi / 180);
      // Araç türü gövdenin boyunu belirler; tür yazılmamışsa otomobil çizilir.
      final (en, boy) = switch (a['tur']) {
        'kamyon' => (0.1, 0.27),
        'motosiklet' => (0.04, 0.12),
        _ => (0.085, 0.17),
      };
      final govde = Rect.fromCenter(center: Offset.zero, width: b.width * en, height: b.height * boy);
      canvas.drawRRect(RRect.fromRectAndRadius(govde, Radius.circular(b.width * 0.02)), Paint()..color = aracRengi(ad));
      // Ön cam aracın yönünü gösterir.
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(govde.left + govde.width * 0.15, govde.top + govde.height * 0.14, govde.width * 0.7, govde.height * 0.2), const Radius.circular(2)),
          Paint()..color = Colors.white70);
      canvas.restore();
      _yazi(canvas, a['park'] == true ? '$ad·P' : ad, m.translate(0, b.height * 0.02), b.width * (kucuk ? 0.06 : 0.04), Colors.white);
    }

    final yaya = sahne['yaya'] as List<dynamic>?;
    if (yaya != null) {
      final m = n(yaya[0] as num, yaya[1] as num);
      canvas.drawCircle(m, b.width * 0.028, Paint()..color = Colors.orange.shade800);
      canvas.drawCircle(m, b.width * 0.028, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }

    final carpisma = sahne['carpisma'] as List<dynamic>?;
    if (carpisma != null) {
      final m = n(carpisma[0] as num, carpisma[1] as num);
      final yildiz = Path();
      for (var i = 0; i < 16; i++) {
        final r = b.width * (i.isEven ? 0.06 : 0.028);
        final p = m + Offset(math.cos(i * math.pi / 8), math.sin(i * math.pi / 8)) * r;
        i == 0 ? yildiz.moveTo(p.dx, p.dy) : yildiz.lineTo(p.dx, p.dy);
      }
      yildiz.close();
      canvas.drawPath(yildiz, Paint()..color = const Color(0xFFFFC107));
      canvas.drawPath(yildiz, Paint()..color = const Color(0xFFE65100)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  void _yazi(Canvas canvas, String metin, Offset merkez, double punto, Color renk) {
    final tp = TextPainter(
      text: TextSpan(text: metin, style: TextStyle(color: renk, fontSize: punto, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, merkez - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(SahneRessami eski) => eski.sahne != sahne;
}

// ---------------------------------------------------------------- kararlar
class KararlarEkrani extends StatelessWidget {
  const KararlarEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Emsal kararlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Uyari('Özetler bilgilendirme amaçlıdır; künyesi verilen kararın tam metni için kaynağa bakın.'),
          const SizedBox(height: 12),
          for (final k in Depo.i.kararlar)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ExpansionTile(
                  shape: const Border(),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: Text(k['konu'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${k['mahkeme']}\nE. ${k['esas']} · K. ${k['karar']} · ${k['tarih']}'),
                  children: [
                    Etiket('Sonuç: ${k['sonuc']}', renk.secondaryContainer, renk.onSecondaryContainer),
                    const SizedBox(height: 10),
                    SelectableText(k['ozet'] as String, style: const TextStyle(height: 1.5)),
                    const SizedBox(height: 10),
                    Uyari('Sahaya yansıması: ${k['ders']}', ikon: Icons.lightbulb_outline),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Kaynağı aç'),
                        onPressed: () => baglantiAc(context, k['url'] as String),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
