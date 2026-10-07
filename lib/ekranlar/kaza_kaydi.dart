import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../veri/depo.dart';
import '../veri/foto_deposu.dart';
import '../veri/hava.dart';
import '../veri/modeller.dart';
import 'ek_araclar.dart';
import 'egitim.dart';
import 'ortak.dart';
import 'yeni_araclar.dart';

const kazaTurleri = ['Maddi hasarlı', 'Yaralanmalı', 'Ölümlü'];
const kazaTaraflari = ['Tek taraflı', 'Çift taraflı'];

/// Kayıttaki plakalar; 'araclar' alanı virgülle ayrılmış tek metin olarak saklanır.
List<String> kazaPlakalari(Map<String, dynamic> k) => [
      for (final p in (k['araclar'] as String? ?? '').split(RegExp(r'[,;\n]')))
        if (p.trim().isNotEmpty) p.trim(),
    ];

/// Kazanın tek mi çift taraflı mı olduğu; alan eklenmeden önceki kayıtlarda plaka sayısından çıkarılır.
String? kazaTarafi(Map<String, dynamic> k) {
  final t = k['taraf'] as String?;
  if (t != null) return t;
  final n = kazaPlakalari(k).length;
  return n == 0 ? null : kazaTaraflari[n > 1 ? 1 : 0];
}
const _zeminler = ['Kuru', 'Islak', 'Karlı', 'Buzlu'];

String _koordinat(Map<String, dynamic> k) => k['enlem'] == null
    ? ''
    : '${(k['enlem'] as num).toStringAsFixed(6)}, ${(k['boylam'] as num).toStringAsFixed(6)}';

/// Kayda eklenmiş fotoğrafların [FotoDeposu] kimlikleri.
List<String> kazaFotolari(Map<String, dynamic> k) => ((k['fotolar'] as List<dynamic>?) ?? []).cast<String>();

/// Onay sorup kaza kaydını fotoğraflarıyla birlikte siler; silindiyse true döner.
Future<bool> _kazaKaydiniSil(BuildContext context, Map<String, dynamic> k) async {
  final fotolar = kazaFotolari(k);
  final onay = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Kaza kaydı silinsin mi?'),
      content: Text(fotolar.isEmpty
          ? 'Silinen kayıt geri getirilemez.'
          : 'Kayıt ve ${fotolar.length} fotoğrafı silinir; geri getirilemez.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
      ],
    ),
  );
  if (onay != true) return false;
  await Depo.i.kazaKaydiSil(k['id'] as String);
  await FotoDeposu.sil(fotolar);
  if (context.mounted) bildir(context, 'Kaza kaydı silindi');
  return true;
}

/// Kaza kaydını tutanağa veya mesaja yapıştırılabilecek düz metne çevirir.
String kazaMetni(Map<String, dynamic> k) {
  String alan(String ad) => (k[ad] as String? ?? '').trim();
  final b = StringBuffer('TRAFİK KAZASI KAYDI\n');
  b.writeln('Tarih/saat: ${tarihYaz(DateTime.parse(k['zaman'] as String), saat: true)}');
  b.writeln('Tür: ${k['tur']}');
  if (k['enlem'] != null) {
    b.writeln('Koordinat: ${_koordinat(k)}${k['dogruluk'] == null ? '' : ' (± ${(k['dogruluk'] as num).round()} m)'}');
    b.writeln('Harita: https://www.google.com/maps/search/?api=1&query=${k['enlem']},${k['boylam']}');
  }
  if (alan('yer').isNotEmpty) b.writeln('Yer: ${alan('yer')}');
  final taraf = kazaTarafi(k);
  if (taraf != null) b.writeln('Kaza şekli: $taraf');
  if (alan('araclar').isNotEmpty) b.writeln('${taraf == kazaTaraflari.first ? 'Araç' : 'Araçlar'}: ${alan('araclar')}');
  if (alan('olus').isNotEmpty) b.writeln('Oluş: ${alan('olus')}');
  final yarali = k['yarali'] as int? ?? 0;
  final olu = k['olu'] as int? ?? 0;
  if (yarali + olu > 0) b.writeln('Yaralı: $yarali · Ölü: $olu');
  if (alan('zemin').isNotEmpty) b.writeln('Zemin: ${alan('zemin')}');
  if (alan('hava').isNotEmpty) b.writeln('Hava: ${alan('hava')}');
  if (alan('aciklama').isNotEmpty) b.writeln('Açıklama: ${alan('aciklama')}');
  return b.toString().trimRight();
}

