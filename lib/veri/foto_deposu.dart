import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// Kaza yeri fotoğraflarının cihazdaki deposu.
///
/// Fotoğraflar yalnızca bu cihazda (telefonda uygulama klasörü, tarayıcıda sitenin IndexedDB alanı)
/// tutulur. Hiçbir yere gönderilmez; uygulamada paylaşma ya da dışa aktarma yolu bilerek yoktur.
/// Bu dosyaya ağ isteği ya da paylaşım kodu eklenmemelidir.
abstract final class FotoDeposu {
  static Future<LazyBox<Uint8List>>? _kutu;

  static Future<LazyBox<Uint8List>> _ac() => _kutu ??= () async {
        await Hive.initFlutter();
        return Hive.openLazyBox<Uint8List>('kaza_fotograflari');
      }();

  /// Fotoğrafı saklar ve kayıtta tutulacak kimliğini döndürür.
  static Future<String> ekle(Uint8List veri) async {
    final kutu = await _ac();
    var id = DateTime.now().microsecondsSinceEpoch;
    while (kutu.containsKey('$id')) {
      id++;
    }
    await kutu.put('$id', veri);
    return '$id';
  }

  static Future<Uint8List?> oku(String id) async => (await _ac()).get(id);

  static Future<void> sil(Iterable<String> kimlikler) async {
    if (kimlikler.isEmpty) return;
    await (await _ac()).deleteAll(kimlikler);
  }
}
