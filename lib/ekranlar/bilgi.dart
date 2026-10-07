import 'package:flutter/material.dart';

import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'araclar.dart';
import 'ek_araclar.dart';
import 'egitim.dart';
import 'ortak.dart';

/// Konu simgeleri; icerik.json'daki "ikon" adıyla seçilir.
(IconData, Color) _konuGorunumu(String ad) => switch (ad) {
      'kusur' => (Icons.balance, Renkler.kirmizi),
      'ehliyet' => (Icons.badge, Renkler.mavi),
      'dunya' => (Icons.public, Renkler.turkuaz),
      'plaka' => (Icons.pin, Renkler.lacivert),
      'takograf' => (Icons.timer, Renkler.mavi),
      'belge' => (Icons.assignment_turned_in, Renkler.yesil),
      'tehlike' => (Icons.warning_amber, Renkler.turuncu),
      'ilkyardim' => (Icons.medical_services, Renkler.kirmizi),
      'levha' => (Icons.signpost, Renkler.mavi),
      'gerec' => (Icons.home_repair_service, Renkler.kahve),
      'agirlik' => (Icons.scale, Renkler.kahve),
      'hiz' => (Icons.speed, Renkler.kirmizi),
      'alkol' => (Icons.local_bar, Renkler.mor),
      'servis' => (Icons.directions_bus, Renkler.turuncu),
      'kar' => (Icons.ac_unit, Renkler.turkuaz),
      'muayene' => (Icons.fact_check, Renkler.yesil),
      'tutanak' => (Icons.receipt_long, Renkler.lacivert),
      'saglik' => (Icons.monitor_heart, Renkler.kirmizi),
      'fahri' => (Icons.visibility, Renkler.mor),
      _ => (Icons.menu_book, Renkler.mavi),
    };

Widget _satir(BuildContext context, IconData ikon, Color renk, String ad, String alt, Widget ekran) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: RenkliIkon(ikon, renk, boyut: 40),
          title: Text(ad, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(alt, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => git(context, ekran),
        ),
      ),
    );

/// Sahada başvurulan bilgiler. Konular resmî metinlerdeki maddelere bağlanır; açıklama yazısı
/// yalnızca konuyu tanıtır, kuralın kendisi her zaman maddenin metninden okunur.
class BilgiBankasi extends StatelessWidget {
  const BilgiBankasi({super.key});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    return Scaffold(
      appBar: AppBar(title: const Text('Bilgi bankası')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const AracBasligi('Bilgi bankası'),
          const Bolum('Tablolar'),
          _satir(context, Icons.warning_amber, Renkler.turuncu, 'UN numaraları (tehlikeli maddeler)', 'UN numarası ya da madde adıyla ara; sınıf, etiket, tehlike tanım numarası', const UnKodlariEkrani()),
          _satir(context, Icons.badge, Renkler.mavi, 'Sürücü belgesi kodları', 'Belgedeki kısıt ve bilgi kodlarının anlamı', const SurucuKodlariEkrani()),
          _satir(context, Icons.pin, Renkler.lacivert, 'İl plaka kodları', '81 il; ada veya koda göre ara', const PlakaKodlari()),
          _satir(context, Icons.table_chart, Renkler.kirmizi, 'Hız sınırları tablosu', 'Araç sınıfı ve yol türüne göre yasal sınırlar', const HizSinirlariTablosu()),
          _satir(context, Icons.car_crash, Renkler.turuncu, 'Örnek kaza senaryoları', 'Krokili örnekler ve kusur değerlendirmesi', const KazalarEkrani()),
          const Bolum('Konular'),
          for (final k in depo.bilgi)
            () {
              final (ikon, renk) = _konuGorunumu(k['ikon'] as String? ?? '');
              return _satir(context, ikon, renk, k['baslik'] as String, k['aciklama'] as String, BilgiKonusu(k));
            }(),
          const SizedBox(height: 8),
          const Uyari('Konular resmî mevzuat metinlerindeki maddelere bağlanır. İlk yardım uygulamaları gibi sağlık bilgileri '
              'burada yer almaz; bunlar için Sağlık Bakanlığı kaynaklarına ve aldığınız eğitime başvurun.'),
        ],
      ),
    );
  }
}

/// Bir bilgi konusu: tanıtım yazısı ve ilgili maddeler.
class BilgiKonusu extends StatelessWidget {
  const BilgiKonusu(this.konu, {super.key});
  final Map<String, dynamic> konu;