class KazaKayitlariEkrani extends StatelessWidget {
  const KazaKayitlariEkrani({super.key});

  static Color turRengi(String tur) => switch (tur) {
        'Ölümlü' => Renkler.kirmizi,
        'Yaralanmalı' => Renkler.turuncu,
        _ => Renkler.mavi,
      };

  static const _baslik = SayfaBasligi(Icons.add_location_alt, Renkler.kirmizi, 'Kaza kayıtlarım', 'Kaza yeri koordinatı, saat, araçlar ve ilk tespitler');

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final kayitlar = depo.kazaKayitlari;
        return Scaffold(
          appBar: AppBar(title: const Text('Kaza kayıtlarım')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => git(context, const KazaKaydiDuzenle(null)),
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Yeni kaza kaydı'),
          ),
          body: kayitlar.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: const [
                    _baslik,
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Henüz kaza kaydı yok.\nKaza yerinde koordinatı, saati ve temel bilgileri tek ekranda kaydedin.', textAlign: TextAlign.center),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    _baslik,
                    for (final k in kayitlar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            leading: RenkliIkon(Icons.car_crash, turRengi(k['tur'] as String)),
                            title: Text('${k['tur']} · ${tarihYaz(DateTime.parse(k['zaman'] as String), saat: true)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              [k['yer'], _koordinat(k), [kazaTarafi(k), k['araclar']].where((e) => (e as String? ?? '').isNotEmpty).join(' · '), if (kazaFotolari(k).isNotEmpty) '${kazaFotolari(k).length} fotoğraf'].where((e) => (e as String? ?? '').isNotEmpty).join('\n'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(tooltip: 'Metni kopyala', icon: const Icon(Icons.copy), onPressed: () => kopyala(context, kazaMetni(k))),
                                IconButton(
                                  tooltip: 'Kaydı sil',
                                  icon: const Icon(Icons.delete_outline, color: Renkler.kirmizi),
                                  onPressed: () => _kazaKaydiniSil(context, k),
                                ),
                              ],
                            ),
                            onTap: () => git(context, KazaKaydiDuzenle(k)),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class KazaKaydiDuzenle extends StatefulWidget {
  const KazaKaydiDuzenle(this.kayit, {super.key});
  final Map<String, dynamic>? kayit;

  @override
  State<KazaKaydiDuzenle> createState() => _KazaKaydiDuzenleState();
}

class _KazaKaydiDuzenleState extends State<KazaKaydiDuzenle> {
  late final Map<String, dynamic> _k = {
    'zaman': DateTime.now().toIso8601String(),
    'tur': kazaTurleri.first,
    'yarali': 0,
    'olu': 0,
    'zemin': '',
    ...?widget.kayit,
  };
  late final _yer = TextEditingController(text: _k['yer'] as String? ?? '');
  late String? _taraf = kazaTarafi(_k);
  late final _plaka1 = TextEditingController(text: kazaPlakalari(_k).firstOrNull ?? '');
  late final _plaka2 = TextEditingController(text: kazaPlakalari(_k).skip(1).join(', '));
  late final _olus = TextEditingController(text: _k['olus'] as String? ?? '');
  late final _hava = TextEditingController(text: _k['hava'] as String? ?? '');
  late final _aciklama = TextEditingController(text: _k['aciklama'] as String? ?? '');
  late final List<String> _fotolar = kazaFotolari(_k).toList();

  /// Bu oturumda eklenen ve çıkarılan fotoğraflar; kayıt kaydedilmeden çıkılırsa eklenenler,
  /// kaydedilirse çıkarılanlar depodan silinir.
  final _eklenen = <String>{};
  final _cikarilan = <String>{};
  final _fotoVerisi = <String, Future<Uint8List?>>{};
  bool _kaydedildi = false;
  bool _fotoEkleniyor = false;
  bool _konumAliniyor = false;
  bool _havaAliniyor = false;

  @override
  void dispose() {
    if (!_kaydedildi) unawaited(FotoDeposu.sil(_eklenen));
    for (final c in [_yer, _plaka1, _plaka2, _olus, _hava, _aciklama]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Uint8List?> _foto(String id) => _fotoVerisi[id] ??= FotoDeposu.oku(id);

  Future<void> _fotoEkle(ImageSource kaynak) async {
    setState(() => _fotoEkleniyor = true);
    try {
      // Küçültme hem yer kazandırır hem de fotoğraftaki konum gibi ek bilgileri atar.
      final secici = ImagePicker();
      final dosyalar = kaynak == ImageSource.camera
          ? [?await secici.pickImage(source: kaynak, maxWidth: 1600, maxHeight: 1600, imageQuality: 80)]
          : await secici.pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
      for (final d in dosyalar) {
        final id = await FotoDeposu.ekle(await d.readAsBytes());
        if (!mounted) {
          await FotoDeposu.sil([id]);
          return;
        }
        _eklenen.add(id);
        setState(() => _fotolar.add(id));
      }
    } catch (_) {
      if (mounted) bildir(context, 'Fotoğraf eklenemedi. Kamera ya da galeri iznini ve boş alanı kontrol edin.');
    } finally {
      if (mounted) setState(() => _fotoEkleniyor = false);
    }
  }

  Future<void> _fotoAc(String id) async {
    final veri = await _foto(id);
    if (veri == null || !mounted) return;
    final sil = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _FotoSayfasi(veri)));
    if (sil != true || !mounted) return;
    setState(() => _fotolar.remove(id));
    if (_eklenen.remove(id)) {
      await FotoDeposu.sil([id]);
    } else {
      _cikarilan.add(id);
    }
  }

  Widget _kucukFoto(String id) {
    final renk = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 96,
        height: 96,
        child: FutureBuilder<Uint8List?>(
          future: _foto(id),
          builder: (context, s) => s.data == null
              ? ColoredBox(
                  color: renk.surfaceContainerHighest,
                  child: Icon(s.connectionState == ConnectionState.done ? Icons.broken_image_outlined : Icons.image_outlined),
                )
              : InkWell(onTap: () => _fotoAc(id), child: Image.memory(s.data!, fit: BoxFit.cover, cacheWidth: 240)),
        ),
      ),
    );
  }

  DateTime get _zaman => DateTime.parse(_k['zaman'] as String);

  Future<void> _koordinatAl() async {
    setState(() => _konumAliniyor = true);
    try {
      final p = await konumAl();
      setState(() {
        _k['enlem'] = p.latitude;
        _k['boylam'] = p.longitude;
        _k['dogruluk'] = p.accuracy;
      });
    } on KonumHatasi catch (e) {
      if (mounted) bildir(context, e.mesaj);
    } finally {
      if (mounted) setState(() => _konumAliniyor = false);
    }
  }

  Future<void> _havaEkle() async {
    final enlem = (_k['enlem'] ?? Depo.i.havaYeri?['enlem']) as num?;
    final boylam = (_k['boylam'] ?? Depo.i.havaYeri?['boylam']) as num?;
    if (enlem == null || boylam == null) {
      bildir(context, 'Önce koordinatı alın ya da ana sayfadan görev yerinizi seçin.');
      return;
    }
    setState(() => _havaAliniyor = true);
    try {
      final h = Hava.fromJson(await havaIndir(enlem.toDouble(), boylam.toDouble()));
      setState(() => _hava.text = havaOzeti(h));
    } catch (_) {
      if (mounted) bildir(context, 'Hava durumu alınamadı.');
    } finally {
      if (mounted) setState(() => _havaAliniyor = false);
    }
  }

  Future<void> _zamanSec() async {
    final gun = await showDatePicker(context: context, initialDate: _zaman, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (gun == null || !mounted) return;
    final saat = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_zaman));
    if (saat == null) return;
    setState(() => _k['zaman'] = DateTime(gun.year, gun.month, gun.day, saat.hour, saat.minute).toIso8601String());
  }

