import 'package:flutter/material.dart';

import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'ortak.dart';

IconData _turIkonu(String tur) => switch (tur) {
      'Kanun' => Icons.gavel,
      'Tebliğ' => Icons.campaign_outlined,
      _ => Icons.menu_book_outlined,
    };

Color _turRengi(String tur) => switch (tur) {
      'Kanun' => Renkler.lacivert,
      'Tebliğ' => Renkler.turuncu,
      _ => Renkler.turkuaz,
    };

/// Aranan kelimelerin hepsi maddede geçiyorsa (ya da madde numarası tam tutuyorsa) doğru.
bool _maddeEslesir(Madde m, List<String> kelimeler, String q) =>
    m.no.toLowerCase() == q || kelimeler.every(m.arama.contains);

/// Mevzuat kitaplığı: bütün kanun, yönetmelik ve tebliğler alt alta; üstteki kutu hepsinin içinde arar.
class MevzuatEkrani extends StatefulWidget {
  const MevzuatEkrani({super.key});

  @override
  State<MevzuatEkrani> createState() => _MevzuatEkraniState();
}

class _MevzuatEkraniState extends State<MevzuatEkrani> {
  /// Bir metinden arama sonucunda en çok kaç madde gösterileceği; fazlası metnin kendi sayfasında açılır.
  static const _metinBasinaSinir = 4;

  String _arama = '';
  bool _yalnizYerImleri = false;
  Future<Map<String, List<Madde>>>? _tumu;

  Future<Map<String, List<Madde>>> get _kitaplik => _tumu ??= Depo.i.kitaplikYukle();

  Widget _metinKarti(Map<String, dynamic> k) {
    final tur = k['tur'] as String;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: RenkliIkon(_turIkonu(tur), _turRengi(tur)),
          title: Text(k['ad'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('$tur · No ${k['no']} · ${k['madde']} madde\nResmî Gazete: ${k['rg']}'),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => git(context, MevzuatMetni(k['kod'] as String)),
        ),
      ),
    );
  }

  List<Widget> _sonuclar(Map<String, List<Madde>> tumu, String q) {
    final depo = Depo.i;
    final renk = Theme.of(context).colorScheme;
    final kelimeler = q.split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
    final satirlar = <Widget>[];
    var maddeSayisi = 0;
    var metinSayisi = 0;

    Widget baslik(String ad, int adet, {VoidCallback? tumunuAc}) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Row(
            children: [
              Expanded(child: Text(ad, style: TextStyle(fontWeight: FontWeight.w800, color: renk.primary))),
              if (tumunuAc != null)
                TextButton(onPressed: tumunuAc, child: Text('Tümü ($adet)'))
              else
                Text('$adet', style: TextStyle(fontWeight: FontWeight.w700, color: renk.onSurfaceVariant)),
            ],
          ),
        );

    final cezaKelimeleri = aramaKelimeleri(q);
    final cezalar = [
      for (final c in depo.cezalar)
        if (c.eslesenler(cezaKelimeleri) case final e?) (c, e),
    ];
    for (final k in depo.kitaplik) {
      final kod = k['kod'] as String;
      final bulunan = [
        for (final m in tumu[kod] ?? const <Madde>[])
          if ((!_yalnizYerImleri || depo.yerImleri.contains(m.anahtar)) && (q.isEmpty || _maddeEslesir(m, kelimeler, q))) m,
      ];
      if (bulunan.isEmpty) continue;
      metinSayisi++;
      maddeSayisi += bulunan.length;
      final sinirli = !_yalnizYerImleri && bulunan.length > _metinBasinaSinir;
      satirlar.add(baslik(k['ad'] as String, bulunan.length, tumunuAc: sinirli ? () => git(context, MevzuatMetni(kod, arama: _arama.trim())) : null));
      for (final m in sinirli ? bulunan.take(_metinBasinaSinir) : bulunan) {
        satirlar.add(_MaddeKarti(m, kelimeler));
      }
    }
    if (!_yalnizYerImleri && cezalar.isNotEmpty) {
      satirlar.add(baslik('Ceza Rehberi', cezalar.length));
      for (final (c, e) in cezalar.take(_metinBasinaSinir * 2)) {
        satirlar.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: CezaSatiri(c, aranan: e)));
      }
      if (cezalar.length > _metinBasinaSinir * 2) {
        satirlar.add(Text('Diğer ${cezalar.length - _metinBasinaSinir * 2} kalem için Cezalar sekmesinde arayın.',
            style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant)));
      }
    }
    if (satirlar.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _yalnizYerImleri ? 'Yer imi eklenmiş madde yok.' : '"${_arama.trim()}" hiçbir mevzuat metninde geçmiyor.',
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
    return [
      if (!_yalnizYerImleri)
        Text(
          '$metinSayisi mevzuatta $maddeSayisi madde${cezalar.isEmpty ? '' : ', ceza rehberinde ${cezalar.length} kalem'}',
          style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant),
        ),
      ...satirlar,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final q = katla(_arama.trim());
        final ariyor = q.length >= 2 || _yalnizYerImleri;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mevzuat'),
            actions: [
              IconButton(
                tooltip: 'Yer imlerim',
                icon: Icon(_yalnizYerImleri ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () => setState(() => _yalnizYerImleri = !_yalnizYerImleri),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _arama = v),
                  decoration: const InputDecoration(
                    hintText: 'Tüm mevzuatta ara (ör. plaka, kış lastiği)',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              Expanded(
                child: !ariyor
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                            child: Text('${depo.kitaplik.length} kanun, yönetmelik ve tebliğ',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ),
                          for (final k in depo.kitaplik) _metinKarti(k),
                          const Uyari('Kaynak: mevzuat.gov.tr konsolide metinleri. Ekler, cetveller ve dipnotlar eksik olabilir; '
                              'resmî işlemde kaynağındaki metne bakın.'),
                        ],
                      )
                    : FutureBuilder<Map<String, List<Madde>>>(
                        future: _kitaplik,
                        builder: (context, s) => s.data == null
                            ? const Center(child: CircularProgressIndicator())
                            : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: _sonuclar(s.data!, q)),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Madde numarası, başlığı ve (arama varsa) eşleşen yerin kesitiyle tek satırlık kart.
class _MaddeKarti extends StatelessWidget {
  const _MaddeKarti(this.madde, this.kelimeler);
  final Madde madde;
  final List<String> kelimeler;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final kesit = kelimeler.isEmpty ? null : eslesmeKesiti(madde.metin, kelimeler);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: CircleAvatar(
            backgroundColor: renk.primaryContainer,
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(madde.no.replaceAll('Geçici', 'G.'), style: TextStyle(fontWeight: FontWeight.w700, color: renk.onPrimaryContainer)),
              ),
            ),
          ),
          title: Text.rich(isaretliMetin(madde.baslik.isEmpty ? madde.etiket : madde.baslik, kelimeler), maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: kesit == null ? null : Text.rich(isaretliMetin(kesit, kelimeler), maxLines: 3, overflow: TextOverflow.ellipsis),
          trailing: Depo.i.yerImleri.contains(madde.anahtar) ? Icon(Icons.bookmark, color: renk.primary, size: 18) : null,
          onTap: () => git(context, MaddeDetay(madde, aranan: kelimeler)),
        ),
      ),
    );
  }
}

