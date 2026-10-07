import 'package:flutter/material.dart';

import '../veri/depo.dart';
import '../veri/hesap.dart';
import '../veri/modeller.dart';
import 'cezalar.dart';
import 'ek_araclar.dart';
import 'islemler.dart';
import 'kaza_kaydi.dart';
import 'yeni_araclar.dart';
import 'bilgi.dart';
import 'ortak.dart';

/// Her aracın simgesi, vurgu rengi ve kısa açıklaması. Araçlar listesi ve araç sayfalarının
/// başlık şeridi aynı kaynaktan beslenir; anahtar, sayfanın başlığıdır.
const aracGorunumu = <String, (IconData, Color, String)>{
  'Bilgi bankası': (Icons.local_library, Renkler.turkuaz, 'UN numaraları, ehliyet kodları ve konu konu ilgili mevzuat maddeleri'),
  'Arşivim': (Icons.inventory_2, Renkler.lacivert, 'İcraat, kaza kayıtları, krokiler, notlar ve yer imleri tek yerde'),
  'Kaza krokisi': (Icons.draw, Renkler.lacivert, 'Yol tipini seç, araçları yerleştir, ok ve fren izi çiz'),
  'Yaş hesabı': (Icons.cake, Renkler.turkuaz, 'Doğum tarihinden olay günündeki yaş ve yaş doldurma tarihleri'),
  'İşlem kayıtlarım': (Icons.fact_check, Renkler.yesil, 'Uygulanan işlemler, istatistik ve vardiya raporu'),
  'Kaza kayıtlarım': (Icons.add_location_alt, Renkler.kirmizi, 'Kaza yeri koordinatı, saat, araçlar ve ilk tespitler'),
  'Kontrol listeleri': (Icons.checklist, Renkler.turkuaz, 'Belge, kaza yeri, alkol ve taşımacılık denetimi'),
  'Notlarım': (Icons.edit_note, Renkler.turuncu, 'Göreve özel notlar; yalnızca bu cihazda saklanır'),
  'Konum ve koordinat': (Icons.my_location, Renkler.mavi, 'GPS koordinatını al, kopyala, nota ekle'),
  'Hız ihlali': (Icons.speed, Renkler.kirmizi, 'Araç sınıfı, yol ve ölçülen hıza göre kademe ve ceza'),
  'Alkol': (Icons.local_bar, Renkler.mor, 'Promil, araç türü ve tekrar sayısına göre işlem'),
  'Alkol birim dönüştürme': (Icons.swap_horiz, Renkler.mor, 'Promil, mg/100 mL, % BAC, mg/L nefes'),
  'Takograf: sürüş süresi': (Icons.timer, Renkler.mavi, 'Sürekli, günlük ve iki haftalık süre aşımı'),
  'Fazla yük': (Icons.scale, Renkler.kahve, 'Azami yüklü ağırlık aşımı ve tolerans'),
  'Fren izinden hız': (Icons.timeline, Renkler.lacivert, 'İz uzunluğu ve zemine göre en düşük hız'),
  'Durma ve takip mesafesi': (Icons.straighten, Renkler.turkuaz, 'Hıza göre durma mesafesi ve güvenli takip'),
  'İndirim ve gecikme faizi': (Icons.percent, Renkler.yesil, '%25 indirimli tutar ve aylık %5 faiz'),
  'Ceza puanı toplamı': (Icons.leaderboard, Renkler.turuncu, 'İhlalleri seç, 100 puana kalan durumu gör'),
  'Süre bitiş tarihi': (Icons.event_available, Renkler.mavi, 'Belge geri alma ve men sürelerinin bitişi'),
  'Hız sınırları tablosu': (Icons.table_chart, Renkler.kirmizi, 'Araç sınıfı ve yol türüne göre yasal sınırlar (km/s)'),
  'İl plaka kodları': (Icons.pin, Renkler.lacivert, '81 il; ada veya koda göre ara'),
};

/// Bir aracın sayfa başındaki renkli tanıtım şeridi.
class AracBasligi extends StatelessWidget {
  const AracBasligi(this.ad, {super.key});
  final String ad;

  @override
  Widget build(BuildContext context) {
    final g = aracGorunumu[ad] ?? (Icons.calculate, Renkler.mavi, '');
    return SayfaBasligi(g.$1, g.$2, ad, g.$3);
  }
}

class AraclarEkrani extends StatelessWidget {
  const AraclarEkrani({super.key});