  Future<void> _kaydet() async {
    if (_taraf == null) {
      bildir(context, 'Kazanın tek taraflı mı çift taraflı mı olduğunu seçin.');
      return;
    }
    final cift = _taraf == kazaTaraflari.last;
    await Depo.i.kazaKaydet({
      ..._k,
      'yer': _yer.text.trim(),
      'taraf': _taraf,
      'araclar': [_plaka1.text, if (cift) _plaka2.text].map((p) => p.trim().toUpperCase()).where((p) => p.isNotEmpty).join(', '),
      // Oluş şekli yalnızca tek taraflı kazada sorulur.
      'olus': cift ? '' : _olus.text.trim(),
      'hava': _hava.text.trim(),
      'aciklama': _aciklama.text.trim(),
      'fotolar': _fotolar,
    });
    _kaydedildi = true;
    await FotoDeposu.sil(_cikarilan);
    if (mounted) {
      bildir(context, 'Kaza kaydı kaydedildi');
      Navigator.pop(context);
    }
  }

  Future<void> _sil() async {
    if (await _kazaKaydiniSil(context, widget.kayit!) && mounted) Navigator.pop(context);
  }

  Widget _sayac(String ad, String alan) {
    final deger = _k[alan] as int? ?? 0;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(child: Text(ad, style: const TextStyle(fontWeight: FontWeight.w600))),
              IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: deger == 0 ? null : () => setState(() => _k[alan] = deger - 1)),
              Text('$deger', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _k[alan] = deger + 1)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final id = widget.kayit?['id'] as String?;
    final varKonum = _k['enlem'] != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(id == null ? 'Yeni kaza kaydı' : 'Kaza kaydı'),
        actions: [
          if (id != null)
            IconButton(
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: _sil,
            ),
          IconButton(tooltip: 'Kaydet', icon: const Icon(Icons.check), onPressed: _kaydet),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFC62828), Color(0xFFEF6C00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kaza yeri koordinatı', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 4),
                SelectableText(varKonum ? _koordinat(_k) : 'Henüz alınmadı',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                if (_k['dogruluk'] != null)
                  Text('Doğruluk ± ${(_k['dogruluk'] as num).round()} m', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFC62828)),
                      icon: _konumAliniyor
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location, size: 18),
                      label: Text(varKonum ? 'Yeniden al' : 'Koordinatı al'),
                      onPressed: _konumAliniyor ? null : _koordinatAl,
                    ),
                    if (varKonum) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Kopyala'),
                        onPressed: () => kopyala(context, _koordinat(_k)),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Harita'),
                        onPressed: () => baglantiAc(context, 'https://www.google.com/maps/search/?api=1&query=${_k['enlem']},${_k['boylam']}'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.schedule),
              title: const Text('Kaza tarihi ve saati'),
              subtitle: Text(tarihYaz(_zaman, saat: true)),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: _zamanSec,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: [for (final t in kazaTurleri) ButtonSegment(value: t, label: Text(t, style: const TextStyle(fontSize: 12.5)))],
              selected: {_k['tur'] as String},
              onSelectionChanged: (s) => setState(() => _k['tur'] = s.first),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [_sayac('Yaralı', 'yarali'), const SizedBox(width: 8), _sayac('Ölü', 'olu')]),
          const SizedBox(height: 12),
          TextField(controller: _yer, decoration: const InputDecoration(labelText: 'Yer tarifi (yol, km, mevki, yön)')),
          const SizedBox(height: 12),
          Text('Kaza tek taraflı mı, çift taraflı mı?', style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant)),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              emptySelectionAllowed: true,
              segments: [for (final t in kazaTaraflari) ButtonSegment(value: t, label: Text(t))],
              selected: {?_taraf},
              onSelectionChanged: (s) => setState(() => _taraf = s.firstOrNull ?? _taraf),
            ),
          ),
          if (_taraf == kazaTaraflari.first) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _plaka1,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Araç plakası'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _olus,
              decoration: const InputDecoration(labelText: 'Oluş şekli (ör. devrilme, yoldan çıkma, bariyere çarpma)'),
            ),
          ],
          if (_taraf == kazaTaraflari.last) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _plaka1,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: '1. araç plakası'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plaka2,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: '2. araç plakası'),
            ),
          ],
          const SizedBox(height: 12),
          Text('Zemin', style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant)),
          Wrap(
            spacing: 8,
            children: [
              for (final z in _zeminler)
                ChoiceChip(label: Text(z), selected: _k['zemin'] == z, onSelected: (s) => setState(() => _k['zemin'] = s ? z : '')),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hava,
            decoration: InputDecoration(
              labelText: 'Hava durumu',
              suffixIcon: _havaAliniyor
                  ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(tooltip: 'Güncel havayı ekle', icon: const Icon(Icons.cloud_download_outlined), onPressed: _havaEkle),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _aciklama, minLines: 3, maxLines: 8, decoration: const InputDecoration(labelText: 'Açıklama / ilk tespitler')),
          const SizedBox(height: 16),
          const Text('Kroki', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_k['kroki'] != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(width: 96, height: 96, child: CustomPaint(painter: SahneRessami(_k['kroki'] as Map<String, dynamic>, kucuk: true))),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.draw),
                      label: Text(_k['kroki'] == null ? 'Kroki çiz' : 'Krokiyi düzenle'),
                      onPressed: () async {
                        final sahne = await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(builder: (_) => KrokiDuzenle(_k['kroki'] == null ? null : {'sahne': _k['kroki']}, kayitIcin: true)),
                        );
                        if (sahne != null) setState(() => _k['kroki'] = sahne);
                      },
                    ),
                    if (_k['kroki'] != null) TextButton(onPressed: () => setState(() => _k.remove('kroki')), child: const Text('Krokiyi kaldır')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('Kaza yeri fotoğrafları${_fotolar.isEmpty ? '' : ' (${_fotolar.length})'}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (_fotoEkleniyor) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),
          if (_fotolar.isNotEmpty) ...[
            Wrap(spacing: 8, runSpacing: 8, children: [for (final id in _fotolar) _kucukFoto(id)]),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Fotoğraf çek'),
                  onPressed: _fotoEkleniyor ? null : () => _fotoEkle(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeriden ekle'),
                  onPressed: _fotoEkleniyor ? null : () => _fotoEkle(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Uyari('Fotoğraflar yalnızca bu cihazda saklanır; hiçbir yere gönderilmez ve uygulamadan paylaşılamaz. '
              'Uygulama ya da tarayıcı verisi silinince, cihaz sıfırlanınca fotoğraflar da silinir.', ikon: Icons.lock_outline),
          const SizedBox(height: 16),
          FilledButton.icon(icon: const Icon(Icons.save), label: const Padding(padding: EdgeInsets.all(10), child: Text('Kaydet')), onPressed: _kaydet),
          if (id != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Renkler.kirmizi, side: const BorderSide(color: Renkler.kirmizi)),
              icon: const Icon(Icons.delete_outline),
              label: const Padding(padding: EdgeInsets.all(10), child: Text('Kaydı sil')),
              onPressed: _sil,
            ),
          ],
          const SizedBox(height: 12),
          const Uyari('Kayıt yalnızca bu cihazda saklanır ve resmî kaza tespit tutanağının yerine geçmez. '
              'Hava durumu düğmesi, kaza yerinin yaklaşık koordinatını Open-Meteo servisine gönderir.', ikon: Icons.lock_outline),
        ],
      ),
    );
  }
}

/// Tek bir kaza fotoğrafını büyük gösterir; silinmesi istenirse true ile kapanır.
/// Paylaşma ya da indirme düğmesi bilerek yoktur.
class _FotoSayfasi extends StatelessWidget {
  const _FotoSayfasi(this.veri);
  final Uint8List veri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Kaza fotoğrafı'),
        actions: [
          IconButton(
            tooltip: 'Fotoğrafı sil',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final onay = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Fotoğraf silinsin mi?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
                  ],
                ),
              );
              if (onay == true && context.mounted) Navigator.pop(context, true);
            },
          ),
        ],
      ),
      body: InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(veri))),
    );
  }
}
