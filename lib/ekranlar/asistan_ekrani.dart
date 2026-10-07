import 'package:flutter/material.dart';

import '../veri/asistan.dart';
import '../veri/depo.dart';
import 'egitim.dart';
import 'ortak.dart';

/// Asistanla yazışma ekranı. Cevaplar cihazdaki resmî veriden üretilir.
class AsistanEkrani extends StatefulWidget {
  const AsistanEkrani({super.key, this.ilkSoru});
  final String? ilkSoru;

  @override
  State<AsistanEkrani> createState() => _AsistanEkraniState();
}

class _AsistanEkraniState extends State<AsistanEkrani> {
  final _asistan = Asistan(Depo.i);
  final _girdi = TextEditingController();
  final _kaydirma = ScrollController();

  /// Soru (String) ve cevap (Cevap) sırasıyla tutulur.
  final List<Object> _mesajlar = [];

  static const _oneriler = [
    'Kırmızı ışık cezası',
    'Yerleşim dışı 110 sınırında 150',
    'Muayenesiz araç',
    'Alkol ölçümünü reddetme',
    '100 puan dolarsa ne olur?',
    'Sola dönerken çarpışma kusur',
    'SRC belgesi olmadan taşıma',
    'Takip mesafesi',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.ilkSoru != null) _sor(widget.ilkSoru!);
  }

  @override
  void dispose() {
    _girdi.dispose();
    _kaydirma.dispose();
    super.dispose();
  }

  Future<void> _sor(String soru) async {
    final temiz = soru.trim();
    if (temiz.isEmpty) return;
    // Yönetmelik ve tebliğlerden de cevap verebilmek için kitaplık ilk soruda yüklenir.
    _asistan.kitaplik ??= await Depo.i.kitaplikYukle();
    if (!mounted) return;
    setState(() {
      _mesajlar
        ..add(temiz)
        ..add(_asistan.cevapla(temiz));
      _girdi.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_kaydirma.hasClients) {
        _kaydirma.animateTo(_kaydirma.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trafik Asistanı'),
        actions: [
          if (_mesajlar.isNotEmpty)
            IconButton(tooltip: 'Sohbeti temizle', icon: const Icon(Icons.delete_sweep_outlined), onPressed: () => setState(_mesajlar.clear)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _mesajlar.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Icon(Icons.auto_awesome, size: 44, color: renk.primary),
                      const SizedBox(height: 12),
                      Text('Merhaba, aklınızdaki ne?',
                          textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Konuşur gibi yazın. Rakamları ceza rehberinden ve kanun metninden veririm, altına da kendi yorumumu eklerim.',
                          textAlign: TextAlign.center, style: TextStyle(color: renk.onSurfaceVariant)),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [for (final o in _oneriler) ActionChip(label: Text(o), onPressed: () => _sor(o))],
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _kaydirma,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _mesajlar.length,
                    itemBuilder: (context, i) {
                      final m = _mesajlar[i];
                      return m is Cevap ? _CevapBalonu(m) : _SoruBalonu(m as String);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _girdi,
                      autofocus: widget.ilkSoru == null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sor,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'Sorunuzu yazın…', contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(icon: const Icon(Icons.send), onPressed: () => _sor(_girdi.text)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoruBalonu extends StatelessWidget {
  const _SoruBalonu(this.metin);
  final String metin;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 48, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: renk.primary, borderRadius: BorderRadius.circular(18)),
        child: Text(metin, style: TextStyle(color: renk.onPrimary)),
      ),
    );
  }
}

class _CevapBalonu extends StatelessWidget {
  const _CevapBalonu(this.cevap);
  final Cevap cevap;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 16, bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: renk.surfaceContainerHigh, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(cevap.metin, style: const TextStyle(height: 1.4)),
          if (cevap.yorum.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Renkler.turuncu.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Renkler.turuncu.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.record_voice_over, size: 16, color: Renkler.turuncu),
                    SizedBox(width: 6),
                    Text('Benim yorumum', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Renkler.turuncu)),
                  ]),
                  const SizedBox(height: 6),
                  SelectableText(cevap.yorum, style: const TextStyle(height: 1.4)),
                  const SizedBox(height: 6),
                  Text('Yorum kişisel değerlendirmedir, mevzuat hükmü değildir.', style: TextStyle(fontSize: 11, color: renk.onSurfaceVariant)),
                ],
              ),
            ),
          ],
          if (cevap.cezalar.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Ceza kalemleri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: renk.onSurfaceVariant)),
            const SizedBox(height: 6),
            for (final c in cevap.cezalar) Padding(padding: const EdgeInsets.only(bottom: 6), child: CezaSatiri(c)),
          ],
          if (cevap.maddeler.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Kanun maddeleri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: renk.onSurfaceVariant)),
            const SizedBox(height: 6),
            for (final m in cevap.maddeler) Padding(padding: const EdgeInsets.only(bottom: 6), child: MaddeSatiri(m)),
          ],
          if (cevap.kazalar.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Kaza örnekleri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: renk.onSurfaceVariant)),
            const SizedBox(height: 6),
            for (final k in cevap.kazalar)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.car_crash_outlined),
                    title: Text(k['baslik'] as String),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => git(context, KazaDetay(k)),
                  ),
                ),
              ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Cevabı kopyala',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => kopyala(context, cevap.tamMetin),
            ),
          ),
        ],
      ),
    );
  }
}
