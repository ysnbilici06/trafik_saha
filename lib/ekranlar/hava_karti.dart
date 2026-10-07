import 'package:flutter/material.dart';

import '../veri/depo.dart';
import '../veri/hava.dart';
import '../veri/modeller.dart';
import 'ek_araclar.dart';
import 'ortak.dart';

IconData havaSimgesi(int kod, {bool gunduz = true}) => switch (kod) {
      0 || 1 => gunduz ? Icons.wb_sunny : Icons.nightlight_round,
      2 => gunduz ? Icons.wb_cloudy : Icons.nights_stay,
      3 => Icons.cloud,
      45 || 48 => Icons.foggy,
      71 || 73 || 75 || 77 || 85 || 86 || 56 || 57 || 66 || 67 => Icons.ac_unit,
      95 || 96 || 99 => Icons.thunderstorm,
      _ => Icons.water_drop,
    };

/// Ana sayfadaki hava, yol uyarıları ve trafik haritası kartı.
class HavaKarti extends StatelessWidget {
  const HavaKarti({super.key});

  /// Trafik katmanı açık Google Haritalar bağlantısı.
  static String trafikHaritasi(double enlem, double boylam) =>
      'https://www.google.com/maps/@$enlem,$boylam,13z/data=!5m1!1e1';

