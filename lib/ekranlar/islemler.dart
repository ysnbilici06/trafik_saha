import 'package:flutter/material.dart';

import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'ortak.dart';

/// Bir ceza kalemini işlem kaydına eklemek için plaka ve açıklama soran pencere.
Future<void> islemKaydet(BuildContext context, Ceza ceza) async {
  final plaka = TextEditingController();
  final aciklama = TextEditingController();
  final onay = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('İşlem kaydet · md. ${ceza.madde}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: plaka,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Plaka (isteğe bağlı)'),
            ),
            const SizedBox(height: 10),
            TextField(controller: aciklama, maxLines: 2, decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)')),
            const SizedBox(height: 10),
            const Uyari('Kayıt yalnızca bu cihazda tutulur; kişisel takip içindir, resmî tutanak yerine geçmez.', ikon: Icons.lock_outline),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaydet')),
      ],
    ),
  );
  if (onay == true) {
    await Depo.i.islemEkle(ceza, plaka: plaka.text, aciklama: aciklama.text);
    if (context.mounted) bildir(context, 'İşlem kaydedildi');
  }
}

/// Seçilen dönemdeki kayıtların özeti: adet, toplam tutar, en çok uygulanan maddeler.
class IslemOzeti {
  IslemOzeti(List<Map<String, dynamic>> kayitlar)
      : adet = kayitlar.length,
        toplam = kayitlar.fold(0.0, (t, k) => t + ((k['tutar'] as num?)?.toDouble() ?? 0)) {
    final sayac = <String, int>{};
    for (final k in kayitlar) {
      final ad = '${k['kanun']} md. ${k['madde']}';
      sayac[ad] = (sayac[ad] ?? 0) + 1;
    }
    enCok = sayac.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  final int adet;
  final double toplam;
  late final List<MapEntry<String, int>> enCok;
}

/// [gun] gün geriye giden (bugün dâhil) kayıtları verir; null ise hepsini.
List<Map<String, dynamic>> donemKayitlari(List<Map<String, dynamic>> hepsi, int? gun, {DateTime? simdi}) {
  if (gun == null) return hepsi;
  final s = simdi ?? DateTime.now();
  final baslangic = DateTime(s.year, s.month, s.day).subtract(Duration(days: gun - 1));
  return hepsi.where((k) => !DateTime.parse(k['tarih'] as String).isBefore(baslangic)).toList();
}

String raporMetni(List<Map<String, dynamic>> kayitlar, String donem, Map<String, dynamic> profil) {
  final ozet = IslemOzeti(kayitlar);
  final b = StringBuffer('İŞLEM RAPORU – $donem\n');
  final kim = [profil['ad'], profil['gorev'], profil['birim']].where((e) => (e as String? ?? '').isNotEmpty).join(' · ');
  if (kim.isNotEmpty) b.writeln(kim);
  b.writeln('Düzenlenme: ${tarihYaz(DateTime.now(), saat: true)}');
  b.writeln('Toplam işlem: ${ozet.adet} · Toplam tutar: ${para(ozet.toplam)}\n');
  b.writeln('Maddelere göre:');
  for (final e in ozet.enCok) {
    b.writeln('  ${e.key}: ${e.value}');
  }
  b.writeln('\nKayıtlar:');
  for (final k in kayitlar) {
    final plaka = (k['plaka'] as String? ?? '').isEmpty ? '' : ' · ${k['plaka']}';
    b.writeln('  ${tarihYaz(DateTime.parse(k['tarih'] as String), saat: true)} · md. ${k['madde']}$plaka · ${para(k['tutar'] as num?)}');
  }
  return b.toString().trimRight();
}

class IslemlerEkrani extends StatefulWidget {
  const IslemlerEkrani({super.key});

  @override
  State<IslemlerEkrani> createState() => _IslemlerEkraniState();
}

class _IslemlerEkraniState extends State<IslemlerEkrani> {
  int? _gun = 1;

