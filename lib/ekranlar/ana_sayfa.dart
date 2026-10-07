import 'dart:async';

import 'package:flutter/material.dart';

import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'asistan_ekrani.dart';
import 'ayarlar_ekrani.dart';
import 'gundem.dart';
import 'hava_karti.dart';
import 'islemler.dart';
import 'ortak.dart';
import 'profil.dart';

/// Karşılamanın altındaki canlı tarih ve saat; tutanak yazarken başka yere bakmaya gerek kalmasın.
class _TarihSaat extends StatefulWidget {
  const _TarihSaat();

  @override
  State<_TarihSaat> createState() => _TarihSaatState();
}

class _TarihSaatState extends State<_TarihSaat> {
  DateTime _simdi = DateTime.now();
  late final Timer _sayac;

  @override
  void initState() {
    super.initState();
    _sayac = Timer.periodic(const Duration(seconds: 1), (_) {
      final yeni = DateTime.now();
      // Uygulama açıkken saat 06:00'yı geçerse günlük haber ve veri yenilemesi kendiliğinden başlar.
      if (yeni.minute != _simdi.minute) Depo.i.sabahYenilemesi();
      setState(() => _simdi = yeni);
    });
  }

  @override
  void dispose() {
    _sayac.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String iki(int n) => n.toString().padLeft(2, '0');
    return Row(
      children: [
        const Icon(Icons.calendar_today, color: Colors.white70, size: 15),
        const SizedBox(width: 6),
        Expanded(child: Text(uzunTarih(_simdi), style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600))),
        const Icon(Icons.schedule, color: Colors.white70, size: 16),
        const SizedBox(width: 5),
        Text('${iki(_simdi.hour)}:${iki(_simdi.minute)}:${iki(_simdi.second)}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
      ],
    );
  }
}

class AnaSayfa extends StatelessWidget {
  const AnaSayfa({super.key, required this.sekmeyeGit});
  final ValueChanged<int> sekmeyeGit;

  static const _ornekSorular = [
    '50 sınırında 82 ile gitmenin cezası',
    'Ehliyetsiz araç kullanma',
    '0,80 promil alkol',
    'Arkadan çarpan kusurlu mu?',
    'Emniyet kemeri kaç puan?',
    'Madde 84',
  ];

