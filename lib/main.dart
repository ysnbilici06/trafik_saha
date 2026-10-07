import 'dart:async';

import 'package:flutter/material.dart';

import 'ekranlar/ana_sayfa.dart';
import 'ekranlar/araclar.dart';
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
      home: Depo.i.karsilandi ? const Kabuk() : const Karsilama(),
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