  static const gruplar = <(String, Map<String, Widget>)>[
    ('Saha', {
      'İşlem kayıtlarım': IslemlerEkrani(),
      'Kaza kayıtlarım': KazaKayitlariEkrani(),
      'Kaza krokisi': KrokilerEkrani(),
      'Arşivim': ArsivEkrani(),
      'Kontrol listeleri': KontrolListeleri(),
      'Notlarım': NotlarEkrani(),
      'Konum ve koordinat': KonumEkrani(),
    }),
    ('Hesaplayıcılar', {
      'Hız ihlali': HizHesabi(),
      'Alkol': AlkolHesabi(),
      'Alkol birim dönüştürme': AlkolDonusturucu(),
      'Takograf: sürüş süresi': TakografHesabi(),
      'Fazla yük': YukHesabi(),
      'Fren izinden hız': FrenIziHesabi(),
      'Durma ve takip mesafesi': MesafeHesabi(),
      'İndirim ve gecikme faizi': OdemeHesabi(),
      'Ceza puanı toplamı': PuanHesabi(),
      'Süre bitiş tarihi': SureHesabi(),
      'Yaş hesabı': YasHesabi(),
    }),
    ('Başvuru', {
      'Bilgi bankası': BilgiBankasi(),
      'Hız sınırları tablosu': HizSinirlariTablosu(),
      'İl plaka kodları': PlakaKodlari(),
    }),
  ];

  @override
  Widget build(BuildContext context) {
    final genis = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      appBar: AppBar(title: const Text('Saha Araçları')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          for (final (ad, araclar) in gruplar) ...[
            Bolum(ad),
            GridView.count(
              crossAxisCount: genis ? 4 : 2,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [for (final a in araclar.entries) _AracKutusu(a.key, a.value)],
            ),
          ],
        ],
      ),
    );
  }
}

/// Araçlar ekranındaki renkli kutu: aracın rengiyle boyalı zemin, büyük simge, ad ve açıklama.
class _AracKutusu extends StatelessWidget {
  const _AracKutusu(this.ad, this.ekran);
  final String ad;
  final Widget ekran;

  @override
  Widget build(BuildContext context) {
    final (ikon, renk, aciklama) = aracGorunumu[ad]!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color.lerp(renk, Colors.black, 0.2)!, Color.lerp(renk, Colors.white, 0.18)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: renk.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => git(context, ekran),
          child: Stack(
            children: [
              Positioned(right: -14, bottom: -18, child: Icon(ikon, size: 92, color: Colors.white.withValues(alpha: 0.16))),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
                      child: Icon(ikon, color: Colors.white, size: 23),
                    ),
                    const Spacer(),
                    Text(ad, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.15)),
                    const SizedBox(height: 3),
                    Text(aciklama, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.2)),
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

/// Hesaplayıcı sayfalarının ortak iskeleti: aracın rengine boyanır ve tanıtım şeridiyle başlar.
class HesapSayfasi extends StatelessWidget {
  const HesapSayfasi({super.key, required this.baslik, required this.cocuklar});
  final String baslik;
  final List<Widget> cocuklar;

  @override
  Widget build(BuildContext context) {
    final renk = aracGorunumu[baslik]?.$2 ?? Renkler.mavi;
    return Theme(
      data: vurguTemasi(context, renk),
      child: Scaffold(
        appBar: AppBar(title: Text(baslik)),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [AracBasligi(baslik), ...cocuklar]),
      ),
    );
  }
}

class SayiAlani extends StatelessWidget {
  const SayiAlani(this.etiket, this.degisti, {super.key, this.sonEk, this.ondalik = false});
  final String etiket;
  final ValueChanged<String> degisti;
  final String? sonEk;
  final bool ondalik;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        keyboardType: TextInputType.numberWithOptions(decimal: ondalik),
        onChanged: degisti,
        decoration: InputDecoration(labelText: etiket, suffixText: sonEk),
      ),
    );
  }
}