  @override
  Widget build(BuildContext context) {
    final (ikon, renk) = _konuGorunumu(konu['ikon'] as String? ?? '');
    return Scaffold(
      appBar: AppBar(title: Text(konu['baslik'] as String, maxLines: 2, style: const TextStyle(fontSize: 17))),
      body: FutureBuilder<List<Madde>>(
        future: Depo.i.bilgiMaddeleri(konu),
        builder: (context, s) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SayfaBasligi(ikon, renk, konu['baslik'] as String, konu['aciklama'] as String),
            const Bolum('İlgili maddeler'),
            if (s.data == null) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            for (final m in s.data ?? const <Madde>[]) Padding(padding: const EdgeInsets.only(bottom: 8), child: MaddeSatiri(m)),
            const SizedBox(height: 8),
            const Uyari('Maddelere dokununca tam metin açılır. Metinler mevzuat.gov.tr konsolide metinleridir.'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- UN numaraları
class UnKodlariEkrani extends StatefulWidget {
  const UnKodlariEkrani({super.key});

  @override
  State<UnKodlariEkrani> createState() => _UnKodlariEkraniState();
}

class _UnKodlariEkraniState extends State<UnKodlariEkrani> {
  late final Future<Map<String, dynamic>> _veri = Depo.i.basvuruDosyasi('un_kodlari.json');
  String _arama = '';

  /// Kayıtların katlanmış adları; ilk aramada bir kez hesaplanır.
  List<String>? _adlar;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('UN numaraları')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _veri,
        builder: (context, s) {
          if (s.data == null) return const Center(child: CircularProgressIndicator());
          final maddeler = (s.data!['maddeler'] as List<dynamic>).cast<Map<String, dynamic>>();
          final adlar = _adlar ??= [for (final m in maddeler) katla(m['ad'] as String)];
          final q = katla(_arama.trim());
          final kelimeler = q.split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
          final sayi = RegExp(r'^\d{1,4}$').hasMatch(q);
          final sonuc = [
            for (final (i, m) in maddeler.indexed)
              if (q.isEmpty || (sayi ? (m['un'] as String).contains(q) || m['tehlikeNo'] == q : kelimeler.every(adlar[i].contains))) m,
          ];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _arama = v),
                  decoration: const InputDecoration(
                    hintText: 'UN no veya madde adı (ör. 1203, benzin)',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: sonuc.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('${sonuc.length} kayıt · Kaynak: ${s.data!['surum']} Tablo A (Ulaştırma ve Altyapı Bakanlığı çevirisi)',
                            style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant)),
                      );
                    }
                    final m = sonuc[i - 1];
                    String alan(String ad) => m[ad] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Turuncu levhadaki düzen: üstte tehlike tanım numarası, altta UN numarası.
                              Container(
                                width: 68,
                                decoration: BoxDecoration(color: const Color(0xFFFF8F00), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black, width: 1.5)),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      child: Text(alan('tehlikeNo').isEmpty ? '–' : alan('tehlikeNo'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15)),
                                    ),
                                    Container(height: 1.5, color: Colors.black),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      child: Text(alan('un'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectableText.rich(isaretliMetin(alan('ad'), sayi ? const [] : kelimeler), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (m['yasak'] == true) const Etiket('Taşınması yasak', Renkler.kirmizi, Colors.white),
                                        if (alan('sinif').isNotEmpty) Etiket('Sınıf ${alan('sinif')}', renk.primaryContainer, renk.onPrimaryContainer),
                                        if (alan('etiket').isNotEmpty) Etiket('Etiket ${alan('etiket')}', renk.secondaryContainer, renk.onSecondaryContainer),
                                        if (alan('pg').isNotEmpty && m['yasak'] != true) Etiket('PG ${alan('pg')}', renk.surfaceContainerHighest, renk.onSurface),
                                        if (alan('kategori').isNotEmpty) Etiket('Taşıma kat. / tünel ${alan('kategori')}', renk.surfaceContainerHighest, renk.onSurface),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- sürücü belgesi kodları
class SurucuKodlariEkrani extends StatefulWidget {
  const SurucuKodlariEkrani({super.key});

  @override
  State<SurucuKodlariEkrani> createState() => _SurucuKodlariEkraniState();
}

class _SurucuKodlariEkraniState extends State<SurucuKodlariEkrani> {
  late final Future<Map<String, dynamic>> _veri = Depo.i.basvuruDosyasi('surucu_kodlari.json');
  String _arama = '';

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sürücü belgesi kodları')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _veri,
        builder: (context, s) {
          if (s.data == null) return const Center(child: CircularProgressIndicator());
          final q = katla(_arama.trim());
          final kelimeler = q.split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
          final sayi = RegExp(r'^[\d.]+$').hasMatch(q);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _arama = v),
                  decoration: const InputDecoration(
                    hintText: 'Kod veya kelime (ör. 78, gözlük)',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    for (final b in (s.data!['bolumler'] as List<dynamic>).cast<Map<String, dynamic>>())
                      ...() {
                        final kodlar = [
                          for (final k in (b['kodlar'] as List<dynamic>).cast<Map<String, dynamic>>())
                            if (q.isEmpty || (sayi ? (k['kod'] as String).startsWith(q) : kelimeler.every(katla(k['aciklama'] as String).contains))) k,
                        ];
                        if (kodlar.isEmpty) return const <Widget>[];
                        return [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                            child: Text(b['baslik'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: renk.primary)),
                          ),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: Column(
                                children: [
                                  for (final k in kodlar)
                                    Padding(
                                      padding: EdgeInsets.fromLTRB((k['kod'] as String).contains('.') ? 14 : 0, 6, 0, 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(width: 62, child: Text(k['kod'] as String, style: TextStyle(fontWeight: FontWeight.w800, color: renk.primary))),
                                          Expanded(child: SelectableText.rich(isaretliMetin(k['aciklama'] as String, sayi ? const [] : kelimeler))),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ];
                      }(),
                    const SizedBox(height: 12),
                    Uyari('Kaynak: Nüfus ve Vatandaşlık İşleri Genel Müdürlüğü, "Sürücü/Sürücü Adayı ve Araçlara İlişkin Kod Tablosu" '
                        '(${s.data!['tarih']}). Tablo bu tarihten sonra değişmiş olabilir; şüphede güncel mevzuata bakın.'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
