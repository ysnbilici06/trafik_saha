import 'package:flutter/material.dart';

import '../veri/depo.dart';
import '../veri/haberler.dart';
import '../veri/modeller.dart';
import 'ortak.dart';

Color _kategoriRengi(String k) => k == 'mevzuat' ? Renkler.lacivert : Renkler.kirmizi;
String _kategoriAdi(String k) => k == 'mevzuat' ? 'Düzenleme' : 'Kaza';

/// Zil simgesinin açtığı ekran: trafik kazası ve mevzuat haberleri ile veri güncelleme duyuruları.
class GundemEkrani extends StatefulWidget {
  const GundemEkrani({super.key});

  @override
  State<GundemEkrani> createState() => _GundemEkraniState();
}

class _GundemEkraniState extends State<GundemEkrani> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final depo = Depo.i;
      depo.haberleriOkunduIsaretle();
      depo.duyurulariOkunduIsaretle();
      depo.haberleriYenile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final kazalar = depo.haberler.where((h) => h['kategori'] == 'kaza').toList();
        final mevzuat = depo.haberler.where((h) => h['kategori'] == 'mevzuat').toList();
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Trafik gündemi'),
              actions: [
                if (depo.haberYukleniyor)
                  const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))),
              ],
              bottom: TabBar(
                tabs: [
                  Tab(text: 'Kazalar (${kazalar.length})'),
                  Tab(text: 'Düzenlemeler (${mevzuat.length})'),
                  Tab(text: 'Veri (${depo.duyurular.length})'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _HaberListesi(kazalar, 'Henüz kaza haberi yok.'),
                _HaberListesi(mevzuat, 'Henüz düzenleme haberi yok.'),
                _VeriDuyurulari(depo.duyurular),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HaberListesi extends StatelessWidget {
  const _HaberListesi(this.haberler, this.bosMesaj);
  final List<Map<String, dynamic>> haberler;
  final String bosMesaj;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Depo.i.haberleriYenile(zorla: true);
        await Depo.i.guncelle();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: haberler.isEmpty ? 1 : haberler.length + 1,
        itemBuilder: (context, i) {
          if (haberler.isEmpty) return Padding(padding: const EdgeInsets.all(32), child: Text(bosMesaj, textAlign: TextAlign.center));
          if (i == haberler.length) {
            final zaman = Depo.i.haberZamani;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Uyari('En güncel $haberSiniri haber gösterilir; liste her sabah 06:00\'da yenilenir.'
                  '${zaman == null ? '' : ' Son yenileme: ${tarihYaz(zaman, saat: true)}.'}\n\n'
                  'Haberler haber sitelerinin açık akışlarından otomatik derlenir; yalnızca başlık ve kısa özet gösterilir, '
                  'haberin tamamı yayıncının sayfasında açılır. İçeriğin doğruluğu yayıncıya aittir.'),
            );
          }
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: HaberKarti(haberler[i]));
        },
      ),
    );
  }
}

/// Haber ön izlemesi: varsa görsel, kategori, başlık, kısa özet, kaynak ve zaman.
class HaberKarti extends StatelessWidget {
  const HaberKarti(this.haber, {super.key, this.kucuk = false});
  final Map<String, dynamic> haber;

  /// Ana sayfadaki sıkı görünüm: görsel ve özet gösterilmez.
  final bool kucuk;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final kategori = haber['kategori'] as String;
    final vurgu = _kategoriRengi(kategori);
    final gorsel = haber['gorsel'] as String? ?? '';
    final ozet = haber['ozet'] as String? ?? '';
    final zaman = DateTime.parse(haber['tarih'] as String).toLocal();
    final altSatir = Row(
      children: [
        Etiket(_kategoriAdi(kategori), vurgu, Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text('${haber['kaynak']} · ${neZaman(zaman)}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant)),
        ),
        Icon(Icons.open_in_new, size: 14, color: renk.onSurfaceVariant),
      ],
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => baglantiAc(context, haber['url'] as String),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gorsel.isNotEmpty && !kucuk)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  gorsel,
                  fit: BoxFit.cover,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (_, _, _) => Container(color: vurgu.withValues(alpha: 0.12), child: Icon(Icons.image_not_supported_outlined, color: vurgu)),
                  loadingBuilder: (context, cocuk, ilerleme) => ilerleme == null ? cocuk : Container(color: renk.surfaceContainerHighest),
                ),
              ),
            Container(
              decoration: gorsel.isEmpty || kucuk ? BoxDecoration(border: Border(left: BorderSide(color: vurgu, width: 5))) : null,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(haber['baslik'] as String,
                      maxLines: kucuk ? 2 : 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
                  if (ozet.isNotEmpty && !kucuk) ...[
                    const SizedBox(height: 6),
                    Text(ozet, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.35, color: renk.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 8),
                  altSatir,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ana sayfada en yeni birkaç başlığı gösteren bölüm.
class GundemOnizleme extends StatelessWidget {
  const GundemOnizleme({super.key});

  // Ana sayfada const olarak durduğu için haber değişikliklerini kendisi dinler.
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Depo.i, builder: (context, _) => _govde(context));

  Widget _govde(BuildContext context) {
    final haberler = Depo.i.haberler;
    if (haberler.isEmpty) return const SizedBox.shrink();
    // Mevzuat haberi seyrek ama önemlidir; en yenisi varsa başa alınır.
    final mevzuat = haberler.where((h) => h['kategori'] == 'mevzuat').take(1);
    final kazalar = haberler.where((h) => h['kategori'] == 'kaza').take(3 - mevzuat.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Bolum('Trafik gündemi', sag: TextButton(onPressed: () => git(context, const GundemEkrani()), child: const Text('Tümü'))),
        for (final h in [...mevzuat, ...kazalar]) Padding(padding: const EdgeInsets.only(bottom: 8), child: HaberKarti(h, kucuk: true)),
      ],
    );
  }
}

class _VeriDuyurulari extends StatelessWidget {
  const _VeriDuyurulari(this.duyurular);
  final List<Map<String, dynamic>> duyurular;

  @override
  Widget build(BuildContext context) {
    if (duyurular.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Henüz veri duyurusu yok. Ceza tutarları veya kanun metni değiştiğinde ve Resmî Gazete\'de '
              'ilgili bir yayın çıktığında burada madde madde görünür.', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (final d in duyurular)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ExpansionTile(
                shape: const Border(),
                leading: RenkliIkon(d['tur'] == 'resmi-gazete' ? Icons.newspaper : Icons.update, Renkler.yesil, boyut: 38),
                title: Text(d['baslik'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${tarihYaz(DateTime.parse(d['tarih'] as String).toLocal(), saat: true)} · ${d['ozet']}'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in (d['satirlar'] as List<dynamic>? ?? [])) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $s')),
                  if ((d['url'] as String? ?? '').isNotEmpty)
                    TextButton.icon(icon: const Icon(Icons.open_in_new, size: 18), label: const Text('Kaynağı aç'), onPressed: () => baglantiAc(context, d['url'] as String)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