double? sayiOku(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

class SonucKarti extends StatelessWidget {
  const SonucKarti(this.cocuklar, {super.key});
  final List<Widget> cocuklar;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Card(
      color: renk.secondaryContainer,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sonucu girişlerden ayıran renkli şerit.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [renk.primary, Color.lerp(renk.primary, renk.tertiary, 0.6)!])),
            child: Row(
              children: [
                Icon(Icons.insights, color: renk.onPrimary, size: 18),
                const SizedBox(width: 8),
                Text('Sonuç', style: TextStyle(color: renk.onPrimary, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: cocuklar)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- hız
class HizHesabi extends StatefulWidget {
  const HizHesabi({super.key});

  @override
  State<HizHesabi> createState() => _HizHesabiState();
}

class _HizHesabiState extends State<HizHesabi> {
  int _arac = 0;
  int _yol = 0;
  bool _otoyolUst = false;
  double? _levha;
  double? _olculen;

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    final araclar = depo.hizAraclari;
    final yollar = depo.hizYollari;
    final renk = Theme.of(context).colorScheme;
    if (araclar.isEmpty) {
      return const HesapSayfasi(baslik: 'Hız ihlali', cocuklar: [Uyari('Hız sınırı tablosu yüklenemedi.')]);
    }
    final arac = araclar[_arac];
    final yasal = depo.yasalHizSiniri(arac, _yol, otoyolUstSinir: _otoyolUst);
    // Levhayla farklı bir sınır belirlenmişse o esas alınır.
    final sinir = _levha?.round() ?? yasal;
    final s = sinir != null && _olculen != null
        ? hizHesapla(depo.cezalar, yerlesimIci: _yol == 0, sinir: sinir, olculen: _olculen!.round())
        : null;
    return HesapSayfasi(
      baslik: 'Hız ihlali',
      cocuklar: [
        DropdownButtonFormField<int>(
          initialValue: _arac,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Araç sınıfı', prefixIcon: Icon(Icons.directions_car)),
          items: [for (var i = 0; i < araclar.length; i++) DropdownMenuItem(value: i, child: Text(araclar[i]['ad'] as String, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() {
            _arac = v ?? 0;
            _otoyolUst = false;
          }),
        ),
        const SizedBox(height: 12),
        Text('Yol türü', style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant)),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < yollar.length; i++)
              ChoiceChip(label: Text(yollar[i]), selected: _yol == i, onSelected: (_) => setState(() => _yol = i)),
          ],
        ),
        if (_yol == 3 && arac['otoyolUst'] != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${arac['otoyolUst']} km/s uygulanan otoyol kesimi'),
            value: _otoyolUst,
            onChanged: (v) => setState(() => _otoyolUst = v),
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Renkler.kirmizi.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              // Hız sınırı levhası görünümü.
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Renkler.kirmizi, width: 6)),
                child: Text(yasal == null ? '–' : '$yasal', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  yasal == null
                      ? 'Bu araç sınıfı ${yollar[_yol].toLowerCase()} kesimine giremez.'
                      : 'Yasal hız sınırı: $yasal km/s\n${arac['ad']} · ${yollar[_yol]}',
                  style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SayiAlani('Levhayla belirlenen sınır (varsa)', (v) => setState(() => _levha = sayiOku(v)), sonEk: 'km/s'),
        SayiAlani('Ölçülen hız', (v) => setState(() => _olculen = sayiOku(v)), sonEk: 'km/s'),
        if (s != null)
          SonucKarti([
            BilgiSatiri('Esas alınan sınır', '$sinir km/s${_levha != null ? ' (levha)' : ''}'),
            BilgiSatiri('Aşım', '${s.asim} km/s'),
            if (s.asim <= 0) const Text('Hız sınırı aşılmamış.'),
            if (s.asim > 0 && s.kalem == null) const Text('Aşım, ceza kademelerinin alt eşiğinin altında.'),
            if (s.kalem != null) ...[
              BilgiSatiri('Madde', s.kalem!.madde),
              BilgiSatiri('Ceza', para(s.kalem!.tutar), vurgu: true),
              BilgiSatiri('%25 indirimli', para(s.kalem!.indirimli)),
              if (s.kalem!.belge.isNotEmpty) BilgiSatiri('Sürücü belgesi', s.kalem!.belge),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Ceza kalemini aç'),
                onPressed: () => git(context, CezaDetay(s.kalem!)),
              ),
            ],
          ]),
        const SizedBox(height: 12),
        if ((arac['aciklama'] as String? ?? '').isNotEmpty) ...[Uyari(arac['aciklama'] as String), const SizedBox(height: 8)],
        Uyari('Sınırlar: ${depo.hizSinirlari['kaynak'] ?? ''}. Ceza kademeleri güncel ceza rehberinden okunur. '
            'Ölçülen hız olarak cihazın tutanağa esas alınan değerini girin.'),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            label: const Text('Tüm hız sınırları tablosu'),
            onPressed: () => git(context, const HizSinirlariTablosu()),
          ),
        ),
      ],
    );
  }
}

