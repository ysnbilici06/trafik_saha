import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../veri/depo.dart';
import '../veri/hesap.dart';
import '../veri/modeller.dart';
import 'araclar.dart';
import 'cezalar.dart';
import 'ortak.dart';

// ---------------------------------------------------------------- takograf
class TakografHesabi extends StatefulWidget {
  const TakografHesabi({super.key});

  @override
  State<TakografHesabi> createState() => _TakografHesabiState();
}

class _TakografHesabiState extends State<TakografHesabi> {
  TakografTuru _tur = TakografTuru.surekli;
  double? _saat;
  double? _dakika;

  static String _sure(int dakika) => '${dakika ~/ 60} sa ${dakika % 60} dk';

  @override
  Widget build(BuildContext context) {
    final girildi = _saat != null || _dakika != null;
    final toplam = ((_saat ?? 0) * 60 + (_dakika ?? 0)).round();
    final s = girildi ? takografHesapla(Depo.i.cezalar, _tur, toplam) : null;
    return HesapSayfasi(
      baslik: 'Takograf: sürüş süresi',
      cocuklar: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in TakografTuru.values)
              ChoiceChip(
                label: Text('${t.ad} (azami ${_sure(t.sinirDakika)})'),
                selected: _tur == t,
                onSelected: (_) => setState(() => _tur = t),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: SayiAlani('Sürülen süre', (v) => setState(() => _saat = sayiOku(v)), sonEk: 'saat')),
            const SizedBox(width: 12),
            Expanded(child: SayiAlani('', (v) => setState(() => _dakika = sayiOku(v)), sonEk: 'dakika')),
          ],
        ),
        if (s != null)
          SonucKarti([
            BilgiSatiri('Sürülen', _sure(toplam)),
            BilgiSatiri('Azami süre', _sure(_tur.sinirDakika)),
            if (s.asimDakika <= 0) const Text('Süre aşılmamış.'),
            if (s.asimDakika > 0) BilgiSatiri('Aşım', _sure(s.asimDakika)),
            if (s.kalem != null) ...[
              BilgiSatiri('Madde', s.kalem!.madde),
              BilgiSatiri('Ceza', para(s.kalem!.tutar), vurgu: true),
              BilgiSatiri('%25 indirimli', para(s.kalem!.indirimli)),
              if (s.kalem!.puan != null) BilgiSatiri('Ceza puanı', '${s.kalem!.puan}'),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Ceza kalemini aç'),
                onPressed: () => git(context, CezaDetay(s.kalem!)),
              ),
            ],
          ]),
        const SizedBox(height: 12),
        const Uyari('Karayolları Trafik Yönetmeliği md. 98: 24 saatlik süre içinde toplam 9 saatten ve sürekli 4,5 saatten '
            'fazla araç sürülemez; 4,5 saatlik sürüşten sonra en az 45 dakika mola verilir; birbirini izleyen iki haftada '
            'toplam sürüş 90 saati geçemez. Günlük ve haftalık dinlenme ihlalleri için md. 49/3-d ve 49/3-e kalemlerine bakın.'),
      ],
    );
  }
}

// ---------------------------------------------------------------- fren izi
class FrenIziHesabi extends StatefulWidget {
  const FrenIziHesabi({super.key});

  @override
  State<FrenIziHesabi> createState() => _FrenIziHesabiState();
}

class _FrenIziHesabiState extends State<FrenIziHesabi> {
  double? _iz;
  double _surtunme = 0.7;

  static const _zeminler = [(0.7, 'Kuru asfalt'), (0.4, 'Islak asfalt'), (0.2, 'Karlı'), (0.1, 'Buzlu')];

