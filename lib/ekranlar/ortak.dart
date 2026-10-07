import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'cezalar.dart';
import 'mevzuat.dart';

Future<T?> git<T>(BuildContext context, Widget ekran) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => ekran));

void bildir(BuildContext context, String mesaj) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mesaj), behavior: SnackBarBehavior.floating));
}

Future<void> kopyala(BuildContext context, String metin) async {
  await Clipboard.setData(ClipboardData(text: metin));
  if (context.mounted) bildir(context, 'Panoya kopyalandı');
}

Future<void> baglantiAc(BuildContext context, String adres) async {
  final acildi = await launchUrl(Uri.parse(adres), mode: LaunchMode.externalApplication);
  if (!acildi && context.mounted) bildir(context, 'Bağlantı açılamadı');
}

/// Uygulama genelinde bölümleri ayırt etmek için kullanılan vurgu renkleri.
abstract final class Renkler {
  static const mavi = Color(0xFF1976D2);
  static const lacivert = Color(0xFF283593);
  static const kirmizi = Color(0xFFE53935);
  static const turuncu = Color(0xFFF57C00);
  static const yesil = Color(0xFF2E9E5B);
  static const turkuaz = Color(0xFF0097A7);
  static const mor = Color(0xFF7B3FC4);
  static const kahve = Color(0xFF8D5B3E);

  /// Ceza tutarının ağırlığını renkle gösterir: düşük yeşil, orta turuncu, yüksek kırmızı.
  static Color tutar(double? t) => t == null ? lacivert : (t < 3000 ? yesil : (t < 20000 ? turuncu : kirmizi));
}

/// Renkli, hafif geçişli zemin üzerinde beyaz simge.
class RenkliIkon extends StatelessWidget {
  const RenkliIkon(this.ikon, this.renk, {super.key, this.boyut = 42});
  final IconData ikon;
  final Color renk;
  final double boyut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boyut,
      height: boyut,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color.lerp(renk, Colors.white, 0.22)!, renk], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(boyut * 0.3),
        boxShadow: [BoxShadow(color: renk.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Icon(ikon, color: Colors.white, size: boyut * 0.55),
    );
  }
}