/// Tek bir mevzuat metninin maddeleri; kendi içinde arama yapılabilir.
class MevzuatMetni extends StatefulWidget {
  const MevzuatMetni(this.kod, {super.key, this.arama = ''});
  final String kod;
  final String arama;

  @override
  State<MevzuatMetni> createState() => _MevzuatMetniState();
}

class _MevzuatMetniState extends State<MevzuatMetni> {
  late final _kutu = TextEditingController(text: widget.arama);
  late final Future<List<Madde>> _maddeler = Depo.i.mevzuatMaddeleri(widget.kod);

  @override
  void dispose() {
    _kutu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    final bilgi = depo.mevzuatBilgisi(widget.kod);
    final renk = Theme.of(context).colorScheme;
    final q = katla(_kutu.text.trim());
    final kelimeler = q.split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(depo.mevzuatAdi(widget.kod), maxLines: 2, style: const TextStyle(fontSize: 16)),
          actions: [
            if (bilgi != null)
              IconButton(tooltip: 'Kaynağı aç', icon: const Icon(Icons.open_in_new), onPressed: () => baglantiAc(context, bilgi['kaynak'] as String)),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _kutu,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Bu metinde madde no veya kelime ara',
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Madde>>(
                future: _maddeler,
                builder: (context, s) {
                  if (s.data == null) return const Center(child: CircularProgressIndicator());
                  final sonuc = [
                    for (final m in s.data!)
                      if (q.isEmpty || _maddeEslesir(m, kelimeler, q)) m,
                  ];
                  if (sonuc.isEmpty) return const Center(child: Text('Eşleşen madde bulunamadı'));
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: sonuc.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Text(
                            '${bilgi == null ? '' : '${bilgi['tur']} · Resmî Gazete: ${bilgi['rg']} · '}${sonuc.length} madde',
                            style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant),
                          ),
                        );
                      }
                      final m = sonuc[i - 1];
                      final yeniKisim = i == 1 || sonuc[i - 2].kisim != m.kisim;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (yeniKisim && m.kisim.isNotEmpty && q.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                              child: Text(m.kisim, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: renk.primary)),
                            ),
                          _MaddeKarti(m, kelimeler),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MaddeDetay extends StatelessWidget {
  const MaddeDetay(this.madde, {super.key, this.aranan = const []});
  final Madde madde;

  /// Aramadan gelindiyse metinde işaretlenecek kelimeler.
  final List<String> aranan;

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    final t = Theme.of(context);
    final ad = depo.mevzuatAdi(madde.kanun);
    final ilgili = depo.cezalar.where((c) => c.kanun == madde.kanun && c.anaMadde == madde.no).toList();
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(madde.etiket),
          actions: [
            IconButton(
              tooltip: 'Kopyala',
              icon: const Icon(Icons.copy),
              onPressed: () => kopyala(context, '$ad ${madde.etiket} – ${madde.baslik}\n\n${madde.metin}'),
            ),
            IconButton(
              tooltip: 'Yer imi',
              icon: Icon(depo.yerImleri.contains(madde.anahtar) ? Icons.bookmark : Icons.bookmark_border),
              onPressed: () => depo.yerImiDegistir(madde.anahtar),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Text(ad, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: t.colorScheme.primary)),
            if (madde.kisim.isNotEmpty)
              Text(madde.kisim, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.colorScheme.onSurfaceVariant)),
            if (madde.baslik.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(madde.baslik, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ),
            SelectableText.rich(isaretliMetin(madde.metin.replaceAll('\n', '\n\n'), aranan), style: const TextStyle(height: 1.5, fontSize: 15)),
            if (ilgili.isNotEmpty) ...[
              Bolum('Bu maddeye bağlı cezalar (${ilgili.length})'),
              for (final c in ilgili) Padding(padding: const EdgeInsets.only(bottom: 8), child: CezaSatiri(c)),
            ],
            const SizedBox(height: 16),
            const Uyari('Kaynak: mevzuat.gov.tr konsolide metni. Dipnotlar, ekler ve cetveller eksik olabilir.'),
          ],
        ),
      ),
    );
  }
}
