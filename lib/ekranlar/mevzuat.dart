import 'package:flutter/material.dart';

import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'ortak.dart';

class MevzuatEkrani extends StatefulWidget {
  const MevzuatEkrani({super.key});

  @override
  State<MevzuatEkrani> createState() => _MevzuatEkraniState();
}

class _MevzuatEkraniState extends State<MevzuatEkrani> {
  String _kanun = '2918';
  String _arama = '';
  bool _yalnizYerImleri = false;

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final renk = Theme.of(context).colorScheme;
        final q = katla(_arama.trim());
        final sonuc = depo.maddeler.where((m) {
          if (m.kanun != _kanun) return false;
          if (_yalnizYerImleri && !depo.yerImleri.contains(m.anahtar)) return false;
          return q.isEmpty || m.no.toLowerCase() == q || m.arama.contains(q);
        }).toList();
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
                    hintText: 'Madde no veya metin içinde ara',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '2918', label: Text('2918 · Karayolları Trafik')),
                      ButtonSegment(value: '4925', label: Text('4925 · Karayolu Taşıma')),
                    ],
                    selected: {_kanun},
                    onSelectionChanged: (s) => setState(() => _kanun = s.first),
                  ),
                ),
              ),
              Expanded(
                child: sonuc.isEmpty
                    ? const Center(child: Text('Eşleşen madde bulunamadı'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: sonuc.length,
                        itemBuilder: (context, i) {
                          final m = sonuc[i];
                          final yeniKisim = i == 0 || sonuc[i - 1].kisim != m.kisim;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (yeniKisim && m.kisim.isNotEmpty && q.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                                  child: Text(m.kisim, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: renk.primary)),
                                ),
                              Card(
                                child: ListTile(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  leading: CircleAvatar(
                                    backgroundColor: renk.primaryContainer,
                                    child: FittedBox(
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(m.no.replaceAll('Geçici', 'G.'),
                                            style: TextStyle(fontWeight: FontWeight.w700, color: renk.onPrimaryContainer)),
                                      ),
                                    ),
                                  ),
                                  title: Text(m.baslik.isEmpty ? m.etiket : m.baslik, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  subtitle: q.length < 3 ? null : _Kesit(m.metin, q),
                                  trailing: depo.yerImleri.contains(m.anahtar) ? Icon(Icons.bookmark, color: renk.primary, size: 18) : null,
                                  onTap: () => git(context, MaddeDetay(m)),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Arama kelimesinin madde metninde geçtiği yerin kısa kesiti.
class _Kesit extends StatelessWidget {
  const _Kesit(this.metin, this.aranan);
  final String metin;
  final String aranan;

  @override
  Widget build(BuildContext context) {
    final i = katla(metin).indexOf(aranan);
    if (i < 0) return const SizedBox.shrink();
    final bas = (i - 40).clamp(0, metin.length);
    final son = (i + 90).clamp(0, metin.length);
    return Text('…${metin.substring(bas, son).replaceAll('\n', ' ')}…', maxLines: 2, overflow: TextOverflow.ellipsis);
  }
}

class MaddeDetay extends StatelessWidget {
  const MaddeDetay(this.madde, {super.key});
  final Madde madde;

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    final t = Theme.of(context);
    final ilgili = depo.cezalar.where((c) => c.kanun == madde.kanun && c.anaMadde == madde.no).toList();
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text('${madde.kanun} · ${madde.etiket}'),
          actions: [
            IconButton(
              tooltip: 'Kopyala',
              icon: const Icon(Icons.copy),
              onPressed: () => kopyala(context, '${madde.kanun} sayılı Kanun ${madde.etiket} – ${madde.baslik}\n\n${madde.metin}'),
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
            if (madde.kisim.isNotEmpty)
              Text(madde.kisim, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.colorScheme.primary)),
            if (madde.baslik.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(madde.baslik, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ),
            SelectableText(madde.metin.replaceAll('\n', '\n\n'), style: const TextStyle(height: 1.5, fontSize: 15)),
            if (ilgili.isNotEmpty) ...[
              Bolum('Bu maddeye bağlı cezalar (${ilgili.length})'),
              for (final c in ilgili) Padding(padding: const EdgeInsets.only(bottom: 8), child: CezaSatiri(c)),
            ],
            const SizedBox(height: 16),
            const Uyari('Kaynak: mevzuat.gov.tr konsolide kanun metni. Dipnotlar gösterilmez.'),
          ],
        ),
      ),
    );
  }
}