/// Araç sınıfı ve yol türüne göre yasal hız sınırlarının tamamı.
class HizSinirlariTablosu extends StatelessWidget {
  const HizSinirlariTablosu({super.key});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    final renk = Theme.of(context).colorScheme;
    const kisa = ['İçi', 'Çift y.', 'Bölünmüş', 'Otoyol'];
    return Scaffold(
      appBar: AppBar(title: const Text('Hız sınırları (km/s)')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          const AracBasligi('Hız sınırları tablosu'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Expanded(flex: 5, child: Text('Araç sınıfı', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                for (final k in kisa)
                  Expanded(flex: 2, child: Text(k, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
              ],
            ),
          ),
          for (final (i, a) in depo.hizAraclari.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(color: i.isEven ? renk.surfaceContainerLow : null, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Expanded(flex: 5, child: Text(a['ad'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  for (var y = 0; y < 4; y++)
                    Expanded(
                      flex: 2,
                      child: Text(
                        (a['sinirlar'] as List<dynamic>)[y] == null
                            ? 'Giremez'
                            : '${(a['sinirlar'] as List<dynamic>)[y]}${y == 3 && a['otoyolUst'] != null ? '–${a['otoyolUst']}' : ''}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: (a['sinirlar'] as List<dynamic>)[y] == null ? 10.5 : 14, color: Renkler.kirmizi),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Uyari('Kaynak: ${depo.hizSinirlari['kaynak'] ?? ''}. Trafik işaretleriyle farklı bir sınır belirlenmişse o sınır geçerlidir.'),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Kaynağı aç'),
              onPressed: () => baglantiAc(context, depo.hizSinirlari['url'] as String? ?? ''),
            ),
          ),
        ],
      ),
    );
  }
}
// ---------------------------------------------------------------- alkol
class AlkolHesabi extends StatefulWidget {
  const AlkolHesabi({super.key});

  @override
  State<AlkolHesabi> createState() => _AlkolHesabiState();
}

class _AlkolHesabiState extends State<AlkolHesabi> {
  bool _hususi = true;
  int _kacinci = 1;
  double? _promil;

  @override
  Widget build(BuildContext context) {
    final kalem = Depo.i.ceza('2918:48-5');
    final s = _promil == null ? null : alkolHesapla(kalem, hususiOtomobil: _hususi, promil: _promil!, kacinci: _kacinci);
    return HesapSayfasi(
      baslik: 'Alkol',
      cocuklar: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Hususi otomobil')),
            ButtonSegment(value: false, label: Text('Diğer araçlar')),
          ],
          selected: {_hususi},
          onSelectionChanged: (v) => setState(() => _hususi = v.first),
        ),
        const SizedBox(height: 14),
        SayiAlani('Ölçüm sonucu', (v) => setState(() => _promil = sayiOku(v)), sonEk: 'promil', ondalik: true),
        const Text('Son beş yıl içinde kaçıncı ihlal?'),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('1.')),
            ButtonSegment(value: 2, label: Text('2.')),
            ButtonSegment(value: 3, label: Text('3 ve üzeri')),
          ],
          selected: {_kacinci},
          onSelectionChanged: (v) => setState(() => _kacinci = v.first),
        ),
        const SizedBox(height: 14),
        if (s != null)
          SonucKarti([
            BilgiSatiri('Yasal sınır', '${s.sinir.toStringAsFixed(2)} promilin üzeri'),
            if (!s.ihlal) const Text('Ölçüm sonucu sınırın üzerinde değil; md. 48/5 uygulanmaz.'),
            if (s.ihlal) ...[
              BilgiSatiri('Ceza', para(s.tutar), vurgu: true),
              if (s.tutar != null) BilgiSatiri('%25 indirimli', para(s.tutar! * 0.75)),
              if (kalem != null) BilgiSatiri('Sürücü belgesi', kalem.belge),
              if (kalem != null && kalem.kullanmaktanMen.isNotEmpty) BilgiSatiri('Araç kullanmaktan men', kalem.kullanmaktanMen),
              if (s.tckUygulanir)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('1,00 promilin üzerinde: ayrıca TCK md. 179 kapsamında işlem yapılır.', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              if (kalem != null) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Md. 48/5 ayrıntısı'),
                  onPressed: () => git(context, CezaDetay(kalem)),
                ),
              ],
            ],
          ]),
        const SizedBox(height: 12),
        const Uyari('Yasal sınırların üzerinde alkollü olarak trafik kazasına sebebiyet verilmesi hâlinde de TCK md. 179 uygulanır.'),
      ],
    );
  }
}

// ---------------------------------------------------------------- ödeme
class OdemeHesabi extends StatefulWidget {
  const OdemeHesabi({super.key});

