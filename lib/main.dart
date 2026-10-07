import 'dart:async';

import 'package:flutter/material.dart';

import 'ekranlar/ana_sayfa.dart';
import 'ekranlar/araclar.dart';
import 'ekranlar/ayarlar_ekrani.dart';
import 'ekranlar/cezalar.dart';
import 'ekranlar/egitim.dart';
import 'ekranlar/mevzuat.dart';
import 'ekranlar/profil.dart';
import 'veri/ayarlar.dart';
import 'veri/depo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Depo.i.baslat();
  runApp(const TrafikSahaUygulamasi());
  // Açılışta güncel veri denetlenir; arayüz bunu beklemez.
  unawaited(Depo.i.guncelle());
  unawaited(Depo.i.havaYenile());
  unawaited(Depo.i.sabahYenilemesi());
}

class TrafikSahaUygulamasi extends StatelessWidget {
  const TrafikSahaUygulamasi({super.key});

  ThemeData _tema(Brightness parlaklik) {
    final renkler = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1565C0),
      brightness: parlaklik,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );
    return ThemeData(
      colorScheme: renkler,
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        color: renkler.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: uygulamaAdi,
      debugShowCheckedModeBanner: false,
      theme: _tema(Brightness.light),
      darkTheme: _tema(Brightness.dark),
      home: const AcilisEkrani(),
    );
  }
}

/// Açılışta kısa süre görünen, kullanıcının seçtiği birim rozetini taşıyan ekran.
class AcilisEkrani extends StatefulWidget {
  const AcilisEkrani({super.key});

  @override
  State<AcilisEkrani> createState() => _AcilisEkraniState();
}

class _AcilisEkraniState extends State<AcilisEkrani> with SingleTickerProviderStateMixin {
  late final _canlandirma = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    _canlandirma.forward().whenComplete(() {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, _, _) => Depo.i.karsilandi ? const Kabuk() : const Karsilama(),
        transitionsBuilder: (_, a, _, cocuk) => FadeTransition(opacity: a, child: cocuk),
      ));
    });
  }

  @override
  void dispose() {
    _canlandirma.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (ad, _, koyu, acik) = birimBilgisi(Depo.i.birim);
    final giris = CurvedAnimation(parent: _canlandirma, curve: const Interval(0, 0.6, curve: Curves.easeOutBack));
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [koyu, acik], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(scale: Tween(begin: 0.6, end: 1.0).animate(giris), child: BirimLogosu(Depo.i.birim, boyut: 120)),
            const SizedBox(height: 24),
            const Text(uygulamaAdi, style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
            if (Depo.i.birim != 'genel')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(ad, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Alt gezinme çubuğuyla beş ana bölümü barındıran iskelet.
class Kabuk extends StatefulWidget {
  const Kabuk({super.key});

  @override
  State<Kabuk> createState() => _KabukState();
}

class _KabukState extends State<Kabuk> {
  int _sekme = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _sekme,
        children: [
          AnaSayfa(sekmeyeGit: (i) => setState(() => _sekme = i)),
          const CezalarEkrani(),
          const MevzuatEkrani(),
          const AraclarEkrani(),
          const EgitimEkrani(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _sekme,
        onDestinationSelected: (i) => setState(() => _sekme = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Ana Sayfa'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Cezalar'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Mevzuat'),
          NavigationDestination(icon: Icon(Icons.construction_outlined), selectedIcon: Icon(Icons.construction), label: 'Araçlar'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Eğitim'),
        ],
      ),
    );
  }
}
