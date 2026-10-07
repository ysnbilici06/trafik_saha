import 'package:flutter/material.dart';

import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'araclar.dart';
import 'asistan_ekrani.dart';
import 'egitim.dart';
import 'gundem.dart';
import 'ortak.dart';
import 'profil.dart';

// ---------------------------------------------------------------- birim logoları
/// Kullanıcının seçebileceği birim rozetleri: ad, simge ve iki renk.
///
/// Bunlar uygulamaya özgü çizimlerdir; hiçbir kurumun resmî arması ya da logosu değildir ve
/// öyle görünecek biçimde değiştirilmemelidir (uygulama resmî bir kurum uygulaması değil).
const birimler = <String, (String, IconData, Color, Color)>{
  'genel': ('Trafik Saha', Icons.local_police, Color(0xFF0D2B6B), Color(0xFF00897B)),
  'trafik-polisi': ('Trafik Polisi', Icons.local_police, Color(0xFF0D2B6B), Color(0xFF1976D2)),
  'trafik-jandarmasi': ('Trafik Jandarması', Icons.security, Color(0xFF1B5E20), Color(0xFF43A047)),
  'otoyol-polisi': ('Otoyol Polisi', Icons.add_road, Color(0xFF0D2B6B), Color(0xFF0097A7)),
  'otoyol-jandarmasi': ('Otoyol Jandarması', Icons.add_road, Color(0xFF1B5E20), Color(0xFF00897B)),
  'fahri': ('Fahri Trafik Müfettişi', Icons.visibility, Color(0xFF4A148C), Color(0xFF7B3FC4)),
  'karayollari': ('Karayolları', Icons.alt_route, Color(0xFFBF360C), Color(0xFFF9A825)),
  'zabita': ('Zabıta', Icons.account_balance, Color(0xFF263238), Color(0xFF1976D2)),
};

(String, IconData, Color, Color) birimBilgisi(String kod) => birimler[kod] ?? birimler['genel']!;

/// Seçilen birimin kalkan biçimli rozeti.
class BirimLogosu extends StatelessWidget {
  const BirimLogosu(this.kod, {super.key, this.boyut = 64});
  final String kod;
  final double boyut;

  @override
  Widget build(BuildContext context) {
    final (_, ikon, koyu, acik) = birimBilgisi(kod);
    return SizedBox(
      width: boyut,
      height: boyut * 1.14,
      child: CustomPaint(
        painter: _KalkanBoyaci(koyu, acik),
        child: Align(alignment: const Alignment(0, -0.18), child: Icon(ikon, color: Colors.white, size: boyut * 0.46)),
      ),
    );
  }
}

class _KalkanBoyaci extends CustomPainter {
  const _KalkanBoyaci(this.koyu, this.acik);
  final Color koyu;
  final Color acik;