  @override
  State<OdemeHesabi> createState() => _OdemeHesabiState();
}

class _OdemeHesabiState extends State<OdemeHesabi> {
  double? _tutar;
  double _ay = 0;

  @override
  Widget build(BuildContext context) {
    final faiz = _tutar == null ? 0.0 : gecikmeFaizi(_tutar!, _ay.round());
    return HesapSayfasi(
      baslik: 'İndirim ve gecikme faizi',
      cocuklar: [
        SayiAlani('Ceza tutarı', (v) => setState(() => _tutar = sayiOku(v)), sonEk: 'TL', ondalik: true),
        Text('Ödeme süresinden sonra geçen ay: ${_ay.round()}'),
        Slider(value: _ay, max: 48, divisions: 48, label: '${_ay.round()} ay', onChanged: (v) => setState(() => _ay = v)),
        if (_tutar != null)
          SonucKarti([
            BilgiSatiri('%25 indirimli', para(_tutar! * 0.75), vurgu: true),
            BilgiSatiri('İndirim tutarı', para(_tutar! * 0.25)),
            if (_ay > 0) ...[
              const Divider(),
              BilgiSatiri('Gecikme faizi', para(faiz)),
              BilgiSatiri('Faizle toplam', para(_tutar! + faiz), vurgu: true),
            ],
          ]),
        const SizedBox(height: 12),
        const Uyari('Md. 115: Ceza, tebliğden itibaren bir ay içinde ödenir. Süresinde ödenmeyen cezaya her ay %5 faiz '
            'uygulanır, ay kesirleri tam ay sayılır ve bulunacak faiz cezanın iki katını geçemez.'),
      ],
    );
  }
}

// ---------------------------------------------------------------- ceza puanı
class PuanHesabi extends StatefulWidget {
  const PuanHesabi({super.key});

  @override
  State<PuanHesabi> createState() => _PuanHesabiState();
}

class _PuanHesabiState extends State<PuanHesabi> {
  final List<Ceza> _secilen = [];

