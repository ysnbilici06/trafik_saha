import 'package:flutter/material.dart';

import '../veri/depo.dart';
import '../veri/hava.dart';
import '../veri/modeller.dart';
import 'ek_araclar.dart';
import 'ortak.dart';

const kazaTurleri = ['Maddi hasarlı', 'Yaralanmalı', 'Ölümlü'];
const _zeminler = ['Kuru', 'Islak', 'Karlı', 'Buzlu'];

String _koordinat(Map<String, dynamic> k) => k['enlem'] == null
    ? ''
    : '${(k['enlem'] as num).toStringAsFixed(6)}, ${(k['boylam'] as num).toStringAsFixed(6)}';

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
  if (alan('araclar').isNotEmpty) b.writeln('Araçlar: ${alan('araclar')}');
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
                              [k['yer'], _koordinat(k), k['araclar']].where((e) => (e as String? ?? '').isNotEmpty).join('\n'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(tooltip: 'Metni kopyala', icon: const Icon(Icons.copy), onPressed: () => kopyala(context, kazaMetni(k))),
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
  late final _araclar = TextEditingController(text: _k['araclar'] as String? ?? '');
  late final _hava = TextEditingController(text: _k['hava'] as String? ?? '');
  late final _aciklama = TextEditingController(text: _k['aciklama'] as String? ?? '');
  bool _konumAliniyor = false;
  bool _havaAliniyor = false;

  @override
  void dispose() {
    for (final c in [_yer, _araclar, _hava, _aciklama]) {
      c.dispose();
    }
    super.dispose();
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
    await Depo.i.kazaKaydet({
      ..._k,
      'yer': _yer.text.trim(),
      'araclar': _araclar.text.trim().toUpperCase(),
      'hava': _hava.text.trim(),
      'aciklama': _aciklama.text.trim(),
    });
    if (mounted) {
      bildir(context, 'Kaza kaydı kaydedildi');
      Navigator.pop(context);
    }
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
              onPressed: () async {
                final onay = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Kaza kaydı silinsin mi?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
                    ],
                  ),
                );
                if (onay == true) {
                  await Depo.i.kazaKaydiSil(id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
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
          TextField(
            controller: _araclar,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Karışan araçlar (plakalar)'),
          ),
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
          FilledButton.icon(icon: const Icon(Icons.save), label: const Padding(padding: EdgeInsets.all(10), child: Text('Kaydet')), onPressed: _kaydet),
          const SizedBox(height: 12),
          const Uyari('Kayıt yalnızca bu cihazda saklanır ve resmî kaza tespit tutanağının yerine geçmez. '
              'Hava durumu düğmesi, kaza yerinin yaklaşık koordinatını Open-Meteo servisine gönderir.', ikon: Icons.lock_outline),
        ],
      ),
    );
  }
}