  // Kart ana sayfada const olarak durduğu için değişiklikleri kendisi dinler; yoksa yer değişince yenilenmez.
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Depo.i, builder: (context, _) => _govde(context));

  Widget _govde(BuildContext context) {
    final depo = Depo.i;
    final yer = depo.havaYeri;
    final bekleyen = depo.havaYeriBekleyen;
    final hava = bekleyen == null ? depo.hava : null;
    if (yer == null && bekleyen == null) {
      return Card(
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: const RenkliIkon(Icons.wb_sunny, Renkler.turuncu),
          title: const Text('Hava ve yol durumu', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Görev yerinizi seçin; hava, yol uyarıları ve trafik haritası burada görünsün.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => yerSec(context),
        ),
      );
    }
    final yerAdi = bekleyen ?? yer!['ad'] as String;
    final yukleniyor = bekleyen != null || depo.havaYukleniyor;
    final uyarilar = hava == null ? const <String>[] : yolUyarilari(hava);
    final kotu = uyarilar.isNotEmpty;
    final renkler = hava == null
        ? const [Color(0xFF546E7A), Color(0xFF78909C)]
        : kotu
            ? const [Color(0xFF37474F), Color(0xFF546E7A)]
            : hava.gunduz
                ? const [Color(0xFF1E88E5), Color(0xFF4FC3F7)]
                : const [Color(0xFF1A237E), Color(0xFF3949AB)];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: renkler, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => yerSec(context),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Text(yerAdi, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                ),
                const Spacer(),
                if (depo.havaZamani != null && hava != null)
                  Text(tarihYaz(depo.havaZamani!, saat: true).substring(11), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                yukleniyor
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      )
                    : IconButton(
                        tooltip: 'Yenile',
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () => depo.havaYenile(zorla: true),
                      ),
              ],
            ),
            if (hava == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                child: Text(yukleniyor ? '$yerAdi için hava durumu yükleniyor…' : (depo.havaHatasi ?? 'Hava durumu yükleniyor…')),
              )
            else ...[
              Row(
                children: [
                  Icon(havaSimgesi(hava.kod, gunduz: hava.gunduz), color: Colors.white, size: 46),
                  const SizedBox(width: 12),
                  Text('${hava.sicaklik.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w300, height: 1)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hava.durum, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text('Hissedilen ${hava.hissedilen.toStringAsFixed(0)}° · Nem %${hava.nem}', style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
                        Text('Rüzgâr ${hava.ruzgar.round()} km/s · Görüş ${hava.gorus >= 10000 ? '10 km+' : '${hava.gorus.round()} m'}',
                            style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
              if (hava.saatlik.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in hava.saatlik.take(6))
                        Expanded(
                          child: Column(
                            children: [
                              Text(s.$1, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                              const SizedBox(height: 2),
                              Icon(havaSimgesi(s.$3), color: Colors.white, size: 18),
                              Text('${s.$2.round()}°', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              if (s.$4 >= 20) Text('%${s.$4}', style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(kotu ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: kotu ? const Color(0xFFFFD54F) : Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        kotu ? uyarilar.join('\n') : 'Yol ve görüş koşulları açısından olumsuz bir hava durumu yok.',
                        style: const TextStyle(fontSize: 12.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  // Bağlantılar dokunulduğu anda seçili yerden kurulur; yer değişince eski ile gitmez.
                  Expanded(child: _Dugme(Icons.traffic, 'Trafik haritası', () {
                    final y = Depo.i.havaYeri;
                    if (y == null || Depo.i.havaYeriBekleyen != null) return bildir(context, 'Yer bilgisi alınıyor, birazdan tekrar deneyin.');
                    baglantiAc(context, trafikHaritasi((y['enlem'] as num).toDouble(), (y['boylam'] as num).toDouble()));
                  })),
                  const SizedBox(width: 8),
                  Expanded(child: _Dugme(Icons.construction, 'Çalışma olan yollar', () => baglantiAc(context, calismaYollariAdresi(katla(yerAdi))))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hava durumu için il seçtirir ya da cihaz konumunu kullanır.
  static Future<void> yerSec(BuildContext context) async {
    final secim = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        var arama = '';
        return StatefulBuilder(builder: (context, yenile) {
          final q = katla(arama);
          final iller = PlakaKodlari.iller.where((i) => katla(i).contains(q)).toList()..sort((a, b) => katla(a).compareTo(katla(b)));
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    onChanged: (v) => yenile(() => arama = v),
                    decoration: const InputDecoration(hintText: 'İl ara', prefixIcon: Icon(Icons.search)),
                  ),
                ),
                ListTile(
                  leading: const RenkliIkon(Icons.my_location, Renkler.kirmizi, boyut: 36),
                  title: const Text('Bulunduğum konumu kullan', style: TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () => Navigator.pop(context, ''),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Uyari('Hava durumu Open-Meteo servisinden alınır; bunun için seçtiğiniz ilin ya da konumunuzun '
                      'yaklaşık (1 km duyarlıkta) koordinatı bu servise gönderilir.', ikon: Icons.privacy_tip_outlined),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: iller.length,
                    itemBuilder: (context, i) => ListTile(title: Text(iller[i]), onTap: () => Navigator.pop(context, iller[i])),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
    if (secim == null) return;
    // Seçilen ad koordinat beklenmeden hemen kartta görünür.
    Depo.i.havaYeriSeciliyor(secim.isEmpty ? 'Konumum' : secim);
    try {
      if (secim.isEmpty) {
        final k = await konumAl();
        await Depo.i.havaYeriKaydet('Konumum', k.latitude, k.longitude);
      } else {
        final k = await ilKonumu(secim);
        if (k == null) throw KonumHatasi('$secim için konum bulunamadı.');
        await Depo.i.havaYeriKaydet(secim, k.$1, k.$2);
      }
    } on KonumHatasi catch (e) {
      Depo.i.havaYeriSeciliyor(null);
      if (context.mounted) bildir(context, e.mesaj);
    } catch (_) {
      Depo.i.havaYeriSeciliyor(null);
      if (context.mounted) bildir(context, 'Yer bilgisi alınamadı. İnternet bağlantınızı kontrol edin.');
    }
  }
}

class _Dugme extends StatelessWidget {
  const _Dugme(this.ikon, this.ad, this.dokun);
  final IconData ikon;
  final String ad;
  final VoidCallback dokun;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: dokun,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ikon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Flexible(child: Text(ad, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
              const SizedBox(width: 4),
              const Icon(Icons.open_in_new, color: Colors.white70, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}