  Path _kalkan(Rect r) => Path()
    ..moveTo(r.center.dx, r.top)
    ..lineTo(r.right, r.top + r.height * 0.15)
    ..lineTo(r.right, r.top + r.height * 0.52)
    ..quadraticBezierTo(r.right, r.top + r.height * 0.84, r.center.dx, r.bottom)
    ..quadraticBezierTo(r.left, r.top + r.height * 0.84, r.left, r.top + r.height * 0.52)
    ..lineTo(r.left, r.top + r.height * 0.15)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final dis = Offset.zero & size;
    canvas.drawPath(_kalkan(dis), Paint()..color = Colors.white);
    final ic = dis.deflate(size.width * 0.06);
    canvas.drawPath(
      _kalkan(ic),
      Paint()..shader = LinearGradient(colors: [koyu, acik], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(ic),
    );
    canvas.drawPath(
      _kalkan(ic.deflate(size.width * 0.07)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.025
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_KalkanBoyaci eski) => eski.koyu != koyu || eski.acik != acik;
}

// ---------------------------------------------------------------- kısayollar
/// Ana sayfaya konabilecek bir kısayol. [ekran] yoksa alt gezinmedeki [sekme]ye gider.
class Kisayol {
  const Kisayol(this.ad, this.kisa, this.ikon, this.renk, {this.ekran, this.sekme});
  final String ad;
  final String kisa;
  final IconData ikon;
  final Color renk;
  final Widget? ekran;
  final int? sekme;
}

/// Araç adlarının kutuya sığan kısa yazılışları; listede olmayanlar kendi adıyla gösterilir.
const _kisaAdlar = {
  'Hız ihlali': 'Hız',
  'Takograf: sürüş süresi': 'Takograf',
  'İşlem kayıtlarım': 'İşlemler',
  'Kontrol listeleri': 'Kontrol',
  'Kaza kayıtlarım': 'Kaza kaydı',
  'Konum ve koordinat': 'Konum',
  'Alkol birim dönüştürme': 'Alkol birimi',
  'Fren izinden hız': 'Fren izi',
  'Durma ve takip mesafesi': 'Durma mesafesi',
  'İndirim ve gecikme faizi': 'Ödeme',
  'Ceza puanı toplamı': 'Ceza puanı',
  'Süre bitiş tarihi': 'Süre bitişi',
  'Hız sınırları tablosu': 'Hız sınırları',
  'İl plaka kodları': 'Plaka kodları',
};

const varsayilanKisayollar = [
  'Hız ihlali',
  'Alkol',
  'Takograf: sürüş süresi',
  'İşlem kayıtlarım',
  'Kontrol listeleri',
  'Kaza örnekleri',
  'Kaza kayıtlarım',
  'Quiz',
];

/// Seçilebilecek bütün kısayollar: Araçlar ekranındaki her araç ve birkaç bölüm.
final List<Kisayol> tumKisayollar = [
  for (final (_, araclar) in AraclarEkrani.gruplar)
    for (final a in araclar.entries)
      Kisayol(a.key, _kisaAdlar[a.key] ?? a.key, aracGorunumu[a.key]!.$1, aracGorunumu[a.key]!.$2, ekran: a.value),
  const Kisayol('Kaza örnekleri', 'Kazalar', Icons.car_crash, Renkler.turuncu, ekran: KazalarEkrani()),
  const Kisayol('Quiz', 'Quiz', Icons.quiz, Renkler.lacivert, sekme: 4),
  const Kisayol('Trafik asistanı', 'Asistan', Icons.auto_awesome, Renkler.mavi, ekran: AsistanEkrani()),
  const Kisayol('Trafik gündemi', 'Gündem', Icons.notifications, Renkler.kirmizi, ekran: GundemEkrani()),
  const Kisayol('Ceza rehberi', 'Cezalar', Icons.receipt_long, Renkler.yesil, sekme: 1),
  const Kisayol('Mevzuat', 'Mevzuat', Icons.menu_book, Renkler.turkuaz, sekme: 2),
];

/// Kullanıcının seçtiği (yoksa varsayılan) kısayollar, sırasıyla.
List<Kisayol> seciliKisayollar() => [
      for (final ad in Depo.i.kisayollar ?? varsayilanKisayollar)
        ...tumKisayollar.where((k) => k.ad == ad),
    ];

// ---------------------------------------------------------------- ayarlar ekranı
class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({super.key});

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  /// Bütün kısayollar: seçililer kullanıcının sırasıyla başta, diğerleri arkada.
  late final List<String> _sira = [
    for (final k in seciliKisayollar()) k.ad,
    for (final k in tumKisayollar)
      if (!(Depo.i.kisayollar ?? varsayilanKisayollar).contains(k.ad)) k.ad,
  ];
  late final Set<String> _secili = {for (final k in seciliKisayollar()) k.ad};

  Future<void> _kisayollariKaydet() => Depo.i.kisayollariKaydet(_sira.where(_secili.contains).toList());

  Future<void> _favoriEkle() async {
    final depo = Depo.i;
    var arama = '';
    final secilen = await showModalBottomSheet<Ceza>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, yenile) {
          final kelimeler = aramaKelimeleri(arama);
          final sonuc = [
            for (final c in depo.cezalar)
              if (!depo.favoriMi(c.anahtar) && c.eslesenler(kelimeler, asil: true) != null) c,
          ];
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.7,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (v) => yenile(() => arama = v),
                    decoration: const InputDecoration(hintText: 'Madde no veya kelime ara', prefixIcon: Icon(Icons.search)),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: sonuc.length,
                      itemBuilder: (context, i) => ListTile(
                        dense: true,
                        leading: Text(sonuc[i].madde, style: const TextStyle(fontWeight: FontWeight.w800)),
                        title: Text(sonuc[i].konu, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${sonuc[i].kanun} · ${sonuc[i].tutarYazisi}'),
                        onTap: () => Navigator.pop(context, sonuc[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (secilen != null) await depo.favorileriKaydet([...depo.favoriler, secilen.anahtar]);
  }

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final renk = Theme.of(context).colorScheme;
        final favoriler = [for (final a in depo.favoriler) ?depo.ceza(a)];
        return Scaffold(
          appBar: AppBar(title: const Text('Ayarlar')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              const Bolum('Birim logosu'),
              Text('Açılış ekranında ve ana sayfanın başında görünür.', style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 8 : 4,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.66,
                children: [
                  for (final b in birimler.entries)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => depo.birimSec(b.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                        decoration: BoxDecoration(
                          color: depo.birim == b.key ? renk.primaryContainer : null,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: depo.birim == b.key ? renk.primary : renk.outlineVariant, width: depo.birim == b.key ? 2 : 1),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            BirimLogosu(b.key, boyut: 44),
                            const SizedBox(height: 6),
                            Text(b.value.$1, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.1)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Uyari('Rozetler bu uygulamaya özgü çizimlerdir; kurumların resmî logosu ya da arması değildir.'),
              Row(
                children: [
                  const Expanded(child: Bolum('Ana sayfa kısayolları')),
                  TextButton(
                    onPressed: () async {
                      setState(() {
                        _secili
                          ..clear()
                          ..addAll(varsayilanKisayollar);
                        _sira
                          ..removeWhere(varsayilanKisayollar.contains)
                          ..insertAll(0, varsayilanKisayollar);
                      });
                      await depo.kisayollariKaydet(null);
                    },
                    child: const Text('Varsayılana dön'),
                  ),
                ],
              ),
              Text('İşaretledikleriniz ana sayfada görünür; sırayı değiştirmek için sağdaki tutamaçtan sürükleyin.',
                  style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant)),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (eski, yeni) {
                  setState(() => _sira.insert(yeni, _sira.removeAt(eski)));
                  _kisayollariKaydet();
                },
                children: [
                  for (final (i, ad) in _sira.indexed)
                    for (final k in tumKisayollar.where((k) => k.ad == ad))
                      ListTile(
                        key: ValueKey(ad),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Checkbox(
                          value: _secili.contains(ad),
                          onChanged: (v) {
                            setState(() => v == true ? _secili.add(ad) : _secili.remove(ad));
                            _kisayollariKaydet();
                          },
                        ),
                        title: Row(children: [RenkliIkon(k.ikon, k.renk, boyut: 30), const SizedBox(width: 10), Expanded(child: Text(k.ad))]),
                        trailing: ReorderableDragStartListener(index: i, child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle))),
                      ),
                ],
              ),
              Row(
                children: [
                  const Expanded(child: Bolum('Sık kullandıklarım')),
                  TextButton.icon(onPressed: _favoriEkle, icon: const Icon(Icons.add), label: const Text('Ceza ekle')),
                ],
              ),
              if (favoriler.isEmpty)
                Text('Henüz sık kullanılan ceza yok. Buradan ekleyebilir ya da bir cezanın sayfasındaki yıldıza basabilirsiniz.',
                    style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant))
              else
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: (eski, yeni) {
                    final l = depo.favoriler.toList();
                    l.insert(yeni, l.removeAt(eski));
                    depo.favorileriKaydet(l);
                  },
                  children: [
                    for (final (i, c) in favoriler.indexed)
                      ListTile(
                        key: ValueKey(c.anahtar),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: IconButton(
                          tooltip: 'Çıkar',
                          icon: const Icon(Icons.remove_circle_outline, color: Renkler.kirmizi),
                          onPressed: () => depo.favoriDegistir(c.anahtar),
                        ),
                        title: Text('${c.kanun} · md. ${c.madde}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(c.konu, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: ReorderableDragStartListener(index: i, child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle))),
                      ),
                  ],
                ),
              const Bolum('Diğer'),
              Card(
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Profilim'),
                  subtitle: const Text('Ad, görev, birim; veri kaynakları ve gizlilik'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => git(context, const ProfilEkrani()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