/// Araç ve liste sayfalarının tepesindeki renkli tanıtım şeridi: büyük simge, başlık ve kısa açıklama.
class SayfaBasligi extends StatelessWidget {
  const SayfaBasligi(this.ikon, this.renk, this.baslik, this.aciklama, {super.key});
  final IconData ikon;
  final Color renk;
  final String baslik;
  final String aciklama;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.lerp(renk, Colors.black, 0.28)!, renk, Color.lerp(renk, Colors.white, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: renk.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Stack(
        children: [
          // Zemindeki büyük, soluk simge sayfaya kimlik verir.
          Positioned(right: -18, bottom: -26, child: Icon(ikon, size: 130, color: Colors.white.withValues(alpha: 0.14))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(16)),
                  child: Icon(ikon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(baslik, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                      if (aciklama.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(aciklama, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sayfayı kendi vurgu rengine boyar: düğmeler, seçim çipleri, kaydırıcılar ve giriş alanları bu rengi alır.
ThemeData vurguTemasi(BuildContext context, Color renk) {
  final t = Theme.of(context);
  return t.copyWith(colorScheme: ColorScheme.fromSeed(seedColor: renk, brightness: t.brightness, dynamicSchemeVariant: DynamicSchemeVariant.vibrant));
}

class Bolum extends StatelessWidget {
  const Bolum(this.baslik, {super.key, this.sag});
  final String baslik;
  final Widget? sag;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(child: Text(baslik, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          ?sag,
        ],
      ),
    );
  }
}

/// Ceza kalemini madde numarası, konu ve tutarla gösteren liste satırı.
/// [metin]i, [terimler]in (katlanmış yazılışlarıyla) geçtiği yerler işaretli olarak verir.
TextSpan isaretliMetin(String metin, Iterable<String> terimler, {Color? zemin}) {
  zemin ??= Renkler.turuncu.withValues(alpha: 0.35);
  final parcalar = <TextSpan>[];
  var son = 0;
  for (final (bas, bit) in eslesenAraliklar(metin, terimler)) {
    parcalar.add(TextSpan(text: metin.substring(son, bas)));
    parcalar.add(TextSpan(text: metin.substring(bas, bit), style: TextStyle(backgroundColor: zemin, fontWeight: FontWeight.w800)));
    son = bit;
  }
  parcalar.add(TextSpan(text: metin.substring(son)));
  return TextSpan(children: parcalar);
}

/// [metin]de [terimler]den ilkinin geçtiği yerin çevresi; hiçbiri geçmiyorsa null.
String? eslesmeKesiti(String metin, Iterable<String> terimler, {int once = 50, int sonra = 110}) {
  final a = eslesenAraliklar(metin, terimler);
  if (a.isEmpty) return null;
  final bas = (a.first.$1 - once).clamp(0, metin.length);
  final bit = (a.first.$2 + sonra).clamp(0, metin.length);
  return '${bas > 0 ? '…' : ''}${metin.substring(bas, bit).replaceAll('\n', ' ').trim()}${bit < metin.length ? '…' : ''}';
}

class CezaSatiri extends StatelessWidget {
  const CezaSatiri(this.ceza, {super.key, this.aranan = const []});
  final Ceza ceza;

  /// Aramada eşleşen yazılışlar; ihlal tanımında işaretlenir.
  final List<String> aranan;

  TextSpan _isaretli(String metin, Color zemin) => isaretliMetin(metin, aranan, zemin: zemin);

  /// Aranan kelime yalnızca diğer hususlarda geçiyorsa geçtiği yerin çevresini verir.
  String? _ekAlinti() {
    if (aranan.isEmpty || eslesenAraliklar('${ceza.madde} ${ceza.konu} ${ceza.kime}', aranan).isNotEmpty) return null;
    final metin = '${ceza.diger} ${ceza.men}'.replaceAll('-\n', '-').replaceAll('\n', ' ');
    final a = eslesenAraliklar(metin, aranan);
    if (a.isEmpty) return null;
    final bas = (a.first.$1 - 40).clamp(0, metin.length);
    final bit = (a.first.$2 + 60).clamp(0, metin.length);
    return '${bas > 0 ? '…' : ''}${metin.substring(bas, bit).trim()}${bit < metin.length ? '…' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final men = ceza.menGerektirir;
    final vurgu = men ? Renkler.kirmizi : Renkler.tutar(ceza.tutar);
    final isaret = Renkler.turuncu.withValues(alpha: 0.35);
    final alinti = _ekAlinti();
    return Card(
      clipBehavior: Clip.antiAlias,
      // Men gerektiren kalemler dikkat çeksin diye kırmızı zeminle gösterilir.
      color: men ? Color.alphaBlend(Renkler.kirmizi.withValues(alpha: 0.10), renk.surface) : null,
      child: InkWell(
        onTap: () => git(context, CezaDetay(ceza)),
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: vurgu, width: 5))),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 74,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(color: vurgu.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    Text(ceza.kanun, style: TextStyle(fontSize: 10, color: renk.onSurfaceVariant)),
                    Text(ceza.madde,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: vurgu)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(_isaretli(ceza.konu, isaret),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: men ? const TextStyle(color: Renkler.kirmizi, fontWeight: FontWeight.w600) : null),
                    if (alinti != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text.rich(
                          TextSpan(children: [const TextSpan(text: 'Diğer hususlar: '), _isaretli(alinti, isaret)]),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Etiket(ceza.tutarYazisi, vurgu, Colors.white),
                        if (ceza.puan != null) Etiket('${ceza.puan} puan', renk.secondaryContainer, renk.onSecondaryContainer),
                        if (ceza.belge.isNotEmpty) Etiket('Belge', renk.errorContainer, renk.onErrorContainer),
                        if (ceza.men.isNotEmpty) Etiket('Trafikten men', Renkler.kirmizi, Colors.white),
                        if (ceza.kullanmaktanMen.isNotEmpty) Etiket('Sürücü men', Renkler.kirmizi, Colors.white),
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
  }
}

class MaddeSatiri extends StatelessWidget {
  const MaddeSatiri(this.madde, {super.key});
  final Madde madde;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: const Icon(Icons.article_outlined),
        title: Text('${madde.kanun == '2918' || madde.kanun == '4925' ? '${madde.kanun} · ' : ''}${madde.etiket}'
            '${madde.baslik.isEmpty ? '' : ' – ${madde.baslik}'}'),
        subtitle: Text(Depo.i.mevzuatAdi(madde.kanun), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => git(context, MaddeDetay(madde)),
      ),
    );
  }
}

class Etiket extends StatelessWidget {
  const Etiket(this.metin, this.zemin, this.yazi, {super.key});
  final String metin;
  final Color zemin;
  final Color yazi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(8)),
      child: Text(metin, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: yazi)),
    );
  }
}

/// Sonuç ekranlarında başlık-değer çiftlerini gösteren satır.
class BilgiSatiri extends StatelessWidget {
  const BilgiSatiri(this.baslik, this.deger, {super.key, this.vurgu = false, this.renk});
  final String baslik;
  final String deger;
  final bool vurgu;

  /// Verilirse başlık ve değer bu renkle yazılır (ör. men satırları kırmızı).
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(baslik, style: TextStyle(color: renk ?? t.colorScheme.onSurfaceVariant))),
          Expanded(
            child: Text(deger,
                style: vurgu
                    ? t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: t.colorScheme.primary)
                    : TextStyle(fontWeight: FontWeight.w600, color: renk)),
          ),
        ],
      ),
    );
  }
}

class Uyari extends StatelessWidget {
  const Uyari(this.metin, {super.key, this.ikon = Icons.info_outline});
  final String metin;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: renk.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 18, color: renk.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(metin, style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant))),
        ],
      ),
    );
  }
}