  static const _donemler = [(1, 'Bugün'), (7, 'Son 7 gün'), (30, 'Son 30 gün'), (null, 'Tümü')];

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final kayitlar = donemKayitlari(depo.islemler, _gun);
        final ozet = IslemOzeti(kayitlar);
        final donemAdi = _donemler.firstWhere((d) => d.$1 == _gun).$2;
        return Scaffold(
          appBar: AppBar(
            title: const Text('İşlem kayıtlarım'),
            actions: [
              IconButton(
                tooltip: 'Raporu kopyala',
                icon: const Icon(Icons.summarize_outlined),
                onPressed: kayitlar.isEmpty ? null : () => kopyala(context, raporMetni(kayitlar, donemAdi, depo.profil)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              const SayfaBasligi(Icons.fact_check, Renkler.yesil, 'İşlem kayıtlarım', 'Uygulanan işlemler, istatistik ve vardiya raporu'),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in _donemler)
                    ChoiceChip(label: Text(d.$2), selected: _gun == d.$1, onSelected: (_) => setState(() => _gun = d.$1)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1B7A45), Renkler.yesil, Renkler.turkuaz], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(child: _Sayi('İşlem', '${ozet.adet}', Colors.white)),
                    Expanded(flex: 2, child: _Sayi('Toplam tutar', para(ozet.toplam), Colors.white)),
                  ],
                ),
              ),
              const Bolum('Son 7 gün'),
              _HaftaGrafigi(depo.islemler),
              if (ozet.enCok.isNotEmpty) ...[
                const Bolum('En çok uygulanan maddeler'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      children: [
                        for (final e in ozet.enCok.take(5))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                SizedBox(width: 120, child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                                Expanded(
                                  child: LinearProgressIndicator(value: e.value / ozet.enCok.first.value, minHeight: 10, borderRadius: BorderRadius.circular(6)),
                                ),
                                SizedBox(width: 34, child: Text('${e.value}', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              Bolum('Kayıtlar (${kayitlar.length})'),
              if (kayitlar.isEmpty)
                const Uyari('Bu dönemde kayıt yok. Bir ceza kaleminin sayfasındaki "İşlem kaydet" düğmesiyle kayıt ekleyebilirsiniz.'),
              for (final k in kayitlar)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('md. ${k['madde']}${(k['plaka'] as String? ?? '').isEmpty ? '' : ' · ${k['plaka']}'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${tarihYaz(DateTime.parse(k['tarih'] as String), saat: true)} · ${para(k['tutar'] as num?)}\n'
                        '${(k['aciklama'] as String? ?? '').isEmpty ? k['konu'] : k['aciklama']}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Kaydı sil',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final onay = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Kayıt silinsin mi?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
                              ],
                            ),
                          );
                          if (onay == true) await depo.islemSil(k['id'] as String);
                        },
                      ),
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

class _Sayi extends StatelessWidget {
  const _Sayi(this.baslik, this.deger, this.renk);
  final String baslik;
  final String deger;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(baslik, style: TextStyle(fontSize: 12, color: renk)),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(deger, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: renk))),
      ],
    );
  }
}

/// Son yedi günün günlük işlem sayısını sütunlarla gösterir.
class _HaftaGrafigi extends StatelessWidget {
  const _HaftaGrafigi(this.kayitlar);
  final List<Map<String, dynamic>> kayitlar;

  static const _gunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final simdi = DateTime.now();
    final bugun = DateTime(simdi.year, simdi.month, simdi.day);
    final gunler = [for (var i = 6; i >= 0; i--) bugun.subtract(Duration(days: i))];
    final sayilar = [
      for (final g in gunler)
        kayitlar.where((k) {
          final t = DateTime.parse(k['tarih'] as String);
          return t.year == g.year && t.month == g.month && t.day == g.day;
        }).length,
    ];
    final enYuksek = sayilar.fold(1, (a, b) => b > a ? b : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        child: SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${sayilar[i]}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: renk.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Container(
                        height: 4 + 76 * sayilar[i] / enYuksek,
                        margin: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(color: i == 6 ? renk.primary : renk.primary.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(6)),
                      ),
                      const SizedBox(height: 6),
                      Text(_gunler[gunler[i].weekday - 1], style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