  Future<void> _ekle() async {
    final puanlilar = Depo.i.cezalar.where((c) => c.puan != null).toList();
    final secim = await showModalBottomSheet<Ceza>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        var arama = '';
        return StatefulBuilder(builder: (context, yenile) {
          final q = katla(arama);
          final liste = puanlilar.where((c) => c.arama.contains(q)).toList();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => yenile(() => arama = v),
                    decoration: const InputDecoration(hintText: 'İhlal ara', prefixIcon: Icon(Icons.search)),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: liste.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(liste[i].konu, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('md. ${liste[i].madde}'),
                      trailing: Text('${liste[i].puan}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      onTap: () => Navigator.pop(context, liste[i]),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
    if (secim != null) setState(() => _secilen.add(secim));
  }

  @override
  Widget build(BuildContext context) {
    final toplam = _secilen.fold<int>(0, (t, c) => t + c.puan!);
    final sinir = Depo.i.ceza('2918:118');
    final renk = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ceza puanı toplamı')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _ekle, icon: const Icon(Icons.add), label: const Text('İhlal ekle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const AracBasligi('Ceza puanı toplamı'),
          SonucKarti([
            Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: (toplam / 100).clamp(0, 1).toDouble(),
                          strokeWidth: 8,
                          color: toplam >= 100 ? renk.error : renk.primary,
                          backgroundColor: renk.surface,
                        ),
                      ),
                      Text('$toplam', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    toplam >= 100
                        ? '100 ceza puanı dolmuş.${sinir == null ? '' : ' Sürücü belgesi: ${sinir.belge}; mahkemece: ${sinir.mahkeme}.'}'
                        : '100 puana ${100 - toplam} puan kaldı.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          if (_secilen.isEmpty) const Uyari('Geriye doğru bir yıl içindeki puanlı ihlalleri ekleyin.'),
          for (var i = 0; i < _secilen.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(_secilen[i].konu, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('md. ${_secilen[i].madde} · ${_secilen[i].puan} puan'),
                trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _secilen.removeAt(i))),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- fazla yük
class YukHesabi extends StatefulWidget {
  const YukHesabi({super.key});

  @override
  State<YukHesabi> createState() => _YukHesabiState();
}

class _YukHesabiState extends State<YukHesabi> {
  double? _azami;
  double? _tartilan;

  @override
  Widget build(BuildContext context) {
    final s = _azami != null && _tartilan != null && _azami! > 0
        ? yukHesapla(Depo.i.cezalar, azami: _azami!, tartilan: _tartilan!)
        : null;
    return HesapSayfasi(
      baslik: 'Fazla yük',
      cocuklar: [
        SayiAlani('Azami yüklü ağırlık', (v) => setState(() => _azami = sayiOku(v)), sonEk: 'kg', ondalik: true),
        SayiAlani('Tartılan ağırlık', (v) => setState(() => _tartilan = sayiOku(v)), sonEk: 'kg', ondalik: true),
        if (s != null)
          SonucKarti([
            BilgiSatiri('Fazla yük', '${s.fazlaKg.toStringAsFixed(0)} kg'),
            BilgiSatiri('Aşım oranı', '%${s.yuzde.toStringAsFixed(2)}'),
            BilgiSatiri('Tolerans sınırı', '${s.toleransSiniri.toStringAsFixed(0)} kg'),
            if (s.kalem == null) const Text('Tartılan ağırlık tolerans sınırını (%3,75 + 500 kg) aşmıyor.'),
            if (s.kalem != null) ...[
              BilgiSatiri('Madde', s.kalem!.madde),
              BilgiSatiri('Ceza', para(s.kalem!.tutar), vurgu: true),
              BilgiSatiri('Kime', s.kalem!.kime),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Ceza kalemini aç'),
                onPressed: () => git(context, CezaDetay(s.kalem!)),
              ),
            ],
          ]),
        const SizedBox(height: 12),
        const Uyari('Yardımcı hesaptır: kademe, fazla yükün azami yüklü ağırlığa oranına göre seçilir. '
            'İşlem tesis etmeden önce kademeyi ceza kalemindeki tanımla karşılaştırın.', ikon: Icons.warning_amber),
      ],
    );
  }
}

// ---------------------------------------------------------------- süre
class SureHesabi extends StatefulWidget {
  const SureHesabi({super.key});

  @override
  State<SureHesabi> createState() => _SureHesabiState();
}

class _SureHesabiState extends State<SureHesabi> {
  DateTime _baslangic = DateTime.now();
  double? _miktar;
  String _birim = 'gün';

  DateTime? get _bitis {
    final n = _miktar?.round();
    if (n == null || n <= 0) return null;
    final b = _baslangic;
    return switch (_birim) {
      'ay' => DateTime(b.year, b.month + n, b.day),
      'yıl' => DateTime(b.year + n, b.month, b.day),
      _ => b.add(Duration(days: n)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final bitis = _bitis;
    return HesapSayfasi(
      baslik: 'Süre bitiş tarihi',
      cocuklar: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Başlangıç tarihi'),
            subtitle: Text(tarihYaz(_baslangic)),
            onTap: () async {
              final t = await showDatePicker(context: context, initialDate: _baslangic, firstDate: DateTime(2015), lastDate: DateTime(2040));
              if (t != null) setState(() => _baslangic = t);
            },
          ),
        ),
        const SizedBox(height: 12),
        SayiAlani('Süre', (v) => setState(() => _miktar = sayiOku(v))),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'gün', label: Text('Gün')),
            ButtonSegment(value: 'ay', label: Text('Ay')),
            ButtonSegment(value: 'yıl', label: Text('Yıl')),
          ],
          selected: {_birim},
          onSelectionChanged: (v) => setState(() => _birim = v.first),
        ),
        const SizedBox(height: 14),
        if (bitis != null)
          SonucKarti([
            BilgiSatiri('Bitiş tarihi', tarihYaz(bitis), vurgu: true),
            BilgiSatiri('Toplam gün', '${bitis.difference(_baslangic).inDays}'),
          ]),
        const SizedBox(height: 12),
        const Uyari('Takvim hesabıdır. Sürenin başlangıcı ve iade şartları için ilgili ceza kalemindeki açıklamaları esas alın.'),
      ],
    );
  }
}

// ---------------------------------------------------------------- mesafe
class MesafeHesabi extends StatefulWidget {
  const MesafeHesabi({super.key});

  @override
  State<MesafeHesabi> createState() => _MesafeHesabiState();
}

class _MesafeHesabiState extends State<MesafeHesabi> {
  double _hiz = 90;
  double _surtunme = 0.7;

  static const _zeminler = [(0.7, 'Kuru asfalt'), (0.4, 'Islak asfalt'), (0.2, 'Karlı'), (0.1, 'Buzlu')];

  @override
  Widget build(BuildContext context) {
    final s = durmaMesafesi(hizKmS: _hiz, reaksiyonSn: 1, surtunme: _surtunme);
    return HesapSayfasi(
      baslik: 'Durma ve takip mesafesi',
      cocuklar: [
        Text('Hız: ${_hiz.round()} km/s', style: const TextStyle(fontWeight: FontWeight.w600)),
        Slider(value: _hiz, min: 10, max: 200, divisions: 38, label: '${_hiz.round()}', onChanged: (v) => setState(() => _hiz = v)),
        Wrap(
          spacing: 8,
          children: [
            for (final z in _zeminler)
              ChoiceChip(label: Text(z.$2), selected: _surtunme == z.$1, onSelected: (_) => setState(() => _surtunme = z.$1)),
          ],
        ),
        const SizedBox(height: 14),
        SonucKarti([
          BilgiSatiri('Reaksiyon mesafesi', '${s.reaksiyon.toStringAsFixed(1)} m'),
          BilgiSatiri('Fren mesafesi', '${s.fren.toStringAsFixed(1)} m'),
          BilgiSatiri('Durma mesafesi', '${s.toplam.toStringAsFixed(1)} m', vurgu: true),
          const Divider(),
          BilgiSatiri('Takip mesafesi', '${(_hiz / 2).toStringAsFixed(0)} m (hızın yarısı)'),
          BilgiSatiri('2 saniyede alınan yol', '${(_hiz / 3.6 * 2).toStringAsFixed(1)} m'),
        ]),
        const SizedBox(height: 12),
        const Uyari('Durma mesafesi yaklaşık fiziksel hesaptır (reaksiyon süresi 1 sn, zemine göre varsayılan sürtünme katsayısı). '
            'Kusur tespitinde delil niteliği taşımaz; eğitim ve bilgilendirme amaçlıdır.'),
      ],
    );
  }
}

// ---------------------------------------------------------------- kontrol listeleri
class KontrolListeleri extends StatelessWidget {
  const KontrolListeleri({super.key});

  static const _ikonlar = {
    'belge': Icons.badge_outlined,
    'kaza': Icons.car_crash_outlined,
    'alkol': Icons.local_bar_outlined,
    'kamyon': Icons.local_shipping_outlined,
    'otobus': Icons.directions_bus_outlined,
  };
  static const _renkler = [Renkler.mavi, Renkler.kirmizi, Renkler.mor, Renkler.kahve, Renkler.yesil, Renkler.turkuaz];

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Kontrol listeleri')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const AracBasligi('Kontrol listeleri'),
            for (final (i, l) in depo.listeler.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Builder(builder: (context) {
                  final tamam = depo.isaretliler(l['id'] as String).length;
                  final toplam = (l['maddeler'] as List<dynamic>).length;
                  final vurgu = _renkler[i % _renkler.length];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => git(context, _ListeDetay(l)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            RenkliIkon(_ikonlar[l['ikon']] ?? Icons.checklist, vurgu, boyut: 46),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l['baslik'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: toplam == 0 ? 0 : tamam / toplam,
                                      minHeight: 7,
                                      color: vurgu,
                                      backgroundColor: vurgu.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('$tamam / $toplam tamamlandı', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}

class _ListeDetay extends StatelessWidget {
  const _ListeDetay(this.liste);
  final Map<String, dynamic> liste;

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    final id = liste['id'] as String;
    final maddeler = (liste['maddeler'] as List<dynamic>).cast<Map<String, dynamic>>();
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final isaretli = depo.isaretliler(id);
        return Scaffold(
          appBar: AppBar(
            title: Text(liste['baslik'] as String),
            actions: [IconButton(tooltip: 'Sıfırla', icon: const Icon(Icons.restart_alt), onPressed: () => depo.isaretleriTemizle(id))],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: LinearProgressIndicator(value: maddeler.isEmpty ? 0 : isaretli.length / maddeler.length, minHeight: 8, borderRadius: BorderRadius.circular(8)),
              ),
              for (var i = 0; i < maddeler.length; i++) _satir(context, depo, id, i, maddeler[i], isaretli.contains(i)),
            ],
          ),
        );
      },
    );
  }

  Widget _satir(BuildContext context, Depo depo, String id, int i, Map<String, dynamic> m, bool isaretli) {
    Ceza? ceza = m['ceza'] == null ? null : depo.ceza('2918:${m['ceza']}');
    if (ceza == null && m['ceza4925'] != null) {
      for (final c in depo.cezalar) {
        if (c.kanun == '4925' && c.madde == m['ceza4925']) {
          ceza = c;
          break;
        }
      }
    }
    final bulunan = ceza;
    return CheckboxListTile(
      value: isaretli,
      onChanged: (_) => depo.isaretDegistir(id, i),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(m['metin'] as String, style: TextStyle(decoration: isaretli ? TextDecoration.lineThrough : null)),
      subtitle: bulunan == null ? null : Text('${bulunan.kanun} md. ${bulunan.madde} · ${bulunan.tutarYazisi}'),
      secondary: bulunan == null
          ? null
          : IconButton(tooltip: 'Ceza kalemi', icon: const Icon(Icons.receipt_long_outlined), onPressed: () => git(context, CezaDetay(bulunan))),
    );
  }
}

// ---------------------------------------------------------------- notlar
/// Notların arşivde ayrıldığı başlıklar.
const notTurleri = ['Genel', 'İcraat', 'Radar', 'Yönerge', 'Mevzuat'];

String notTuru(Map<String, dynamic> n) => n['tur'] as String? ?? notTurleri.first;

IconData notTuruIkonu(String tur) => switch (tur) {
      'İcraat' => Icons.fact_check_outlined,
      'Radar' => Icons.speed,
      'Yönerge' => Icons.assignment_outlined,
      'Mevzuat' => Icons.menu_book_outlined,
      _ => Icons.sticky_note_2,
    };

class NotlarEkrani extends StatelessWidget {
  const NotlarEkrani({super.key, this.tur});

  /// Verilirse yalnızca bu türdeki notlar gösterilir ve yeni not bu türle açılır.
  final String? tur;

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final notlar = [
          for (final n in depo.notlar)
            if (tur == null || notTuru(n) == tur) n,
        ];
        return Scaffold(
          appBar: AppBar(title: Text(tur == null ? 'Notlarım' : 'Notlarım · $tur')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => git(context, _NotDuzenle(null, tur: tur)),
            icon: const Icon(Icons.add),
            label: const Text('Yeni not'),
          ),
          body: notlar.isEmpty
              ? ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: const [
                  AracBasligi('Notlarım'),
                  Padding(padding: EdgeInsets.all(32), child: Text('Henüz not yok. Sağ alttaki düğmeyle ilk notunuzu ekleyin.', textAlign: TextAlign.center)),
                ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    const AracBasligi('Notlarım'),
                    for (final n in notlar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            leading: RenkliIkon(notTuruIkonu(notTuru(n)), Renkler.turuncu, boyut: 40),
                            title: Text((n['baslik'] as String).isEmpty ? 'Başlıksız not' : n['baslik'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${notTuru(n)} · ${tarihYaz(DateTime.parse(n['tarih'] as String), saat: true)}\n${n['metin']}', maxLines: 3, overflow: TextOverflow.ellipsis),
                            isThreeLine: true,
                            onTap: () => git(context, _NotDuzenle(n)),
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

class _NotDuzenle extends StatefulWidget {
  const _NotDuzenle(this.not, {this.tur});
  final Map<String, dynamic>? not;
  final String? tur;

  @override
  State<_NotDuzenle> createState() => _NotDuzenleState();
}

class _NotDuzenleState extends State<_NotDuzenle> {
  late final _baslik = TextEditingController(text: widget.not?['baslik'] as String? ?? '');
  late final _metin = TextEditingController(text: widget.not?['metin'] as String? ?? '');
  late String _tur = widget.not == null ? (widget.tur ?? notTurleri.first) : notTuru(widget.not!);

  @override
  void dispose() {
    _baslik.dispose();
    _metin.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_baslik.text.trim().isEmpty && _metin.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    await Depo.i.notKaydet(widget.not?['id'] as String?, _baslik.text.trim(), _metin.text.trim(), tur: _tur);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.not?['id'] as String?;
    return Scaffold(
      appBar: AppBar(
        title: Text(id == null ? 'Yeni not' : 'Notu düzenle'),
        actions: [
          if (id != null)
            IconButton(
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final onay = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Not silinsin mi?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
                    ],
                  ),
                );
                if (onay == true) {
                  await Depo.i.notSil(id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          IconButton(tooltip: 'Kopyala', icon: const Icon(Icons.copy), onPressed: () => kopyala(context, '${_baslik.text}\n${_metin.text}'.trim())),
          IconButton(tooltip: 'Kaydet', icon: const Icon(Icons.check), onPressed: _kaydet),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final t in notTurleri)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(label: Text(t), selected: _tur == t, onSelected: (_) => setState(() => _tur = t)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(controller: _baslik, decoration: const InputDecoration(hintText: 'Başlık (ör. plaka, konum)')),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _metin,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(hintText: 'Not'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
