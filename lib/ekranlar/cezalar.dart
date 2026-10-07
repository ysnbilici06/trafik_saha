import 'package:flutter/material.dart';

import '../veri/asistan.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'islemler.dart';
import 'ortak.dart';

class CezalarEkrani extends StatefulWidget {
  const CezalarEkrani({super.key});

  @override
  State<CezalarEkrani> createState() => _CezalarEkraniState();
}

class _CezalarEkraniState extends State<CezalarEkrani> {
  String _kanun = '2918';
  String _arama = '';
  final Set<String> _suzgec = {};

  static const _suzgecler = ['Puanlı', 'Belge geri alma', 'Trafikten men', 'Sık kullanılan'];

  List<Ceza> _sonuc() {
    final depo = Depo.i;
    final kelimeler = katla(_arama).split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
    return depo.cezalar.where((c) {
      if (c.kanun != _kanun) return false;
      if (_suzgec.contains('Puanlı') && c.puan == null) return false;
      if (_suzgec.contains('Belge geri alma') && c.belge.isEmpty && c.mahkeme.isEmpty) return false;
      if (_suzgec.contains('Trafikten men') && c.men.isEmpty) return false;
      if (_suzgec.contains('Sık kullanılan') && !depo.favoriMi(c.anahtar)) return false;
      return kelimeler.every(c.arama.contains);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Depo.i,
      builder: (context, _) {
        final sonuc = _sonuc();
        return Scaffold(
          appBar: AppBar(title: const Text('Ceza Rehberi')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _arama = v),
                  decoration: const InputDecoration(
                    hintText: 'Madde no veya ihlal ara (ör. 47/1-b, kemer)',
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
                      ButtonSegment(value: '2918', label: Text('2918 · Trafik')),
                      ButtonSegment(value: '4925', label: Text('4925 · Taşıma')),
                    ],
                    selected: {_kanun},
                    onSelectionChanged: (s) => setState(() => _kanun = s.first),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: [
                    for (final s in _suzgecler)
                      if (_kanun == '2918' || s == 'Sık kullanılan')
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(s),
                            selected: _suzgec.contains(s),
                            visualDensity: VisualDensity.compact,
                            onSelected: (v) => setState(() => v ? _suzgec.add(s) : _suzgec.remove(s)),
                          ),
                        ),
                  ],
                ),
              ),
              Expanded(
                child: sonuc.isEmpty
                    ? const Center(child: Text('Eşleşen ceza kalemi bulunamadı'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: sonuc.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => i == 0
                            ? Text('${sonuc.length} kalem', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))
                            : CezaSatiri(sonuc[i - 1]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CezaDetay extends StatefulWidget {
  const CezaDetay(this.ceza, {super.key});
  final Ceza ceza;

  @override
  State<CezaDetay> createState() => _CezaDetayState();
}

class _CezaDetayState extends State<CezaDetay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Depo.i.bakildi(widget.ceza.anahtar));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.ceza;
    final depo = Depo.i;
    final t = Theme.of(context);
    final renk = t.colorScheme;
    final madde = depo.madde(c.kanun, c.anaMadde);
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text('${c.kanun} · md. ${c.madde}'),
          actions: [
            IconButton(tooltip: 'Kopyala', icon: const Icon(Icons.copy), onPressed: () => kopyala(context, Asistan.cezaOzeti(c))),
            IconButton(
              tooltip: 'Sık kullanılanlara ekle',
              icon: Icon(depo.favoriMi(c.anahtar) ? Icons.star : Icons.star_border),
              onPressed: () => depo.favoriDegistir(c.anahtar),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => islemKaydet(context, c),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('İşlem kaydet'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            if (c.cumle.isNotEmpty) Text(c.cumle, style: TextStyle(color: renk.primary, fontWeight: FontWeight.w700)),
            SelectableText(c.konu, style: t.textTheme.titleMedium?.copyWith(height: 1.35)),
            const SizedBox(height: 16),
            if (c.tutar != null && !c.kademeli)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: renk.primaryContainer, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: [
                    Expanded(child: _Tutar('İdari para cezası', para(c.tutar), renk.onPrimaryContainer, buyuk: true)),
                    if (c.kanun == '2918') Expanded(child: _Tutar('%25 indirimli', para(c.indirimli), renk.onPrimaryContainer)),
                    if (c.ustSinir != null) Expanded(child: _Tutar('Üst sınır', para(c.ustSinir), renk.onPrimaryContainer)),
                  ],
                ),
              ),
            if (c.kademeli)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: renk.primaryContainer, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kademeli ceza', style: TextStyle(fontSize: 12, color: renk.onPrimaryContainer)),
                    const SizedBox(height: 6),
                    SelectableText(c.cezaMetin, style: TextStyle(height: 1.45, fontWeight: FontWeight.w600, color: renk.onPrimaryContainer)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: [
                    if (c.kime.isNotEmpty) BilgiSatiri('Kime uygulanır', c.kime),
                    if (c.puan != null) BilgiSatiri('Ceza puanı', '${c.puan}'),
                    if (c.altSinir != null) BilgiSatiri('Alt sınır', para(c.altSinir)),
                    if (c.mulkiAmir.isNotEmpty) BilgiSatiri('Mülki amirce', c.mulkiAmir),
                    if (c.belge.isNotEmpty) BilgiSatiri('Belge geri alma (trafik kolluğu)', c.belge),
                    if (c.mahkeme.isNotEmpty) BilgiSatiri('Belge işlemi (mahkeme)', c.mahkeme),
                    if (c.men.isNotEmpty) BilgiSatiri('Trafikten men', c.men),
                    if (c.kullanmaktanMen.isNotEmpty) BilgiSatiri('Araç kullanmaktan men', c.kullanmaktanMen),
                  ],
                ),
              ),
            ),
            if (c.diger.isNotEmpty) ...[
              const Bolum('Diğer hususlar'),
              SelectableText(c.diger.replaceAll('\n', ' ').replaceAll(' *', '\n\n*').replaceAll(RegExp(r' (?=\d[-)] )'), '\n'),
                  style: const TextStyle(height: 1.45)),
            ],
            if (madde != null) ...[const Bolum('Kanun maddesi'), MaddeSatiri(madde)],
            const SizedBox(height: 16),
            Uyari(c.kanun == '2918'
                ? 'Kaynak: EGM Trafik Başkanlığı Trafik İdari Para Ceza Rehberi.'
                : 'Kaynak: Ulaştırma ve Altyapı Bakanlığı, 4925 sayılı Kanun md. 26 idari para cezaları tablosu.'),
          ],
        ),
      ),
    );
  }
}

class _Tutar extends StatelessWidget {
  const _Tutar(this.baslik, this.deger, this.renk, {this.buyuk = false});
  final String baslik;
  final String deger;
  final Color renk;
  final bool buyuk;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(baslik, style: TextStyle(fontSize: 12, color: renk)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(deger, style: TextStyle(fontSize: buyuk ? 24 : 18, fontWeight: FontWeight.w800, color: renk)),
        ),
      ],
    );
  }
}