  @override
  Widget build(BuildContext context) {
    final hiz = _iz == null || _iz! <= 0 ? null : frenIzindenHiz(izMetre: _iz!, surtunme: _surtunme);
    return HesapSayfasi(
      baslik: 'Fren izinden hız',
      cocuklar: [
        SayiAlani('Fren izi uzunluğu', (v) => setState(() => _iz = sayiOku(v)), sonEk: 'metre', ondalik: true),
        Wrap(
          spacing: 8,
          children: [
            for (final z in _zeminler)
              ChoiceChip(label: Text('${z.$2} (μ ${z.$1})'), selected: _surtunme == z.$1, onSelected: (_) => setState(() => _surtunme = z.$1)),
          ],
        ),
        const SizedBox(height: 14),
        if (hiz != null)
          SonucKarti([
            BilgiSatiri('Frenleme başındaki hız', 'en az ${hiz.toStringAsFixed(0)} km/s', vurgu: true),
            BilgiSatiri('Formül', 'v = √(2 · μ · g · d)'),
          ]),
        const SizedBox(height: 12),
        const Uyari('Yaklaşık fiziksel hesaptır ve aracın iz sonunda durduğunu varsayar; çarpma varsa gerçek hız daha yüksektir. '
            'Sürtünme katsayısı zemine, lastiğe ve eğime göre değişir. Kusur tespitinde delil değildir; ön değerlendirme içindir.',
            ikon: Icons.warning_amber),
      ],
    );
  }
}

// ---------------------------------------------------------------- alkol birimleri
class AlkolDonusturucu extends StatefulWidget {
  const AlkolDonusturucu({super.key});

  @override
  State<AlkolDonusturucu> createState() => _AlkolDonusturucuState();
}

class _AlkolDonusturucuState extends State<AlkolDonusturucu> {
  int _birim = 0;
  double? _deger;

  @override
  Widget build(BuildContext context) {
    return HesapSayfasi(
      baslik: 'Alkol birim dönüştürme',
      cocuklar: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (var i = 0; i < alkolBirimleri.length; i++)
              ChoiceChip(label: Text(alkolBirimleri[i].$1), selected: _birim == i, onSelected: (_) => setState(() => _birim = i)),
          ],
        ),
        const SizedBox(height: 14),
        SayiAlani('Ölçüm değeri', (v) => setState(() => _deger = sayiOku(v)), sonEk: alkolBirimleri[_birim].$1, ondalik: true),
        if (_deger != null)
          SonucKarti([
            for (var i = 0; i < alkolBirimleri.length; i++)
              BilgiSatiri(alkolBirimleri[i].$1, alkolDonustur(_deger!, _birim, i).toStringAsFixed(i == 1 ? 1 : 3), vurgu: i == 0),
          ]),
        const SizedBox(height: 12),
        const Uyari('Nefes–kan dönüşümünde 2100:1 oranı kabul edilmiştir; cihazlar farklı oran kullanabilir. '
            'İşlemde ölçüm cihazının verdiği promil değeri esas alınır.'),
      ],
    );
  }
}

// ---------------------------------------------------------------- il plaka kodları
class PlakaKodlari extends StatefulWidget {
  const PlakaKodlari({super.key});

  static const iller = [
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya', 'Ankara', 'Antalya', 'Artvin', 'Aydın', 'Balıkesir',
    'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli',
    'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkâri',
    'Hatay', 'Isparta', 'Mersin', 'İstanbul', 'İzmir', 'Kars', 'Kastamonu', 'Kayseri', 'Kırklareli', 'Kırşehir',
    'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş', 'Nevşehir',
    'Niğde', 'Ordu', 'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas', 'Tekirdağ', 'Tokat',
    'Trabzon', 'Tunceli', 'Şanlıurfa', 'Uşak', 'Van', 'Yozgat', 'Zonguldak', 'Aksaray', 'Bayburt', 'Karaman',
    'Kırıkkale', 'Batman', 'Şırnak', 'Bartın', 'Ardahan', 'Iğdır', 'Yalova', 'Karabük', 'Kilis', 'Osmaniye', 'Düzce',
  ];

  @override
  State<PlakaKodlari> createState() => _PlakaKodlariState();
}