  @override
  Widget build(BuildContext context) {
    final depo = Depo.i;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final renk = Theme.of(context).colorScheme;
        final ad = depo.profil['ad'] as String? ?? '';
        final okunmamis = depo.okunmamisDuyuru + depo.okunmamisHaber;
        final favoriler = [for (final a in depo.favoriler) ?depo.ceza(a)];
        final sonlar = [for (final a in depo.sonBakilanlar) ?depo.ceza(a)].take(5).toList();
        final bugun = IslemOzeti(donemKayitlari(depo.islemler, 1));
        final (birimAdi, _, birimKoyu, birimAcik) = birimBilgisi(depo.birim);
        return Scaffold(
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Üst bölüm: karşılama, günün özeti ve asistan.
              Container(
                padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [birimKoyu, Color.lerp(birimKoyu, birimAcik, 0.5)!, birimAcik],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BirimLogosu(depo.birim, boyut: 30),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Trafik Saha', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, height: 1.1)),
                              if (depo.birim != 'genel') Text(birimAdi, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Trafik gündemi',
                          onPressed: () => git(context, const GundemEkrani()),
                          icon: Badge(isLabelVisible: okunmamis > 0, label: Text(okunmamis > 9 ? '9+' : '$okunmamis'), child: const Icon(Icons.notifications_outlined, color: Colors.white)),
                        ),
                        IconButton(
                          tooltip: 'Ayarlar',
                          onPressed: () => git(context, const AyarlarEkrani()),
                          icon: const Icon(Icons.settings_outlined, color: Colors.white),
                        ),
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => git(context, const ProfilEkrani()),
                          child: CircleAvatar(
                            radius: 17,
                            backgroundColor: Colors.white,
                            child: Text(ad.isEmpty ? '?' : ad.characters.first.toUpperCase(),
                                style: const TextStyle(color: Color(0xFF0D2B6B), fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(ad.isEmpty ? 'İyi görevler' : 'İyi görevler, $ad',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const _TarihSaat(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _Ozet(Icons.fact_check, '${bugun.adet}', 'Bugünkü işlem', () => git(context, const IslemlerEkrani())),
                        const SizedBox(width: 8),
                        _Ozet(Icons.military_tech, depo.derece, '${depo.xp} puan', () => sekmeyeGit(4)),
                        const SizedBox(width: 8),
                        _Ozet(Icons.star, '${favoriler.length}', 'Sık kullanılan', () => sekmeyeGit(1)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _AsistanKarti(ornekler: _ornekSorular),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const HavaKarti(),
                    Row(
                      children: [
                        const Expanded(child: Bolum('Hızlı erişim')),
                        TextButton(onPressed: () => git(context, const AyarlarEkrani()), child: const Text('Düzenle')),
                      ],
                    ),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.82,
                      children: [
                        // Kullanıcının Ayarlar'da seçtiği kısayollar; seçmediyse varsayılan sekizli.
                        for (final k in seciliKisayollar())
                          _Kisayol(k.ikon, k.renk, k.kisa, () => k.ekran == null ? sekmeyeGit(k.sekme!) : git(context, k.ekran!)),
                      ],
                    ),
                    const GundemOnizleme(),
                    const Bolum('Veri durumu'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const RenkliIkon(Icons.verified, Renkler.yesil),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Veri sürümü: ${depo.veriTarihi == null ? '-' : tarihYaz(depo.veriTarihi!, saat: true)}',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    depo.sonKontrol == null
                                        ? '${depo.cezalar.length} ceza kalemi · ${depo.maddeler.length} kanun maddesi'
                                        : 'Son denetim: ${tarihYaz(depo.sonKontrol!, saat: true)}',
                                    style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            depo.guncelleniyor
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                                : IconButton(
                                    tooltip: 'Güncellemeleri denetle',
                                    icon: const Icon(Icons.refresh),
                                    onPressed: () async {
                                      final sonuc = await depo.guncelle();
                                      if (context.mounted) bildir(context, sonuc);
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
                    if (favoriler.isNotEmpty) ...[
                      const Bolum('Sık kullanılanlarım'),
                      for (final c in favoriler.take(6)) Padding(padding: const EdgeInsets.only(bottom: 8), child: CezaSatiri(c)),
                    ],
                    if (sonlar.isNotEmpty) ...[
                      const Bolum('Son baktıklarım'),
                      for (final c in sonlar) Padding(padding: const EdgeInsets.only(bottom: 8), child: CezaSatiri(c)),
                    ],
                    const SizedBox(height: 16),
                    const Uyari('Bu uygulama resmî bir kurum uygulaması değildir. Veriler resmî kaynaklardan derlenir; '
                        'işlem tesis ederken yürürlükteki mevzuatı ve kurum talimatlarını esas alın.'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Üst bölümdeki yarı saydam özet kutusu.
class _Ozet extends StatelessWidget {
  const _Ozet(this.ikon, this.deger, this.etiket, this.dokun);
  final IconData ikon;
  final String deger;
  final String etiket;
  final VoidCallback dokun;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: dokun,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(ikon, color: Colors.white, size: 20),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(deger, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                ),
                Text(etiket, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AsistanKarti extends StatelessWidget {
  const _AsistanKarti({required this.ornekler});
  final List<String> ornekler;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFFFFD54F), size: 20),
            SizedBox(width: 8),
            Text('Trafik Asistanı', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 10),
        Material(
          color: renk.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => git(context, const AsistanEkrani()),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.search, color: renk.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Trafikle ilgili bir soru sorun…', style: TextStyle(color: renk.onSurfaceVariant))),
                  const RenkliIkon(Icons.send, Renkler.mavi, boyut: 32),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ornekler.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => Material(
              color: Colors.white.withValues(alpha: 0.18),
              shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.4))),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => git(context, AsistanEkrani(ilkSoru: ornekler[i])),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(child: Text(ornekler[i], style: const TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w600))),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Kisayol extends StatelessWidget {
  const _Kisayol(this.ikon, this.vurgu, this.ad, this.dokun);
  final IconData ikon;
  final Color vurgu;
  final String ad;
  final VoidCallback dokun;

  @override
  Widget build(BuildContext context) {
    // Zemin aracın kendi rengiyle boyanır; arkadaki büyük soluk simge kutuya derinlik verir.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color.lerp(vurgu, Colors.black, 0.18)!, Color.lerp(vurgu, Colors.white, 0.2)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: vurgu.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: dokun,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(right: -12, bottom: -14, child: Icon(ikon, size: 62, color: Colors.white.withValues(alpha: 0.16))),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.24), shape: BoxShape.circle),
                    child: Icon(ikon, color: Colors.white, size: 23),
                  ),
                  const SizedBox(height: 7),
                  Text(ad, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
