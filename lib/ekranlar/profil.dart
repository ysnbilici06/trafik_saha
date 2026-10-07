import 'package:flutter/material.dart';

import '../main.dart';
import '../veri/ayarlar.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'gundem.dart';
import 'ortak.dart';

/// İlk açılışta kullanıcıdan kişisel alanını oluşturmasını ister. Bilgiler yalnızca cihazda kalır.
class Karsilama extends StatefulWidget {
  const Karsilama({super.key});

  @override
  State<Karsilama> createState() => _KarsilamaState();
}

class _KarsilamaState extends State<Karsilama> {
  final _ad = TextEditingController();
  final _gorev = TextEditingController();
  final _birim = TextEditingController();

  @override
  void dispose() {
    _ad.dispose();
    _gorev.dispose();
    _birim.dispose();
    super.dispose();
  }

  Future<void> _devam({required bool kaydet}) async {
    if (kaydet && _ad.text.trim().isNotEmpty) {
      await Depo.i.profilKaydet(_ad.text, _gorev.text, _birim.text);
    } else {
      await Depo.i.karsilamayiGec();
    }
    if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Kabuk()));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Icon(Icons.local_police, size: 64, color: t.colorScheme.primary),
            const SizedBox(height: 16),
            Text(uygulamaAdi, textAlign: TextAlign.center, style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Ceza rehberi, mevzuat, hesaplayıcılar, saha kontrol listeleri ve eğitim tek uygulamada.',
                textAlign: TextAlign.center, style: TextStyle(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 32),
            Text('Kişisel alanınızı oluşturun', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: _ad, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Adınız', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 12),
            TextField(controller: _gorev, decoration: const InputDecoration(labelText: 'Göreviniz (isteğe bağlı)', prefixIcon: Icon(Icons.badge_outlined))),
            const SizedBox(height: 12),
            TextField(controller: _birim, decoration: const InputDecoration(labelText: 'Biriminiz / iliniz (isteğe bağlı)', prefixIcon: Icon(Icons.location_city_outlined))),
            const SizedBox(height: 12),
            const Uyari('Bu bilgiler hiçbir sunucuya gönderilmez; yalnızca bu cihazda saklanır. Sık kullanılanlarınız, '
                'notlarınız ve quiz ilerlemeniz de bu alana bağlıdır.', ikon: Icons.lock_outline),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => _devam(kaydet: true), child: const Padding(padding: EdgeInsets.all(12), child: Text('Başla'))),
            TextButton(onPressed: () => _devam(kaydet: false), child: const Text('Şimdilik geç')),
          ],
        ),
      ),
    );
  }
}

class ProfilEkrani extends StatelessWidget {
  const ProfilEkrani({super.key});

  Future<void> _duzenle(BuildContext context) async {
    final depo = Depo.i;
    final ad = TextEditingController(text: depo.profil['ad'] as String? ?? '');
    final gorev = TextEditingController(text: depo.profil['gorev'] as String? ?? '');
    final birim = TextEditingController(text: depo.profil['birim'] as String? ?? '');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profili düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: ad, decoration: const InputDecoration(labelText: 'Ad')),
              const SizedBox(height: 10),
              TextField(controller: gorev, decoration: const InputDecoration(labelText: 'Görev')),
              const SizedBox(height: 10),
              TextField(controller: birim, decoration: const InputDecoration(labelText: 'Birim / il')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () async {
              await depo.profilKaydet(ad.text, gorev.text, birim.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final t = Theme.of(context);
        final renk = t.colorScheme;
        final p = depo.profil;
        final ad = p['ad'] as String? ?? '';
        final q = depo.quiz;
        final toplam = q['toplam'] as int? ?? 0;
        final dogru = q['dogru'] as int? ?? 0;
        Widget sayi(String deger, String ad) => Expanded(
              child: Column(children: [
                Text(deger, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(ad, style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant)),
              ]),
            );
        return Scaffold(
          appBar: AppBar(title: const Text('Profilim'), actions: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _duzenle(context))]),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: renk.primary,
                    child: Text(ad.isEmpty ? '?' : ad.characters.first.toUpperCase(), style: TextStyle(fontSize: 26, color: renk.onPrimary, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ad.isEmpty ? 'Profil oluşturulmadı' : ad, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        Text([p['gorev'], p['birim']].where((e) => (e as String? ?? '').isNotEmpty).join(' · '), style: TextStyle(color: renk.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Etiket('${depo.derece} · ${depo.xp} puan', renk.tertiaryContainer, renk.onTertiaryContainer),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(children: [
                    sayi('${depo.favoriler.length}', 'Sık kullanılan'),
                    sayi('${depo.notlar.length}', 'Not'),
                    sayi('$toplam', 'Çözülen soru'),
                    sayi(toplam == 0 ? '–' : '%${(dogru / toplam * 100).round()}', 'Başarı'),
                  ]),
                ),
              ),
              const Bolum('Uygulama'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: const Text('Trafik gündemi ve duyurular'),
                      trailing: depo.okunmamisDuyuru + depo.okunmamisHaber > 0 ? Badge(label: Text('${depo.okunmamisDuyuru + depo.okunmamisHaber}')) : const Icon(Icons.chevron_right),
                      onTap: () => git(context, const GundemEkrani()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.refresh),
                      title: const Text('Güncellemeleri denetle'),
                      subtitle: Text('Veri sürümü: ${depo.veriTarihi == null ? '-' : tarihYaz(depo.veriTarihi!, saat: true)}'),
                      onTap: () async {
                        final sonuc = await depo.guncelle();
                        if (context.mounted) bildir(context, sonuc);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.restart_alt),
                      title: const Text('Quiz ilerlemesini sıfırla'),
                      onTap: () async {
                        final onay = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('İlerleme sıfırlansın mı?'),
                            content: const Text('Puan, derece, rozetler ve başarı çarkları silinir.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sıfırla')),
                            ],
                          ),
                        );
                        if (onay == true) await depo.ilerlemeyiSifirla();
                      },
                    ),
                  ],
                ),
              ),
              const Bolum('Veri kaynakları'),
              Card(
                child: Column(
                  children: [
                    for (final k in const [
                      ('EGM Trafik Başkanlığı', 'Trafik İdari Para Ceza Rehberi', 'https://www.trafik.gov.tr'),
                      ('mevzuat.gov.tr', '2918 ve 4925 sayılı Kanun metinleri', 'https://www.mevzuat.gov.tr'),
                      ('Ulaştırma ve Altyapı Bakanlığı', '4925 md. 26 idari para cezaları', 'https://www.uab.gov.tr'),
                      ('Resmî Gazete', 'Değişiklik duyuruları', 'https://www.resmigazete.gov.tr'),
                      ('Open-Meteo', 'Hava durumu verisi (CC BY 4.0)', 'https://open-meteo.com'),
                    ])
                      ListTile(title: Text(k.$1), subtitle: Text(k.$2), trailing: const Icon(Icons.open_in_new, size: 18), onTap: () => baglantiAc(context, k.$3)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Uyari('Trafik Saha resmî bir kurum uygulaması değildir. İçerik resmî kaynaklardan otomatik derlenir; '
                  'derleme sırasında hata oluşabilir. İşlem tesis ederken yürürlükteki mevzuat ve kurum talimatları esastır.',
                  ikon: Icons.gpp_maybe_outlined),
            ],
          ),
        );
      },
    );
  }
}