class _PlakaKodlariState extends State<PlakaKodlari> {
  String _arama = '';

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final q = katla(_arama.trim());
    final sonuc = [
      for (var i = 0; i < PlakaKodlari.iller.length; i++)
        if (q.isEmpty || katla(PlakaKodlari.iller[i]).contains(q) || (i + 1).toString().padLeft(2, '0').contains(q)) i,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('İl plaka kodları')),
      body: Column(
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: AracBasligi('İl plaka kodları')),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _arama = v),
              decoration: const InputDecoration(hintText: 'İl adı veya kod ara', prefixIcon: Icon(Icons.search)),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisExtent: 52, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: sonuc.length,
              itemBuilder: (context, n) {
                final i = sonuc[n];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: renk.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(color: Renkler.lacivert, borderRadius: BorderRadius.circular(6)),
                        child: Text((i + 1).toString().padLeft(2, '0'),
                            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(PlakaKodlari.iller[i], overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- konum
class KonumHatasi implements Exception {
  KonumHatasi(this.mesaj);
  final String mesaj;
}

/// Cihazın anlık konumunu alır; izin, servis veya sinyal sorununda kullanıcıya gösterilecek
/// mesajla [KonumHatasi] fırlatır.
Future<Position> konumAl() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw KonumHatasi('Konum servisi kapalı. Cihaz ayarlarından açın.');
    }
    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) izin = await Geolocator.requestPermission();
    if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) {
      throw KonumHatasi('Konum izni verilmedi. Uygulama ayarlarından izin verin.');
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
    );
  } on KonumHatasi {
    rethrow;
  } catch (_) {
    throw KonumHatasi('Konum alınamadı. Açık alanda tekrar deneyin.');
  }
}

class KonumEkrani extends StatefulWidget {
  const KonumEkrani({super.key});

  @override
  State<KonumEkrani> createState() => _KonumEkraniState();
}

class _KonumEkraniState extends State<KonumEkrani> {
  Position? _konum;
  String? _hata;
  bool _aliniyor = false;

  Future<void> _al() async {
    setState(() {
      _aliniyor = true;
      _hata = null;
    });
    try {
      final k = await konumAl();
      if (mounted) setState(() => _konum = k);
    } on KonumHatasi catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } finally {
      if (mounted) setState(() => _aliniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = _konum;
    final koordinat = k == null ? '' : '${k.latitude.toStringAsFixed(6)}, ${k.longitude.toStringAsFixed(6)}';
    return HesapSayfasi(
      baslik: 'Konum ve koordinat',
      cocuklar: [
        FilledButton.icon(
          icon: _aliniyor
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.my_location),
          label: Text(_aliniyor ? 'Konum alınıyor…' : 'Konumumu al'),
          onPressed: _aliniyor ? null : _al,
        ),
        const SizedBox(height: 14),
        if (_hata != null) Uyari(_hata!, ikon: Icons.error_outline),
        if (k != null)
          SonucKarti([
            BilgiSatiri('Koordinat', koordinat, vurgu: true),
            BilgiSatiri('Doğruluk', '± ${k.accuracy.toStringAsFixed(0)} m'),
            BilgiSatiri('Zaman', tarihYaz(k.timestamp.toLocal(), saat: true)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(icon: const Icon(Icons.copy, size: 18), label: const Text('Kopyala'), onPressed: () => kopyala(context, koordinat)),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Haritada aç'),
                  onPressed: () => baglantiAc(context, 'https://www.google.com/maps/search/?api=1&query=${k.latitude},${k.longitude}'),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Nota ekle'),
                  onPressed: () async {
                    await Depo.i.notKaydet(null, 'Konum ${tarihYaz(DateTime.now(), saat: true)}', koordinat);
                    if (context.mounted) bildir(context, 'Notlarınıza eklendi');
                  },
                ),
              ],
            ),
          ]),
        const SizedBox(height: 12),
        const Uyari('Konum yalnızca siz düğmeye bastığınızda alınır ve hiçbir yere gönderilmez.', ikon: Icons.lock_outline),
      ],
    );
  }
}
